#if canImport(UIKit)
import UIKit
import HeatmapCore

/// 등록된 스크롤뷰들을 `CADisplayLink`로 샘플링해 스크롤 깊이를 수집한다.
///
/// 스위즐 없이 **명시 등록**만 추적한다. 스크롤뷰는 weak로 보관해 dealloc 시 자동 해제된다.
/// 오프셋이 바뀐 경우에만 이벤트를 방출해 노이즈를 줄인다.
final class ScrollTracker {

    private struct Tracked {
        weak var view: UIScrollView?
        var lastOffsetY: CGFloat
    }

    private weak var pipeline: EventPipeline?
    private let hz: Int
    private var displayLink: CADisplayLink?
    private var tracked: [Tracked] = []

    init(pipeline: EventPipeline, hz: Int) {
        self.pipeline = pipeline
        self.hz = max(1, hz)
    }

    func track(_ scrollView: UIScrollView) {
        guard !tracked.contains(where: { $0.view === scrollView }) else { return }
        tracked.append(Tracked(view: scrollView, lastOffsetY: scrollView.contentOffset.y))
        startIfNeeded()
    }

    func untrack(_ scrollView: UIScrollView) {
        tracked.removeAll { $0.view === scrollView || $0.view == nil }
        stopIfEmpty()
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        tracked.removeAll()
    }

    private func startIfNeeded() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFramesPerSecond = hz
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopIfEmpty() {
        tracked.removeAll { $0.view == nil }
        if tracked.isEmpty {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    @objc private func tick() {
        var stillAlive: [Tracked] = []
        for var item in tracked {
            guard let view = item.view else { continue } // dealloc된 것 제거
            let offsetY = view.contentOffset.y
            if offsetY != item.lastOffsetY {
                emit(for: view, offsetY: offsetY)
                item.lastOffsetY = offsetY
            }
            stillAlive.append(item)
        }
        tracked = stillAlive
        stopIfEmpty()
    }

    private func emit(for view: UIScrollView, offsetY: CGFloat) {
        let depth = Normalization.scrollDepth(
            offsetY: Double(offsetY),
            contentHeight: Double(view.contentSize.height),
            viewportHeight: Double(view.bounds.height)
        )
        let refSize = view.window?.bounds.size ?? view.bounds.size
        let orientation = DeviceInfo.orientation(
            width: Double(refSize.width), height: Double(refSize.height))
        pipeline?.recordScroll(
            depth: depth, offsetY: Double(offsetY),
            screenW: Double(refSize.width), screenH: Double(refSize.height),
            device: DeviceInfo.modelIdentifier, orientation: orientation
        )
    }
}
#endif
