import XCTest
@testable import HeatmapCore

final class NormalizationTests: XCTestCase {

    func test_normalize_center_of_view() throws {
        let r = try XCTUnwrap(Normalization.normalize(px: 195, py: 422, width: 390, height: 844))
        XCTAssertEqual(r.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(r.y, 0.5, accuracy: 0.0001)
    }

    func test_normalize_is_device_independent() throws {
        // 같은 "화면 정중앙 탭"은 기기 크기가 달라도 (0.5, 0.5)로 수렴해야 한다.
        let se = try XCTUnwrap(Normalization.normalize(px: 160, py: 284, width: 320, height: 568))
        let proMax = try XCTUnwrap(Normalization.normalize(px: 215, py: 465, width: 430, height: 930))
        XCTAssertEqual(se.x, proMax.x, accuracy: 0.0001)
        XCTAssertEqual(se.y, proMax.y, accuracy: 0.0001)
    }

    func test_normalize_clamps_out_of_bounds() throws {
        let r = try XCTUnwrap(Normalization.normalize(px: -50, py: 9999, width: 390, height: 844))
        XCTAssertEqual(r.x, 0.0)
        XCTAssertEqual(r.y, 1.0)
    }

    func test_normalize_invalid_bounds_returns_nil() {
        XCTAssertNil(Normalization.normalize(px: 10, py: 10, width: 0, height: 844))
        XCTAssertNil(Normalization.normalize(px: 10, py: 10, width: 390, height: -1))
    }

    func test_scrollDepth_basic() {
        // contentHeight 2000, viewport 800 → scrollable 1200. offset 600 → 0.5
        XCTAssertEqual(Normalization.scrollDepth(offsetY: 600, contentHeight: 2000, viewportHeight: 800), 0.5, accuracy: 0.0001)
    }

    func test_scrollDepth_clamps_and_handles_nonscrollable() {
        XCTAssertEqual(Normalization.scrollDepth(offsetY: 5000, contentHeight: 2000, viewportHeight: 800), 1.0)
        XCTAssertEqual(Normalization.scrollDepth(offsetY: -100, contentHeight: 2000, viewportHeight: 800), 0.0)
        // 콘텐츠가 뷰포트보다 작으면 스크롤 불가 → 0
        XCTAssertEqual(Normalization.scrollDepth(offsetY: 10, contentHeight: 500, viewportHeight: 800), 0.0)
    }
}
