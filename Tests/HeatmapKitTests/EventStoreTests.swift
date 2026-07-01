import XCTest
@testable import HeatmapKit
@testable import HeatmapCore

final class EventStoreTests: XCTestCase {

    func test_append_and_count() {
        let store = EventStore(fileURL: TestFiles.tempEventFile())
        XCTAssertEqual(store.count(), 0)
        store.append(.stubTap())
        store.append(.stubTap())
        XCTAssertEqual(store.count(), 2)
    }

    func test_loadBatch_respects_max() {
        let store = EventStore(fileURL: TestFiles.tempEventFile())
        for _ in 0..<5 { store.append(.stubTap()) }
        XCTAssertEqual(store.loadBatch(max: 3).count, 3)
        XCTAssertEqual(store.loadBatch(max: 100).count, 5)
    }

    func test_removeFirst_drops_from_front() {
        let store = EventStore(fileURL: TestFiles.tempEventFile())
        for i in 0..<5 { store.append(.stubTap(screen: "s\(i)")) }
        store.removeFirst(2)
        let remaining = store.loadBatch(max: 100)
        XCTAssertEqual(remaining.count, 3)
        XCTAssertEqual(remaining.first?.screen, "s2")
    }

    func test_roundtrip_preserves_event() {
        let store = EventStore(fileURL: TestFiles.tempEventFile())
        let original = HeatmapEvent.scroll(
            screen: "detail", scrollDepth: 0.65, scrollOffsetY: 1240,
            screenW: 390, screenH: 844, device: "iPhone15,3",
            orientation: .portrait, ts: 99)
        store.append(original)
        XCTAssertEqual(store.loadBatch(max: 1).first, original)
    }

    func test_clear_empties_store() {
        let store = EventStore(fileURL: TestFiles.tempEventFile())
        store.append(.stubTap())
        store.clear()
        XCTAssertEqual(store.count(), 0)
    }
}
