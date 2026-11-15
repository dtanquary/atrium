import Testing
@testable import Atrium

/// Aurora's substorms come and go: over six hours of phase at Moderate a surge every 20-30 minutes, each reaching
/// its peak and falling back to rest; Quiet surges less often and less high, Active more often; and a wait carried
/// over from Quiet is cut short on turning to Active.
@Test func auroraSubstormsComeAndGo() {
    func run(_ activity: Int) -> (surges: Int, top: Float, bottom: Float) {
        var storms = Substorms(activity: activity, rng: SplitMix(state: 7))
        var surges = 0, top: Float = -9, bottom: Float = 9, high = false
        let a = Substorms.activities[activity]
        for _ in 0..<(6 * 3600) {
            storms.advance(1)
            top = max(top, storms.level)
            bottom = min(bottom, storms.level)
            if !high, storms.level > a.rest + 0.9 * a.strength { (surges, high) = (surges + 1, true) }
            if storms.level < a.rest + 0.5 * a.strength { high = false }
        }
        return (surges, top, bottom)
    }
    let quiet = run(0), moderate = run(1), active = run(2)
    #expect((12...18).contains(moderate.surges), "\(moderate)")
    #expect(moderate.top <= 1.001 && moderate.bottom >= -0.001)
    #expect(quiet.surges < moderate.surges && active.surges > moderate.surges, "\(quiet) \(active)")
    #expect(quiet.top < moderate.top && quiet.bottom < 0 && active.bottom > 0)

    var storms = Substorms(activity: 0, rng: SplitMix(state: 7))
    storms.sinceOnset = -40 * 60
    storms.activity = 2
    storms.advance(1)
    #expect(storms.sinceOnset >= -9 * 60)
}
