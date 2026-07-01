import Testing
@testable import HeatmapCore

@Suite struct TouchClassifierTests {

    struct Case: Sendable {
        let fx, fy, tx, ty, threshold: Double
        let isTap: Bool
    }

    @Test(arguments: [
        Case(fx: 100, fy: 200, tx: 100, ty: 200, threshold: 10, isTap: true),   // 정지 → 탭
        Case(fx: 100, fy: 200, tx: 103, ty: 204, threshold: 10, isTap: true),   // 5pt → 탭
        Case(fx: 100, fy: 200, tx: 100, ty: 400, threshold: 10, isTap: false),  // 스크롤 → 아님
        Case(fx: 0, fy: 0, tx: 10, ty: 0, threshold: 10, isTap: true),          // 경계(<=) → 탭
        Case(fx: 0, fy: 0, tx: 11, ty: 0, threshold: 10, isTap: false),         // 초과 → 아님
    ])
    func classifiesByMovement(_ c: Case) {
        #expect(TouchClassifier.isTap(
            fromX: c.fx, fromY: c.fy, toX: c.tx, toY: c.ty, threshold: c.threshold) == c.isTap)
    }

    @Test func defaultSlopIsApplied() {
        // 기본 slop(10pt) 안이면 탭.
        #expect(TouchClassifier.isTap(fromX: 0, fromY: 0, toX: 7, toY: 0))
        #expect(!TouchClassifier.isTap(fromX: 0, fromY: 0, toX: 0, toY: 40))
    }
}
