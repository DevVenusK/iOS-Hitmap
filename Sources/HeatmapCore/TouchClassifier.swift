import Foundation

/// 터치가 탭인지 판별하는 순수 로직(UIKit 무의존 → 단위테스트 가능).
public enum TouchClassifier {

    /// 탭으로 간주하는 기본 이동 허용치(pt). 이보다 많이 움직이면 스크롤/드래그로 본다.
    public static let defaultTapSlop: Double = 10

    /// 시작~종료 이동 거리가 `threshold` 이하이면 탭.
    public static func isTap(
        fromX: Double, fromY: Double, toX: Double, toY: Double,
        threshold: Double = TouchClassifier.defaultTapSlop
    ) -> Bool {
        let dx = toX - fromX
        let dy = toY - fromY
        return (dx * dx + dy * dy).squareRoot() <= threshold
    }
}
