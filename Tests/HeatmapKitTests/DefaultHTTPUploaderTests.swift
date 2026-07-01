import XCTest
@testable import HeatmapKit
@testable import HeatmapCore

/// URLProtocol 스텁 — 요청마다 스크립트된 상태코드를 반환한다.
final class StubURLProtocol: URLProtocol {
    /// 반환할 상태코드 시퀀스(소진되면 마지막 값 반복).
    static var statusCodes: [Int] = [200]
    static var callCount = 0
    private static let lock = NSLock()

    static func reset(_ codes: [Int]) {
        lock.lock(); defer { lock.unlock() }
        statusCodes = codes
        callCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let idx = min(Self.callCount, Self.statusCodes.count - 1)
        let code = Self.statusCodes[idx]
        Self.callCount += 1
        Self.lock.unlock()

        let response = HTTPURLResponse(
            url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class DefaultHTTPUploaderTests: XCTestCase {

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeUploader(maxRetries: Int) -> DefaultHTTPUploader {
        DefaultHTTPUploader(
            endpoint: URL(string: "https://example.com/heatmap")!,
            headers: ["X-Api-Key": "test"],
            session: makeSession(),
            maxRetries: maxRetries,
            backoff: { _ in 0 }   // 테스트 가속
        )
    }

    func test_success_on_first_try() {
        StubURLProtocol.reset([200])
        let uploader = makeUploader(maxRetries: 3)
        let exp = expectation(description: "upload")
        uploader.upload(batch: Data("[]".utf8)) { result in
            if case .failure = result { XCTFail("성공해야 함") }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3)
        XCTAssertEqual(StubURLProtocol.callCount, 1)
    }

    func test_retries_then_succeeds() {
        StubURLProtocol.reset([500, 500, 200])
        let uploader = makeUploader(maxRetries: 3)
        let exp = expectation(description: "upload")
        uploader.upload(batch: Data("[]".utf8)) { result in
            if case .failure = result { XCTFail("재시도 후 성공해야 함") }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3)
        XCTAssertEqual(StubURLProtocol.callCount, 3, "500 두 번 후 3번째 200")
    }

    func test_fails_after_exhausting_retries() {
        StubURLProtocol.reset([500])
        let uploader = makeUploader(maxRetries: 2)
        let exp = expectation(description: "upload")
        uploader.upload(batch: Data("[]".utf8)) { result in
            if case .success = result { XCTFail("모두 실패해야 함") }
            if case .failure(let error) = result {
                XCTAssertEqual((error as? HeatmapError)?.code, .uploadFailed)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3)
        XCTAssertEqual(StubURLProtocol.callCount, 3, "최초 1 + 재시도 2 = 3회")
    }
}
