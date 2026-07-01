import Foundation

/// 수집 이벤트의 종류.
public enum HeatmapEventType: String, Codable, Sendable {
    case tap
    case scroll
}

/// 디바이스 방향. 같은 방향끼리만 히트맵 집계가 의미를 가진다.
public enum HeatmapOrientation: String, Codable, Sendable {
    case portrait
    case landscape
}

/// 서버로 전송되는 단일 수집 이벤트 (wire format).
///
/// 탭·스크롤을 하나의 flat 스키마로 통일한다. 좌표는 정규화(0~1)되어 있고,
/// 정규화 기준이 된 `screenW`/`screenH`와 `device`/`orientation`을 함께 실어
/// 수집 측이 나중에 어떤 기기든 합쳐 히트맵을 그릴 수 있게 한다.
///
/// - Note: 콘텐츠/입력값/요소 식별자는 절대 담지 않는다. 좌표·화면이름·시간만.
public struct HeatmapEvent: Codable, Equatable, Sendable {

    /// 현재 스키마 버전. 필드 *추가*는 옵셔널이면 non-breaking으로 이 값을 유지한다.
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    /// 이벤트 고유 ID(UUID). 전송 재시도/ACK 유실 시 **서버 측 멱등 dedup**에 사용.
    public let id: String
    public let type: HeatmapEventType
    /// 화면 이름(매핑은 수집 측이 나중에 수행). PII를 넣지 않도록 호스트가 관리.
    public let screen: String

    /// 탭: 정규화 X(0~1). 스크롤: nil.
    public let x: Double?
    /// 탭: 정규화 Y(0~1). 스크롤: nil.
    public let y: Double?

    /// 스크롤: 정규화 깊이(0~1). 탭: nil.
    public let scrollDepth: Double?
    /// 스크롤: 원본 contentOffset.y(참고용). 탭: nil.
    public let scrollOffsetY: Double?

    /// 정규화 기준이 된 화면 폭(pt).
    public let screenW: Double
    /// 정규화 기준이 된 화면 높이(pt).
    public let screenH: Double
    /// 기기 식별자(machine, 예: "iPhone15,3").
    public let device: String
    public let orientation: HeatmapOrientation
    /// epoch milliseconds.
    public let ts: Int64

    public init(
        schemaVersion: Int = HeatmapEvent.currentSchemaVersion,
        id: String = UUID().uuidString,
        type: HeatmapEventType,
        screen: String,
        x: Double?,
        y: Double?,
        scrollDepth: Double?,
        scrollOffsetY: Double?,
        screenW: Double,
        screenH: Double,
        device: String,
        orientation: HeatmapOrientation,
        ts: Int64
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.type = type
        self.screen = screen
        self.x = x
        self.y = y
        self.scrollDepth = scrollDepth
        self.scrollOffsetY = scrollOffsetY
        self.screenW = screenW
        self.screenH = screenH
        self.device = device
        self.orientation = orientation
        self.ts = ts
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, type, screen, x, y
        case scrollDepth, scrollOffsetY, screenW, screenH, device, orientation, ts
    }

    /// 관대한 디코딩: 예전 버퍼에 쌓인 이벤트(id/schemaVersion 없음)도 유실 없이 복원한다.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? HeatmapEvent.currentSchemaVersion
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.type = try c.decode(HeatmapEventType.self, forKey: .type)
        self.screen = try c.decode(String.self, forKey: .screen)
        self.x = try c.decodeIfPresent(Double.self, forKey: .x)
        self.y = try c.decodeIfPresent(Double.self, forKey: .y)
        self.scrollDepth = try c.decodeIfPresent(Double.self, forKey: .scrollDepth)
        self.scrollOffsetY = try c.decodeIfPresent(Double.self, forKey: .scrollOffsetY)
        self.screenW = try c.decode(Double.self, forKey: .screenW)
        self.screenH = try c.decode(Double.self, forKey: .screenH)
        self.device = try c.decode(String.self, forKey: .device)
        self.orientation = try c.decode(HeatmapOrientation.self, forKey: .orientation)
        self.ts = try c.decode(Int64.self, forKey: .ts)
    }
}

public extension HeatmapEvent {

    /// 탭 이벤트 팩토리. 정규화 좌표만 받는다.
    static func tap(
        screen: String,
        x: Double,
        y: Double,
        screenW: Double,
        screenH: Double,
        device: String,
        orientation: HeatmapOrientation,
        ts: Int64
    ) -> HeatmapEvent {
        HeatmapEvent(
            type: .tap, screen: screen,
            x: x, y: y, scrollDepth: nil, scrollOffsetY: nil,
            screenW: screenW, screenH: screenH,
            device: device, orientation: orientation, ts: ts
        )
    }

    /// 스크롤 이벤트 팩토리. 정규화 깊이 + 원본 offset.
    static func scroll(
        screen: String,
        scrollDepth: Double,
        scrollOffsetY: Double,
        screenW: Double,
        screenH: Double,
        device: String,
        orientation: HeatmapOrientation,
        ts: Int64
    ) -> HeatmapEvent {
        HeatmapEvent(
            type: .scroll, screen: screen,
            x: nil, y: nil, scrollDepth: scrollDepth, scrollOffsetY: scrollOffsetY,
            screenW: screenW, screenH: screenH,
            device: device, orientation: orientation, ts: ts
        )
    }
}
