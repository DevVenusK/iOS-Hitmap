import Foundation
import HeatmapCore

/// 이벤트를 수집해도 되는지 결정하는 **순수 로직**.
///
/// 상태(실행/동의/화면)를 인자로만 받아 부수효과 없이 판정한다 → 파이프라인 없이 단독 테스트 가능.
enum CollectionGate {

    /// `samplingRate`를 안전 범위(0...1)로 정규화한다. NaN/음수/>1을 방어(전량 드롭 방지).
    static func effectiveRate(_ raw: Double) -> Double {
        guard raw.isFinite else { return 1 }
        return min(1, max(0, raw))
    }

    /// 주어진 상태에서 이벤트 수집이 허용되는가?
    ///
    /// - Parameter roll: 0..<1 샘플링 난수(호출자가 주입 → 결정적 테스트 가능).
    static func allows(
        running: Bool,
        consent: Bool,
        screen: String,
        excludedScreens: Set<String>,
        samplingRate: Double,
        roll: Double
    ) -> Bool {
        guard running, consent else { return false }
        guard !excludedScreens.contains(screen) else { return false }
        let rate = effectiveRate(samplingRate)
        return rate >= 1 || roll < rate
    }
}
