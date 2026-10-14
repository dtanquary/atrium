import SpriteKit
import Testing
@testable import Atrium

/// Every wallpaper's scene goes once it's dropped, as Shuffle, Settings' pages and rebuilds drop them all day: nothing
/// it starts as it's built or shown (observers, actions, tasks, shared services' callbacks) may keep hold of it.
/// `presentScene` calls `didMove(to:)` even with no window, so what a scene starts there is covered too. All passed
/// on 2026-10-14. Opt-in, since building every scene again takes 40 s in a debug build:
///
///     LET_GO=1 swift test --filter everySceneIsLetGo
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["LET_GO"] != nil))
func everySceneIsLetGo() async {
    for wallpaper in allScenes {
        weak var dropped: SKScene?
        autoreleasepool {
            let view = WallpaperView(frame: CGRect(x: 0, y: 0, width: 512, height: 320))
            let scene = wallpaper.make(view.frame.size)
            view.presentScene(scene)
            view.presentScene(nil)
            dropped = scene
        }
        try? await Task.sleep(for: .milliseconds(50)) // what it handed to the main queue runs, and lets go
        #expect(dropped == nil, "\(wallpaper.name)'s scene is still alive after being dropped")
    }
}
