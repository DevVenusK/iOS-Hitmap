import XCTest
@testable import HeatmapCore

final class HeatmapEventTests: XCTestCase {

    func test_tap_factory_sets_scroll_fields_nil() {
        let e = HeatmapEvent.tap(
            screen: "loan_detail", x: 0.42, y: 0.73,
            screenW: 390, screenH: 844, device: "iPhone15,3",
            orientation: .portrait, ts: 1_719_800_000_000
        )
        XCTAssertEqual(e.type, .tap)
        XCTAssertEqual(e.x, 0.42)
        XCTAssertNil(e.scrollDepth)
        XCTAssertNil(e.scrollOffsetY)
        XCTAssertEqual(e.schemaVersion, HeatmapEvent.currentSchemaVersion)
    }

    func test_scroll_factory_sets_tap_fields_nil() {
        let e = HeatmapEvent.scroll(
            screen: "loan_detail", scrollDepth: 0.65, scrollOffsetY: 1240,
            screenW: 390, screenH: 844, device: "iPhone15,3",
            orientation: .portrait, ts: 1_719_800_000_000
        )
        XCTAssertEqual(e.type, .scroll)
        XCTAssertNil(e.x)
        XCTAssertNil(e.y)
        XCTAssertEqual(e.scrollDepth, 0.65)
    }

    func test_codable_roundtrip() throws {
        let e = HeatmapEvent.tap(
            screen: "home", x: 0.1, y: 0.2, screenW: 390, screenH: 844,
            device: "iPhone15,3", orientation: .portrait, ts: 42
        )
        let data = try JSONEncoder().encode(e)
        let decoded = try JSONDecoder().decode(HeatmapEvent.self, from: data)
        XCTAssertEqual(e, decoded)
    }

    func test_json_field_names_match_wire_contract() throws {
        let e = HeatmapEvent.scroll(
            screen: "s", scrollDepth: 0.5, scrollOffsetY: 100,
            screenW: 390, screenH: 844, device: "iPhone15,3",
            orientation: .portrait, ts: 7
        )
        let obj = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(e)) as? [String: Any]
        let keys = Set((obj ?? [:]).keys)
        for k in ["schemaVersion", "id", "type", "screen", "screenW", "screenH", "device", "orientation", "ts", "scrollDepth", "scrollOffsetY"] {
            XCTAssertTrue(keys.contains(k), "wire 필드 누락: \(k)")
        }
    }

    func test_decoding_ignores_unknown_future_field() throws {
        // forward-compat: 미지 필드는 무시하고 디코딩되어야 한다.
        let json = """
        {"schemaVersion":1,"type":"tap","screen":"x","x":0.5,"y":0.5,
         "screenW":390,"screenH":844,"device":"iPhone15,3",
         "orientation":"portrait","ts":1,"futureField":"ignored"}
        """.data(using: .utf8)!
        XCTAssertNoThrow(try JSONDecoder().decode(HeatmapEvent.self, from: json))
    }
}
