import Foundation
import HeatmapCore

/// 이벤트 임시 버퍼 추상화. 파일 기반(`EventStore`)과 인메모리 페이크를 교체할 수 있어
/// 파이프라인을 파일 I/O 없이 테스트할 수 있다(POP·의존성 역전).
///
/// 시각/난수 같은 값 공급자는 프로토콜 대신 클로저(`() -> Int64`, `() -> Double`)로 주입한다
/// — 작은 순수 공급자엔 클로저가 더 함수형이고 가볍다.
protocol EventBuffering: AnyObject {
    func append(_ event: HeatmapEvent)
    func count() -> Int
    /// 앞에서부터 최대 `max` 라인을 스캔해 (디코딩된 이벤트, 스캔한 raw 라인 수).
    func loadSpan(max: Int) -> (events: [HeatmapEvent], lineCount: Int)
    func removeFirst(_ n: Int)
    func clear()
}
