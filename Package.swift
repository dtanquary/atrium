// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Atrium",
    platforms: [.macOS("26.0")],
    targets: [
        // A Tree for the Year's growth and bake: numeric code a hundred times slower unoptimised, which would add minutes
        // to every debug `swift test`, so it's always built with -O.
        .target(name: "TreeGrowth", swiftSettings: [.unsafeFlags(["-O"])]),
        // Meander's river and the ground it writes on: the same, for the same reason. A new river is given two hours
        // of past as its scene is built, 90 ms optimised and seconds if not.
        .target(name: "MeanderRiver", swiftSettings: [.unsafeFlags(["-O"])]),
        // Line Drawing's routes and the stamping of one into a display's worth of texels: the same again. A quarter
        // of a million steps are stamped as its scene is built, 120 ms optimised for a 14-inch screen.
        .target(name: "LineRoute", swiftSettings: [.unsafeFlags(["-O"])]),
        // Peg Board's lattice: the snow crystal grown on it and the glow stamped as pegs go in. The same again.
        .target(name: "PegLattice", swiftSettings: [.unsafeFlags(["-O"])]),
        // Resources are copied into the .app by build.sh and found with resource(_:), not Bundle.module.
        .executableTarget(name: "Atrium", dependencies: ["TreeGrowth", "MeanderRiver", "LineRoute", "PegLattice"], exclude: ["Resources"]),
        .testTarget(name: "AtriumTests", dependencies: ["Atrium"]),
    ]
)
