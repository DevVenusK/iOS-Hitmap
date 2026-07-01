import XCTest
@testable import HeatmapKit
@testable import HeatmapCore

final class EventPipelineTests: XCTestCase {

    private func makePipeline(
        configure: (inout HeatmapConfig) -> Void = { _ in },
        sampler: @escaping () -> Double = { 0.0 }
    ) -> (EventPipeline, EventStore) {
        var config = HeatmapConfig(endpoint: URL(string: "https://example.com")!)
        configure(&config)
        let store = EventStore(fileURL: TestFiles.tempEventFile())
        let pipeline = EventPipeline(
            config: config, store: store, uploader: FakeUploader(),
            sampler: sampler, now: { 42 }
        )
        return (pipeline, store)
    }

    // MARK: - 릴리즈 게이트: 동의 OFF ⇒ 0건

    func test_consentOff_recordsZeroEvents() {
        let (pipeline, store) = makePipeline()
        pipeline.start()
        pipeline.setScreen("home")
        // 동의를 켜지 않음 (기본 OFF)
        for _ in 0..<50 {
            pipeline.recordTap(nx: 0.5, ny: 0.5, screenW: 390, screenH: 844,
                               device: "d", orientation: .portrait)
        }
        pipeline._syncForTesting()
        XCTAssertEqual(store.count(), 0, "동의 OFF 상태에서는 단 한 건도 수집되면 안 된다")
    }

    func test_consentOn_recordsEvents() {
        let (pipeline, store) = makePipeline()
        pipeline.start()
        pipeline.setConsent(true)
        pipeline.setScreen("home")
        pipeline.recordTap(nx: 0.5, ny: 0.5, screenW: 390, screenH: 844,
                           device: "d", orientation: .portrait)
        pipeline._syncForTesting()
        XCTAssertEqual(store.count(), 1)
    }

    func test_notRunning_recordsZero() {
        let (pipeline, store) = makePipeline()
        // start() 호출 안 함
        pipeline.setConsent(true)
        pipeline.setScreen("home")
        pipeline.recordTap(nx: 0.5, ny: 0.5, screenW: 390, screenH: 844,
                           device: "d", orientation: .portrait)
        pipeline._syncForTesting()
        XCTAssertEqual(store.count(), 0)
    }

    func test_noScreenSet_recordsZero() {
        let (pipeline, store) = makePipeline()
        pipeline.start()
        pipeline.setConsent(true)
        // setScreen 안 함
        pipeline.recordTap(nx: 0.5, ny: 0.5, screenW: 390, screenH: 844,
                           device: "d", orientation: .portrait)
        pipeline._syncForTesting()
        XCTAssertEqual(store.count(), 0)
    }

    // MARK: - 민감화면 제외

    func test_excludedScreen_isBlocked() {
        let (pipeline, store) = makePipeline { $0.excludedScreens = ["login"] }
        pipeline.start()
        pipeline.setConsent(true)

        pipeline.setScreen("login")
        pipeline.recordTap(nx: 0.5, ny: 0.5, screenW: 390, screenH: 844, device: "d", orientation: .portrait)
        pipeline.setScreen("home")
        pipeline.recordTap(nx: 0.5, ny: 0.5, screenW: 390, screenH: 844, device: "d", orientation: .portrait)
        pipeline._syncForTesting()

        XCTAssertEqual(store.count(), 1, "제외화면(login)은 빠지고 home만 수집")
    }

    // MARK: - 샘플링

    func test_samplingZero_recordsZero() {
        let (pipeline, store) = makePipeline(
            configure: { $0.samplingRate = 0.0 },
            sampler: { 0.5 }   // 0.5 < 0.0 → false → 차단
        )
        pipeline.start()
        pipeline.setConsent(true)
        pipeline.setScreen("home")
        for _ in 0..<20 {
            pipeline.recordTap(nx: 0.5, ny: 0.5, screenW: 390, screenH: 844, device: "d", orientation: .portrait)
        }
        pipeline._syncForTesting()
        XCTAssertEqual(store.count(), 0)
    }

    // MARK: - flush 성공/실패

    func test_flush_success_removesBatch() {
        var config = HeatmapConfig(endpoint: URL(string: "https://example.com")!)
        let store = EventStore(fileURL: TestFiles.tempEventFile())
        let uploader = FakeUploader(results: [.success(())])
        let pipeline = EventPipeline(config: config, store: store, uploader: uploader,
                                     sampler: { 0.0 }, now: { 42 })
        pipeline.start(); pipeline.setConsent(true); pipeline.setScreen("home")
        for _ in 0..<3 {
            pipeline.recordTap(nx: 0.5, ny: 0.5, screenW: 390, screenH: 844, device: "d", orientation: .portrait)
        }
        pipeline._syncForTesting()
        XCTAssertEqual(store.count(), 3)

        let exp = expectation(description: "flush")
        pipeline.flush { result in
            if case .failure = result { XCTFail("성공해야 함") }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
        pipeline._syncForTesting()
        XCTAssertEqual(store.count(), 0, "전송 성공분은 로컬에서 제거")
        _ = config
    }

    func test_flush_failure_preservesBatch() {
        let store = EventStore(fileURL: TestFiles.tempEventFile())
        let err = NSError(domain: "net", code: -1)
        let uploader = FakeUploader(results: [.failure(err)])
        let pipeline = EventPipeline(
            config: HeatmapConfig(endpoint: URL(string: "https://example.com")!),
            store: store, uploader: uploader, sampler: { 0.0 }, now: { 42 })
        pipeline.start(); pipeline.setConsent(true); pipeline.setScreen("home")
        for _ in 0..<3 {
            pipeline.recordTap(nx: 0.5, ny: 0.5, screenW: 390, screenH: 844, device: "d", orientation: .portrait)
        }
        pipeline._syncForTesting()

        let exp = expectation(description: "flush")
        pipeline.flush { result in
            if case .success = result { XCTFail("실패해야 함") }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
        pipeline._syncForTesting()
        XCTAssertEqual(store.count(), 3, "전송 실패 시 로컬 보존(재시도 대상)")
    }
}
