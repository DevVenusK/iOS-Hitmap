import Foundation
import HitHitCore

/// 기기 식별자/방향 유틸.
enum DeviceInfo {

    /// machine identifier (예: "iPhone15,3"). 시뮬레이터는 SIMULATOR_MODEL_IDENTIFIER.
    static let modelIdentifier: String = {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return sim
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) { ptr -> String in
            ptr.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return machine.isEmpty ? "unknown" : machine
    }()

    /// 크기로부터 방향 판정.
    static func orientation(width: Double, height: Double) -> HitHitOrientation {
        width > height ? .landscape : .portrait
    }
}
