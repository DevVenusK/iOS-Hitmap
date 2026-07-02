import Foundation
import HitHitCore

/// 배치 전송기 추상화. 호스트가 커스텀 전송/인증을 원하면 채택해 주입한다.
public protocol HitHitUploader: AnyObject {
    /// - Parameters:
    ///   - batch: 인코딩된 이벤트 배치(JSON 배열).
    ///   - completion: 성공 시 로컬에서 해당 배치 제거, 실패 시 로컬 보존 후 재시도.
    func upload(batch: Data, completion: @escaping (Result<Void, Error>) -> Void)
}

/// 내장 HTTP 전송기. `endpoint`로 POST하며 지수 백오프로 재시도한다.
///
/// 스레드 안전: 재시도 스케줄링은 전용 큐에서 수행. `URLSession` 콜백 스레드에 의존하지 않는다.
final class DefaultHTTPUploader: HitHitUploader {

    private let endpoint: URL
    private let headers: [String: String]
    private let session: URLSession
    private let maxRetries: Int
    private let backoff: (Int) -> TimeInterval
    private let queue = DispatchQueue(label: "co.finda.hithit.upload")

    init(
        endpoint: URL,
        headers: [String: String],
        session: URLSession = .shared,
        maxRetries: Int = 3,
        backoff: @escaping (Int) -> TimeInterval = { attempt in pow(2.0, Double(attempt)) }
    ) {
        self.endpoint = endpoint
        self.headers = headers
        self.session = session
        self.maxRetries = maxRetries
        self.backoff = backoff
    }

    func upload(batch: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        send(batch, attempt: 0, completion: completion)
    }

    private func send(_ data: Data, attempt: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = data

        session.dataTask(with: request) { [weak self] _, response, error in
            // self가 사라져도 completion은 반드시 호출한다(호출자의 uploading 플래그 스턱 방지).
            guard let self = self else {
                completion(.failure(HitHitError.uploadFailed(error)))
                return
            }
            if Self.isSuccess(response) {
                completion(.success(()))
            } else if attempt < self.maxRetries {
                let delay = self.backoff(attempt)
                self.queue.asyncAfter(deadline: .now() + delay) {
                    self.send(data, attempt: attempt + 1, completion: completion)
                }
            } else {
                completion(.failure(HitHitError.uploadFailed(error)))
            }
        }.resume()
    }

    private static func isSuccess(_ response: URLResponse?) -> Bool {
        guard let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }
}
