import Testing
@testable import HeatmapKit

@Suite struct CollectionGateTests {

    @Test func effectiveRateClampsAndDefendsInvalid() {
        #expect(CollectionGate.effectiveRate(0.5) == 0.5)
        #expect(CollectionGate.effectiveRate(2.0) == 1.0)     // >1 → 1
        #expect(CollectionGate.effectiveRate(-1.0) == 0.0)    // 음수 → 0
        #expect(CollectionGate.effectiveRate(.nan) == 1.0)    // NaN → 전량 통과(전량 드롭 방지)
        #expect(CollectionGate.effectiveRate(.infinity) == 1.0)
    }

    @Test func blockedWhenNotRunningOrNoConsent() {
        #expect(!CollectionGate.allows(running: false, consent: true, screen: "s",
                                       excludedScreens: [], samplingRate: 1, roll: 0))
        #expect(!CollectionGate.allows(running: true, consent: false, screen: "s",
                                       excludedScreens: [], samplingRate: 1, roll: 0))
    }

    @Test func blocksExcludedScreenAllowsOthers() {
        #expect(!CollectionGate.allows(running: true, consent: true, screen: "login",
                                       excludedScreens: ["login"], samplingRate: 1, roll: 0))
        #expect(CollectionGate.allows(running: true, consent: true, screen: "home",
                                      excludedScreens: ["login"], samplingRate: 1, roll: 0))
    }

    @Test func samplingComparesRollToRate() {
        // rate 0.3: roll 0.2 통과, roll 0.4 차단
        #expect(CollectionGate.allows(running: true, consent: true, screen: "s",
                                      excludedScreens: [], samplingRate: 0.3, roll: 0.2))
        #expect(!CollectionGate.allows(running: true, consent: true, screen: "s",
                                       excludedScreens: [], samplingRate: 0.3, roll: 0.4))
    }

    @Test func fullSamplingAlwaysAllows() {
        #expect(CollectionGate.allows(running: true, consent: true, screen: "s",
                                      excludedScreens: [], samplingRate: 1.0, roll: 0.999))
    }
}
