import Foundation
import XCTest
@testable import HeatmapKit
@testable import HeatmapCore

/// 주입용 가짜 전송기. 결과 스크립트를 순서대로 반환한다.
final class FakeUploader: HeatmapUploader {
    var scriptedResults: [Result<Void, Error>]
    private(set) var uploadedBatches: [Data] = []
    private var index = 0

    init(results: [Result<Void, Error>] = [.success(())]) {
        self.scriptedResults = results
    }

    func upload(batch: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        uploadedBatches.append(batch)
        let result = index < scriptedResults.count ? scriptedResults[index] : (scriptedResults.last ?? .success(()))
        index += 1
        completion(result)
    }
}

enum TestFiles {
    /// 매 테스트마다 고유한 임시 JSONL 경로.
    static func tempEventFile(_ name: String = "events") -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("heatmap-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(name).jsonl")
    }
}

extension HeatmapEvent {
    static func stubTap(screen: String = "s") -> HeatmapEvent {
        .tap(screen: screen, x: 0.5, y: 0.5, screenW: 390, screenH: 844,
             device: "iPhone15,3", orientation: .portrait, ts: 1)
    }
}
