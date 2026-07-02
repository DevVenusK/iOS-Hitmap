import Testing
import Foundation
@testable import HitHitKit
@testable import HitHitCore

@Suite struct EventPipelineTests {

    /// 기본은 `.batched`(대용량)로 두어 이벤트가 버퍼에 남아 게이팅을 관측할 수 있게 한다.
    private func makePipeline(
        configure: (inout HitHitConfig) -> Void = { _ in },
        uploader: HitHitUploader = FakeUploader(),
        buffer: FakeBuffer = FakeBuffer(),
        sampler: @escaping () -> Double = { 0.0 }
    ) -> (EventPipeline, FakeBuffer) {
        var config = HitHitConfig(endpoint: URL(string: "https://example.com")!)
        config.uploadStrategy = .batched(maxSize: 1_000_000, interval: 3600)
        configure(&config)
        let pipeline = EventPipeline(
            config: config, store: buffer, uploader: uploader, sampler: sampler, now: { 42 })
        return (pipeline, buffer)
    }

    private func record(_ pipeline: EventPipeline, times: Int = 1) {
        for _ in 0..<times {
            pipeline.recordTap(nx: 0.5, ny: 0.5, screenW: 390, screenH: 844,
                               device: "d", orientation: .portrait)
        }
    }

    // MARK: - 릴리즈 게이트: 동의 OFF ⇒ 0건

    @Test func consentOffCollectsZero() {
        let (pipeline, buffer) = makePipeline()
        pipeline.start(); pipeline.setScreen("home")   // 동의 안 함(기본 OFF)
        record(pipeline, times: 50)
        pipeline._syncForTesting()
        #expect(buffer.count() == 0)
    }

    @Test func consentOnCollects() {
        let (pipeline, buffer) = makePipeline()
        pipeline.start(); pipeline.setConsent(true); pipeline.setScreen("home")
        record(pipeline)
        pipeline._syncForTesting()
        #expect(buffer.count() == 1)
    }

    @Test func notRunningCollectsZero() {
        let (pipeline, buffer) = makePipeline()
        pipeline.setConsent(true); pipeline.setScreen("home")   // start 안 함
        record(pipeline)
        pipeline._syncForTesting()
        #expect(buffer.count() == 0)
    }

    @Test func noScreenCollectsZero() {
        let (pipeline, buffer) = makePipeline()
        pipeline.start(); pipeline.setConsent(true)   // setScreen 안 함
        record(pipeline)
        pipeline._syncForTesting()
        #expect(buffer.count() == 0)
    }

    @Test func excludedScreenIsBlocked() {
        let (pipeline, buffer) = makePipeline { $0.excludedScreens = ["login"] }
        pipeline.start(); pipeline.setConsent(true)
        pipeline.setScreen("login"); record(pipeline)
        pipeline.setScreen("home");  record(pipeline)
        pipeline._syncForTesting()
        #expect(buffer.count() == 1)   // login 제외, home만
    }

    @Test func samplingZeroCollectsZero() {
        let (pipeline, buffer) = makePipeline(
            configure: { $0.samplingRate = 0.0 }, sampler: { 0.5 })
        pipeline.start(); pipeline.setConsent(true); pipeline.setScreen("home")
        record(pipeline, times: 20)
        pipeline._syncForTesting()
        #expect(buffer.count() == 0)
    }

    // MARK: - 즉시 전송(.immediate): 로컬에 안 쌓고 서버로

    @Test func immediateUploadsAndClearsLocalOnSuccess() async {
        let uploader = FakeUploader(results: [.success(())])
        let (pipeline, buffer) = makePipeline(
            configure: { $0.uploadStrategy = .immediate }, uploader: uploader)
        pipeline.start(); pipeline.setConsent(true); pipeline.setScreen("home")
        record(pipeline, times: 3)
        await waitUntil { uploader.uploadCount > 0 && buffer.count() == 0 }
        #expect(buffer.count() == 0)
        #expect(uploader.uploadCount > 0)
    }

    @Test func immediateKeepsLocalOnFailure() {
        let uploader = FakeUploader(results: [.failure(NSError(domain: "net", code: -1))])
        let (pipeline, buffer) = makePipeline(
            configure: { $0.uploadStrategy = .immediate }, uploader: uploader)
        pipeline.start(); pipeline.setConsent(true); pipeline.setScreen("home")
        record(pipeline)
        pipeline._syncForTesting()
        #expect(buffer.count() == 1)   // 실패 시 보존
    }

    // MARK: - 수동 flush(.batched 누적 후)

    @Test func flushSuccessRemovesBatch() async {
        let uploader = FakeUploader(results: [.success(())])
        let (pipeline, buffer) = makePipeline(uploader: uploader)
        pipeline.start(); pipeline.setConsent(true); pipeline.setScreen("home")
        record(pipeline, times: 3)
        pipeline._syncForTesting()
        #expect(buffer.count() == 3)

        let result = await awaitFlush(pipeline)
        #expect(result.isSuccess)
        pipeline._syncForTesting()
        #expect(buffer.count() == 0)
    }

    @Test func flushFailurePreservesBatch() async {
        let uploader = FakeUploader(results: [.failure(NSError(domain: "net", code: -1))])
        let (pipeline, buffer) = makePipeline(uploader: uploader)
        pipeline.start(); pipeline.setConsent(true); pipeline.setScreen("home")
        record(pipeline, times: 3)
        pipeline._syncForTesting()

        let result = await awaitFlush(pipeline)
        #expect(result.isFailure)
        pipeline._syncForTesting()
        #expect(buffer.count() == 3)
    }

    // MARK: - 동의 철회 + purge

    @Test func consentRevokeStopsUpload() async {
        let uploader = FakeUploader(results: [.success(())])
        let (pipeline, buffer) = makePipeline(uploader: uploader)
        pipeline.start(); pipeline.setConsent(true); pipeline.setScreen("home")
        record(pipeline, times: 3)
        pipeline._syncForTesting()
        #expect(buffer.count() == 3)

        pipeline.setConsent(false)
        _ = await awaitFlush(pipeline)
        pipeline._syncForTesting()
        #expect(buffer.count() == 3)          // 철회 후 미전송분도 안 나감
        #expect(uploader.uploadCount == 0)
    }

    @Test func purgeClearsBuffer() {
        let (pipeline, buffer) = makePipeline()
        pipeline.start(); pipeline.setConsent(true); pipeline.setScreen("home")
        record(pipeline, times: 3)
        pipeline._syncForTesting()
        #expect(buffer.count() == 3)

        pipeline.purgePending()
        pipeline._syncForTesting()
        #expect(buffer.count() == 0)
    }
}
