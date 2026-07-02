import Testing
@testable import HitHitCore

@Suite struct NormalizationTests {

    @Test func centerNormalizesToHalf() throws {
        let r = try #require(Normalization.normalize(px: 195, py: 422, width: 390, height: 844))
        #expect(abs(r.x - 0.5) < 1e-9)
        #expect(abs(r.y - 0.5) < 1e-9)
    }

    @Test func sameScreenPointIsDeviceIndependent() throws {
        // 화면 정중앙은 기기 크기가 달라도 (0.5, 0.5)로 수렴해야 한다.
        let se = try #require(Normalization.normalize(px: 160, py: 284, width: 320, height: 568))
        let proMax = try #require(Normalization.normalize(px: 215, py: 465, width: 430, height: 930))
        #expect(abs(se.x - proMax.x) < 1e-9)
        #expect(abs(se.y - proMax.y) < 1e-9)
    }

    @Test func clampsOutOfBounds() throws {
        let r = try #require(Normalization.normalize(px: -50, py: 9999, width: 390, height: 844))
        #expect(r.x == 0)
        #expect(r.y == 1)
    }

    @Test(arguments: [(0.0, 844.0), (390.0, 0.0), (-1.0, 10.0)])
    func invalidBoundsReturnNil(_ dim: (Double, Double)) {
        #expect(Normalization.normalize(px: 10, py: 10, width: dim.0, height: dim.1) == nil)
    }

    struct ScrollCase: Sendable {
        let offset, content, viewport, expected: Double
    }

    @Test(arguments: [
        ScrollCase(offset: 600, content: 2000, viewport: 800, expected: 0.5),
        ScrollCase(offset: 5000, content: 2000, viewport: 800, expected: 1.0),   // 넘침 → 1
        ScrollCase(offset: -100, content: 2000, viewport: 800, expected: 0.0),   // 음수 → 0
        ScrollCase(offset: 10, content: 500, viewport: 800, expected: 0.0),      // 스크롤 불가 → 0
    ])
    func scrollDepth(_ c: ScrollCase) {
        let depth = Normalization.scrollDepth(
            offsetY: c.offset, contentHeight: c.content, viewportHeight: c.viewport)
        #expect(abs(depth - c.expected) < 1e-9)
    }
}
