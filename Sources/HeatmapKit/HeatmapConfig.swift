import Foundation
import HeatmapCore

/// 수집·전송 동작을 제어하는 설정.
public struct HeatmapConfig {

    /// 배치를 전송할 서버 엔드포인트.
    public var endpoint: URL
    /// 전송 요청에 실을 헤더(인증 등).
    public var headers: [String: String]
    /// 수집에서 제외할 화면 이름(민감화면). 탭·스크롤 모두 차단.
    public var excludedScreens: Set<String>
    /// 0...1. 1.0이면 전량 수집. 미만이면 확률적 샘플링.
    public var samplingRate: Double
    /// 스크롤 샘플링 주파수(Hz). 기본 10.
    public var scrollSampleHz: Int
    /// 한 배치 최대 이벤트 수. 기본 500.
    public var maxBatchSize: Int
    /// 자동 flush 주기(초). 기본 30.
    public var flushInterval: TimeInterval
    /// 로컬 저장 디렉토리. nil이면 앱 caches.
    public var storageDirectory: URL?
    /// 커스텀 전송기. nil이면 내장 HTTP 전송기 사용.
    public var uploader: HeatmapUploader?

    public init(endpoint: URL) {
        self.endpoint = endpoint
        self.headers = [:]
        self.excludedScreens = []
        self.samplingRate = 1.0
        self.scrollSampleHz = 10
        self.maxBatchSize = 500
        self.flushInterval = 30
        self.storageDirectory = nil
        self.uploader = nil
    }
}
