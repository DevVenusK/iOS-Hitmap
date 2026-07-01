import Testing
import Foundation
@testable import HeatmapCore

@Suite struct HeatmapEventTests {

    @Test func tapFactoryLeavesScrollFieldsNil() {
        let e = HeatmapEvent.tap(
            screen: "loan_detail", x: 0.42, y: 0.73,
            screenW: 390, screenH: 844, device: "iPhone15,3",
            orientation: .portrait, ts: 1_719_800_000_000)
        #expect(e.type == .tap)
        #expect(e.x == 0.42)
        #expect(e.scrollDepth == nil)
        #expect(e.scrollOffsetY == nil)
        #expect(e.schemaVersion == HeatmapEvent.currentSchemaVersion)
    }

    @Test func scrollFactoryLeavesTapFieldsNil() {
        let e = HeatmapEvent.scroll(
            screen: "loan_detail", scrollDepth: 0.65, scrollOffsetY: 1240,
            screenW: 390, screenH: 844, device: "iPhone15,3",
            orientation: .portrait, ts: 1)
        #expect(e.type == .scroll)
        #expect(e.x == nil)
        #expect(e.y == nil)
        #expect(e.scrollDepth == 0.65)
    }

    @Test func codableRoundTripIsLossless() throws {
        let e = HeatmapEvent.tap(
            screen: "home", x: 0.1, y: 0.2, screenW: 390, screenH: 844,
            device: "iPhone15,3", orientation: .portrait, ts: 42)
        let data = try JSONEncoder().encode(e)
        let decoded = try JSONDecoder().decode(HeatmapEvent.self, from: data)
        #expect(decoded == e)
    }

    @Test func eachEventHasUniqueId() {
        let a = HeatmapEvent.stubTapCore()
        let b = HeatmapEvent.stubTapCore()
        #expect(a.id != b.id)
    }

    @Test func wireContractContainsAllFields() throws {
        let e = HeatmapEvent.scroll(
            screen: "s", scrollDepth: 0.5, scrollOffsetY: 100,
            screenW: 390, screenH: 844, device: "iPhone15,3",
            orientation: .portrait, ts: 7)
        let obj = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(e)) as? [String: Any])
        let keys = Set(obj.keys)
        for k in ["schemaVersion", "id", "type", "screen", "screenW", "screenH",
                  "device", "orientation", "ts", "scrollDepth", "scrollOffsetY"] {
            #expect(keys.contains(k), "wire 필드 누락: \(k)")
        }
    }

    @Test func decodingToleratesMissingIdAndUnknownFields() throws {
        // 구버전 버퍼(id/schemaVersion 없음) + 미래 필드도 유실 없이 디코딩.
        let json = """
        {"type":"tap","screen":"x","x":0.5,"y":0.5,
         "screenW":390,"screenH":844,"device":"iPhone15,3",
         "orientation":"portrait","ts":1,"futureField":"ignored"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(HeatmapEvent.self, from: json)
        #expect(decoded.screen == "x")
        #expect(!decoded.id.isEmpty)   // 누락 시 자동 생성
    }
}

private extension HeatmapEvent {
    static func stubTapCore() -> HeatmapEvent {
        .tap(screen: "s", x: 0.5, y: 0.5, screenW: 390, screenH: 844,
             device: "d", orientation: .portrait, ts: 1)
    }
}
