import XCTest
@testable import HeatmapCore

final class TouchClassifierTests: XCTestCase {

    func test_noMovement_isTap() {
        XCTAssertTrue(TouchClassifier.isTap(fromX: 100, fromY: 200, toX: 100, toY: 200))
    }

    func test_smallMovement_withinSlop_isTap() {
        // 약 5pt 이동 → 탭
        XCTAssertTrue(TouchClassifier.isTap(fromX: 100, fromY: 200, toX: 103, toY: 204))
    }

    func test_largeMovement_isNotTap() {
        // 스크롤: 세로로 200pt 이동 → 탭 아님
        XCTAssertFalse(TouchClassifier.isTap(fromX: 100, fromY: 200, toX: 100, toY: 400))
    }

    func test_exactlyAtThreshold_isTap() {
        // 정확히 10pt(가로) → 경계 포함(<=)이므로 탭
        XCTAssertTrue(TouchClassifier.isTap(fromX: 0, fromY: 0, toX: 10, toY: 0, threshold: 10))
    }

    func test_justOverThreshold_isNotTap() {
        XCTAssertFalse(TouchClassifier.isTap(fromX: 0, fromY: 0, toX: 11, toY: 0, threshold: 10))
    }
}
