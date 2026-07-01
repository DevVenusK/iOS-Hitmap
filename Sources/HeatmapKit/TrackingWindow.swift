#if canImport(UIKit)
import UIKit
import HeatmapCore

/// 전역 탭 인터셉트용 `UIWindow` 서브클래스.
///
/// `sendEvent`에서 `.began` 터치만 가로채 좌표를 수집으로 넘기고,
/// **반드시 `super.sendEvent`를 호출**해 실제 터치 처리에는 영향을 주지 않는다.
/// 메인스레드 작업은 좌표 계산 + enqueue로 최소화한다(성능 예산 <0.5ms).
public final class TrackingWindow: UIWindow {

    public override func sendEvent(_ event: UIEvent) {
        if event.type == .touches, let touches = event.allTouches {
            for touch in touches where touch.phase == .began {
                let point = touch.location(in: self)
                HeatmapCollector.shared.handleTap(at: point, in: self)
            }
        }
        super.sendEvent(event) // 원래 동작 보존
    }
}

extension UIResponder {
    /// 책임 체인을 따라 이 responder를 소유한 `UIViewController`를 찾는다.
    var owningViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let vc = current as? UIViewController { return vc }
            responder = current.next
        }
        return nil
    }
}
#endif
