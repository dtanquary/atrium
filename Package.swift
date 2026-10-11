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
        // Resources are copied into the .app by build.sh and found with resource(_:), not Bundle.module.
        .executableTarget(name: "Atrium", dependencies: ["TreeGrowth", "MeanderRiver"], exclude: ["Resources"]),
        .testTarget(name: "AtriumTests", dependencies: ["Atrium"]),
    ]
)
