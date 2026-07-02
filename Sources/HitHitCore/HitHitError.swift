import Foundation

/// SDK 공개 에러. enum이 아니라 struct + code로 설계해, 향후 코드 추가가
/// breaking change가 되지 않도록 한다(소비자는 `error.code == .xxx`로 비교).
public struct HitHitError: Error, Equatable, Sendable {

    /// 에러 코드. 신규 코드는 새 rawValue 추가만으로 non-breaking 확장.
    public struct Code: RawRepresentable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let notConfigured      = Code(rawValue: 1)
        public static let alreadyRunning     = Code(rawValue: 2)
        public static let consentNotGranted  = Code(rawValue: 3)
        public static let storageUnavailable = Code(rawValue: 4)
        public static let encodingFailed     = Code(rawValue: 5)
        public static let uploadFailed       = Code(rawValue: 6)
    }

    public let code: Code
    public let message: String
    public let underlying: Error?

    public init(code: Code, message: String, underlying: Error? = nil) {
        self.code = code
        self.message = message
        self.underlying = underlying
    }

    public static func == (lhs: HitHitError, rhs: HitHitError) -> Bool {
        lhs.code == rhs.code && lhs.message == rhs.message
    }
}

public extension HitHitError {
    static func notConfigured() -> HitHitError {
        HitHitError(code: .notConfigured, message: "HitHitCollector.start(config:)가 먼저 호출되어야 합니다.")
    }
    static func alreadyRunning() -> HitHitError {
        HitHitError(code: .alreadyRunning, message: "이미 실행 중입니다.")
    }
    static func storageUnavailable(_ underlying: Error) -> HitHitError {
        HitHitError(code: .storageUnavailable, message: "로컬 저장소에 접근할 수 없습니다.", underlying: underlying)
    }
    static func encodingFailed(_ underlying: Error) -> HitHitError {
        HitHitError(code: .encodingFailed, message: "이벤트 인코딩에 실패했습니다.", underlying: underlying)
    }
    static func uploadFailed(_ underlying: Error?) -> HitHitError {
        HitHitError(code: .uploadFailed, message: "배치 전송에 실패했습니다.", underlying: underlying)
    }
}
