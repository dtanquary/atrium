// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Atrium",
    platforms: [.macOS(.v15)],
    targets: [
        // Resources are copied into the .app by build.sh and found with resource(_:), not Bundle.module.
        .executableTarget(name: "Atrium", exclude: ["Resources"]),
        .testTarget(name: "AtriumTests", dependencies: ["Atrium"]),
    ]
)
