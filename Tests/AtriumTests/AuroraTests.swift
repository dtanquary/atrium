import Foundation
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

/// Aurora's stars are the real sky over Teton Point: at 9 pm there on 15 November 2026 the Big Dipper lies low in the
/// north, Dubhe (1.8) 16.5° up a little right of centre and drawn as one of the largest, and nothing is placed under the
/// horizon or off the screen.
@MainActor @Test func auroraStarsAreTheRealSky() {
    let size = CGSize(width: 1512, height: 982)
    let stars = AuroraStars(size: size, at: Date(timeIntervalSince1970: 1_794_801_600)).sprites.filter { !$0.isHidden }
    #expect((100...200).contains(stars.count), "\(stars.count)")
    #expect(stars.allSatisfy { $0.position.y > size.height * 0.26 && $0.position.x > -4 && $0.position.x < size.width + 4 })
    let dubhe = stars.min { hypot($0.position.x - 907.5, $0.position.y - 539.5) < hypot($1.position.x - 907.5, $1.position.y - 539.5) }
    #expect(dubhe.map { hypot($0.position.x - 907.5, $0.position.y - 539.5) < 1.5 } == true)
    #expect(dubhe.map { d in stars.filter { $0.size.width > d.size.width }.count < 6 } == true)
}
