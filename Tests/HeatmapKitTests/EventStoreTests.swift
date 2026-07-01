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

    // MARK: - H3: 손상 라인이 있어도 라인 단위 정렬로 중복/유실 없음

    func test_loadSpan_countsCorruptLinesForAlignment() throws {
        let url = TestFiles.tempEventFile()
        let store = EventStore(fileURL: url)
        store.append(.stubTap(screen: "good"))
        // 앱 강제종료로 잘린 것처럼 손상 라인을 파일에 직접 추가
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{corrupt-partial\n".utf8))
        try handle.close()

        let span = store.loadSpan(max: 10)
        XCTAssertEqual(span.events.count, 1, "유효 이벤트만 디코딩")
        XCTAssertEqual(span.lineCount, 2, "손상 라인도 라인 수에는 포함(정렬 기준)")

        store.removeFirst(span.lineCount)   // 라인 수 기준 제거
        XCTAssertEqual(store.loadSpan(max: 10).lineCount, 0, "손상 라인까지 정리 → 중복/블록 없음")
    }
}
