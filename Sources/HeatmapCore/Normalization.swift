import Foundation

/// 좌표 정규화 순수 함수 모음. UIKit/CoreGraphics에 의존하지 않아 어디서든 단위테스트 가능.
public enum Normalization {

    /// 포인트를 뷰 bounds 기준 0~1 비율로 정규화한다.
    ///
    /// - Parameters:
    ///   - px: 뷰 좌표계 상의 x(pt)
    ///   - py: 뷰 좌표계 상의 y(pt)
    ///   - width: 기준 뷰 폭(pt)
    ///   - height: 기준 뷰 높이(pt)
    /// - Returns: 0...1로 clamp된 (x, y). `width`/`height`가 0 이하이면 `nil`.
    public static func normalize(
        px: Double, py: Double, width: Double, height: Double
    ) -> (x: Double, y: Double)? {
        guard width > 0, height > 0 else { return nil }
        return (clamp01(px / width), clamp01(py / height))
    }

    /// 스크롤 깊이를 0~1로 계산한다.
    ///
    /// `depth = offsetY / (contentHeight - viewportHeight)`, 스크롤 불가 시 0.
    public static func scrollDepth(
        offsetY: Double, contentHeight: Double, viewportHeight: Double
    ) -> Double {
        let scrollable = contentHeight - viewportHeight
        guard scrollable > 0 else { return 0 }
        return clamp01(offsetY / scrollable)
    }

    /// 값을 0...1 범위로 clamp.
    public static func clamp01(_ v: Double) -> Double {
        min(1, max(0, v))
    }
}
