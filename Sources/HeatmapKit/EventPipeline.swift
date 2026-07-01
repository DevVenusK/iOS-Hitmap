import Foundation
import HeatmapCore

/// 수집 파이프라인의 순수 코어(UIKit 무의존, 생성자 주입 → 단위테스트 가능).
///
/// 게이팅(실행/동의/제외화면/샘플링) → 저장 → 배치 전송을 담당한다.
/// UIKit 글루(`HeatmapCollector`)가 좌표를 정규화해 `recordTap`/`recordScroll`을 호출한다.
///
/// 스레드 안전: 모든 상태 변경/판정은 전용 직렬 큐에서 직렬화된다.
final class EventPipeline {

    private let queue = DispatchQueue(label: "co.finda.heatmap.pipeline")
    private let store: EventStore
    private let uploader: HeatmapUploader
    private let config: HeatmapConfig
    private let sampler: () -> Double
    private let now: () -> Int64

    private var running = false
    private var consent = false        // 기본 OFF (fail-safe)
    private var currentScreen: String?

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
        }
    }

    /// 수집 게이트. (큐 내부에서만 호출)
    private func passesGate(screen: String) -> Bool {
        guard running, consent else { return false }               // 미실행/미동의 → 차단
        guard !config.excludedScreens.contains(screen) else { return false } // 민감화면 제외
        guard config.samplingRate >= 1.0 || sampler() < config.samplingRate else { return false }
        return true
    }

    // MARK: - Flush

    func flush(completion: ((Result<Void, HeatmapError>) -> Void)?) {
        queue.async {
            let batch = self.store.loadBatch(max: self.config.maxBatchSize)
            guard !batch.isEmpty else { completion?(.success(())); return }

            let data: Data
            do {
                data = try JSONEncoder().encode(batch)
            } catch {
                completion?(.failure(HeatmapError.encodingFailed(error)))
                return
            }

            let count = batch.count
            self.uploader.upload(batch: data) { result in
                switch result {
                case .success:
                    self.queue.async {
                        self.store.removeFirst(count)   // 성공분만 제거
                        completion?(.success(()))
                    }
                case .failure(let error):
                    // 실패 시 로컬 보존(제거하지 않음) → 다음 flush 재시도
                    completion?(.failure(HeatmapError.uploadFailed(error)))
                }
            }
        }
    }

    // MARK: - Testing hook

    /// 큐에 쌓인 비동기 작업이 모두 끝날 때까지 대기(테스트 전용).
    func _syncForTesting() { queue.sync {} }
}
