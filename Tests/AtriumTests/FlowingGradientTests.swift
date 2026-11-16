import SpriteKit
import Testing
@testable import Atrium

/// The pools' centres as the shader gets them, two to a column of `u_pools`.
@MainActor private func centres(_ scene: SKScene) throws -> [SIMD2<Float>] {
    let uniforms = scene.children.compactMap { ($0 as? SKSpriteNode)?.shader?.uniformNamed("u_pools") }
    let m = try #require(uniforms.first).matrixFloat4x4Value
    return [m.columns.0, m.columns.1, m.columns.2, m.columns.3].flatMap { [$0.lowHalf, $0.highHalf] }.dropLast(1)
}

/// Each load rolls its own start and paths, so two never open on the same picture.
@MainActor @Test func flowingGradientStartsSomewhereNew() throws {
    let size = CGSize(width: 300, height: 200)
    #expect(try centres(FlowingGradient(size: size)) != centres(FlowingGradient(size: size)))
}
