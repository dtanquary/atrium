// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wallpaper",
    platforms: [.macOS(.v15)],
    targets: [
        // Resources are copied into the .app by build.sh and found with resource(_:), not Bundle.module.
        .executableTarget(name: "Wallpaper", exclude: ["Resources"]),
        .testTarget(name: "WallpaperTests", dependencies: ["Wallpaper"]),
    ]
)
