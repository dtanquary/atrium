import SpriteKit
import Testing
@testable import Atrium

/// The shader skips a stem whose radius is 0, so a stem that's gone has to come out as exactly 0, not a sliver over
/// it, or the saving quietly goes. A stem lives only while its head rises or drips, so most are gone most of the time.
@MainActor @Test func lavaLampStemsThatAreGoneAreExactlyZero() throws {
    let scene = try #require(allScenes.first { $0.name == "Lava Lamp" }).make(CGSize(width: 300, height: 200))
    let shader = try #require((scene.children.first as? SKSpriteNode)?.shader)
    let stems = try ["u_blobs2", "u_blobs3"].map { try #require(shader.uniformNamed($0)) }
    var radii: [Float] = []
    var t = 0.0
    while t < 600 {
        t += 0.5
        scene.update(t)
        for m in stems.map(\.matrixFloat4x4Value) { radii += [m.columns.0.z, m.columns.1.z, m.columns.2.z, m.columns.3.z] }
    }
    let gone = Double(radii.filter { $0 == 0 }.count) / Double(radii.count)
    #expect(gone > 0.4 && radii.min()! >= 0, "\(Int(gone * 100))% of stems gone")
}
