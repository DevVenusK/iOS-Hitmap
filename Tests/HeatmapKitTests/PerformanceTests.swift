import Testing
import Foundation
@testable import HeatmapKit
@testable import HeatmapCore

/// 성능 예산(A1) 회귀 가드. 병렬 실행의 타이밍 노이즈를 줄이기 위해 직렬.
///
/// 실제 sendEvent 핫패스의 메인스레드 작업 = 정규화 + 이벤트 생성 + enqueue.
/// hitTest는 UIKit 내부라 이 벤치 범위 밖(온디바이스 Instruments로 별도 검증).
@Suite(.serialized) struct PerformanceTests {

    private func perOpMillis(iterations: Int, _ body: (Int) -> Void) -> Double {
        let start = DispatchTime.now()
        for i in 0..<iterations { body(i) }
        let elapsedNs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds)
        return (elapsedNs / Double(iterations)) / 1_000_000.0
    }

    @Test func normalizePerOpUnderBudget() {
        let perOp = perOpMillis(iterations: 100_000) { i in
            _ = Normalization.normalize(px: Double(i % 390), py: 422, width: 390, height: 844)
        }
        #expect(perOp < 0.5, "정규화 per-op \(perOp)ms 가 예산 0.5ms 초과")
    }

    @Test func recordTapEnqueueUnderBudget() {
        var config = HeatmapConfig(endpoint: URL(string: "https://example.com")!)
        config.uploadStrategy = .batched(maxSize: 1_000_000, interval: 3600) // 전송 부하 배제
        let buffer = FakeBuffer()
        let pipeline = EventPipeline(
            config: config, store: buffer, uploader: FakeUploader(),
            sampler: { 0.0 }, now: { 42 })
        pipeline.start(); pipeline.setConsent(true); pipeline.setScreen("home")

        let perOp = perOpMillis(iterations: 10_000) { i in
            let n = Normalization.normalize(px: Double(i % 390), py: 422, width: 390, height: 844)!
            pipeline.recordTap(nx: n.x, ny: n.y, screenW: 390, screenH: 844,
                               device: "iPhone15,3", orientation: .portrait)
        }
        #expect(perOp < 0.5, "인입 per-op \(perOp)ms 가 예산 0.5ms 초과")
        pipeline._syncForTesting()
    }
}
