// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Atrium",
    platforms: [.macOS("26.0")],
    targets: [
        // Meander's river and the ground it writes on: numeric code many times slower unoptimised, which would add
        // seconds to every scene built in a debug `swift test`, so it's always built with -O. A new river is given two
        // hours of past as its scene is built, 90 ms optimised and seconds if not.
        .target(name: "MeanderRiver", swiftSettings: [.unsafeFlags(["-O"])]),
        // Etching's routes and the stamping of one into a display's worth of texels: the same again. A quarter
        // of a million steps are stamped as its scene is built, 120 ms optimised for a 14-inch screen.
        .target(name: "LineRoute", swiftSettings: [.unsafeFlags(["-O"])]),
        // Ant Colony's nest and its ants: the same again. A nest is baked as its scene is built, 70 ms optimised for
        // a 14-inch screen, and its ants are stepped sixty times a second.
        .target(name: "AntNest", swiftSettings: [.unsafeFlags(["-O"])]),
        // Pixel Railway's layouts, scenery and trains, and the drawing of them: the same again. A layout is grown
        // and its scenery marched through as its scene is built, and the trains are drawn into it every frame.
        .target(name: "RailLayout", swiftSettings: [.unsafeFlags(["-O"])]),
        // Resources are copied into the .app by build.sh and found with resource(_:), not Bundle.module.
        .executableTarget(name: "Atrium", dependencies: ["MeanderRiver", "LineRoute", "AntNest", "RailLayout"], exclude: ["Resources"]),
        .testTarget(name: "AtriumTests", dependencies: ["Atrium"]),
    ]
)
