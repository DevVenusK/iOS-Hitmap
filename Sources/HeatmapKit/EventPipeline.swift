import Foundation
import HeatmapCore

/// 수집 파이프라인의 순수 코어(UIKit 무의존, 생성자 주입 → 단위테스트 가능).
///
/// 게이팅(실행/동의/제외화면/샘플링) → 임시 버퍼 저장 → 서버 전송을 담당한다.
/// UIKit 글루(`HeatmapCollector`)가 좌표를 정규화해 `recordTap`/`recordScroll`을 호출한다.
///
/// 전송 정책은 `HeatmapUploadStrategy`가 결정한다. 로컬 저장은 실패/오프라인 대비 임시 버퍼일 뿐,
/// 전송 성공 시 즉시 비워진다(서버가 원본). **동의가 꺼지면 신규 수집과 전송 모두 중단된다.**
///
/// 스레드 안전: 모든 상태 변경/판정/전송 트리거는 전용 직렬 큐에서 직렬화된다.
final class EventPipeline {

    /// 한 번의 HTTP 요청에 담는 최대 이벤트 수.
    static let uploadChunkSize = 500

    private let queue = DispatchQueue(label: "co.finda.heatmap.pipeline")
    private let store: EventStore
    private let uploader: HeatmapUploader
    private let config: HeatmapConfig
    private let sampler: () -> Double
    private let now: () -> Int64

    private var running = false
    private var consent = false        // 기본 OFF (fail-safe)
    private var currentScreen: String?
    private var uploading = false       // 코얼레싱 가드

    init(
        config: HeatmapConfig,
        store: EventStore,
        uploader: HeatmapUploader,
        sampler: @escaping () -> Double = { Double.random(in: 0..<1) },
        now: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }
    ) {
        self.config = config
        self.store = store
        self.uploader = uploader
        self.sampler = sampler
        self.now = now
    }

    // MARK: - Lifecycle / state

    func start() { queue.sync { running = true } }
    func stop()  { queue.sync { running = false } }
    func setConsent(_ granted: Bool) { queue.async { self.consent = granted } }
    func isConsentGranted() -> Bool { queue.sync { consent } }
    func setScreen(_ name: String) { queue.async { self.currentScreen = name } }
    func clearScreen() { queue.async { self.currentScreen = nil } }

    /// 저장된 미전송 이벤트를 하드 삭제(동의 철회 등).
    func purgePending() { queue.async { self.store.clear() } }

    // MARK: - Recording

    func recordTap(
        nx: Double, ny: Double, screenW: Double, screenH: Double,
        device: String, orientation: HeatmapOrientation
    ) {
        queue.async {
            guard let screen = self.currentScreen, self.passesGate(screen: screen) else { return }
            let event = HeatmapEvent.tap(
                screen: screen, x: nx, y: ny,
                screenW: screenW, screenH: screenH,
                device: device, orientation: orientation, ts: self.now()
            )
            self.store.append(event)
            self.maybeTriggerUpload()
        }
    }

    func recordScroll(
        depth: Double, offsetY: Double, screenW: Double, screenH: Double,
        device: String, orientation: HeatmapOrientation
    ) {
        queue.async {
            guard let screen = self.currentScreen, self.passesGate(screen: screen) else { return }
            let event = HeatmapEvent.scroll(
                screen: screen, scrollDepth: depth, scrollOffsetY: offsetY,
                screenW: screenW, screenH: screenH,
                device: device, orientation: orientation, ts: self.now()
            )
            self.store.append(event)
            self.maybeTriggerUpload()
        }
    }

    /// 수집 게이트. (큐 내부에서만 호출)
    private func passesGate(screen: String) -> Bool {
        guard running, consent else { return false }               // 미실행/미동의 → 차단
        guard !config.excludedScreens.contains(screen) else { return false } // 민감화면 제외
        // samplingRate가 NaN/음수/>1이어도 안전하게 처리(전량 드롭 방지).
        let rate = config.samplingRate.isFinite ? min(1, max(0, config.samplingRate)) : 1.0
        guard rate >= 1.0 || sampler() < rate else { return false }
        return true
    }

    // MARK: - Upload

    /// 이벤트 기록 직후 전략에 따라 전송을 트리거. (큐 내부)
    private func maybeTriggerUpload() {
        switch config.uploadStrategy {
        case .immediate:
            startUpload(completion: nil)
        case .batched(let maxSize, _):
            if store.count() >= maxSize { startUpload(completion: nil) }
        }
    }

    /// 수동/주기 flush. 버퍼에 남은 걸 서버로 보낸다.
    func flush(completion: ((Result<Void, HeatmapError>) -> Void)?) {
        queue.async { self.startUpload(completion: completion) }
    }

    /// 한 청크 전송 → 성공 시 로컬 제거 후 남은 게 있으면 계속 드레인. (큐 내부)
    private func startUpload(completion: ((Result<Void, HeatmapError>) -> Void)?) {
        guard consent else { completion?(.success(())); return }     // 동의 철회 시 전송 중단
        guard !uploading else { completion?(.success(())); return }  // 코얼레싱

        let (chunk, lineCount) = store.loadSpan(max: Self.uploadChunkSize)
        guard lineCount > 0 else { completion?(.success(())); return }

        // 스팬 전체가 손상 라인이면(디코딩 0) 정리하고 다음으로.
        guard !chunk.isEmpty else {
            store.removeFirst(lineCount)
            completion?(.success(()))
            if store.count() > 0 { startUpload(completion: nil) }
            return
        }

        let data: Data
        do {
            data = try JSONEncoder().encode(chunk)
        } catch {
            completion?(.failure(HeatmapError.encodingFailed(error)))
            return
        }

        uploading = true
        uploader.upload(batch: data) { result in
            self.queue.async {
                self.uploading = false
                switch result {
                case .success:
                    self.store.removeFirst(lineCount)     // 전송한 라인 수만큼 정확히 제거
                    completion?(.success(()))
                    if self.consent, self.store.count() > 0 {  // 남은 게 있으면 계속 전송
                        self.startUpload(completion: nil)
                    }
                case .failure(let error):
                    // 실패 시 로컬 보존(제거하지 않음) → 다음 트리거/스윕에서 재시도
                    completion?(.failure(HeatmapError.uploadFailed(error)))
                }
            }
        }
    }

    // MARK: - Testing hook

    /// 큐에 쌓인 비동기 작업이 모두 끝날 때까지 대기(테스트 전용).
    func _syncForTesting() { queue.sync {} }
}
