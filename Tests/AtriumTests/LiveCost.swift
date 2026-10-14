import AppKit
import Darwin
import SpriteKit
import Testing
@testable import Atrium

/// What each wallpaper really costs on the desktop: a desktop-level window over the main screen with a `WallpaperView`
/// at each frame rate, as the app shows it, measured over seconds of real frames, a 60th or 30th of a second apart on
/// a core left to clock down between them. The render test's hot loop under-reports this several times over.
/// One line per scene and rate, and a TSV: the process's CPU time per second and the share of it on performance
/// cores (under load the scheduler moves it to efficiency cores, where the same work takes longer and less energy),
/// its GPU time, the kernel's energy estimate (mW), frames drawn, hitches (gaps over 1.5 frames) and the longest gap,
/// the footprint after warm-up and how much of it came with this scene (less what the last one gave back meanwhile),
/// and the build time; and WindowServer's CPU, GPU and energy impact over the same seconds,
/// since it composites every frame drawn. A frozen view comes first, for what a window costs with nothing drawing,
/// and a line with no window at all last, for work a scene left running. WindowServer's numbers carry whatever else is
/// on screen, and shrink as other windows cover the desktop.
/// Settings are the test domain's (`swiftpm-testing-helper`), so standard unless a throwaway test left one there.
///
///     LIVE_COST=1 swift test -c release -Xswiftc -enable-testing --filter liveCost   # → $TMPDIR/atrium-livecost.tsv
///     LIVE_COST_SCENE="Nebula,Wind" LIVE_COST_FPS=30 LIVE_COST_SECONDS=25 LIVE_COST_OUT=/some/file.tsv …
///     LIVE_COST_SAMPLE=/some/dir …   # also `sample` the process while each scene is measured, into that folder
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["LIVE_COST"] != nil))
func liveCost() async throws {
    let env = ProcessInfo.processInfo.environment
    let names = env["LIVE_COST_SCENE"].map { Set($0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }) }
    let rates = (env["LIVE_COST_FPS"] ?? "60,30").split(separator: ",").compactMap { Int($0) }
    let seconds = Double(env["LIVE_COST_SECONDS"] ?? "") ?? 15
    let out = env["LIVE_COST_OUT"] ?? NSTemporaryDirectory() + "atrium-livecost.tsv"
    let chosen = allScenes.filter { names?.contains($0.name) ?? true }
    let first = try #require(chosen.first, "no wallpaper named \(names ?? [])")
    // No App Nap, and no display sleep: a view on a sleeping display draws nothing.
    let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleDisplaySleepDisabled], reason: "Measuring wallpapers")
    defer { ProcessInfo.processInfo.endActivity(activity) }
    NSApplication.shared.setActivationPolicy(.accessory)
    let screen = try #require(NSScreen.screens.first)

    var rows = ["scene\tfps\tachieved fps\tcovered\tcpu ms/s\tP-core %\tgpu ms/s\tenergy mW\thitches\tmax gap ms\tfootprint MB\tgrowth MB\tbuild ms\tWindowServer cpu %\tWindowServer gpu ms/s\tWindowServer power"]
    func run(_ wallpaper: Wallpaper?, fps: Int) async {
        let row = await measure(wallpaper, fps: fps, on: screen, seconds: seconds, sample: env["LIVE_COST_SAMPLE"])
        print(row.replacingOccurrences(of: "\t", with: "  "))
        rows.append(row)
    }
    await run(first, fps: 0)
    for wallpaper in chosen { for fps in rates { await run(wallpaper, fps: fps) } }
    await run(nil, fps: 0)
    try (rows.joined(separator: "\n") + "\n").write(toFile: out, atomically: true, encoding: .utf8)
    print("→ \(out)")
}

/// Shows one wallpaper at `fps` (0: frozen on its first frame; no wallpaper: no window) and returns its TSV line.
@MainActor private func measure(_ wallpaper: Wallpaper?, fps: Int, on screen: NSScreen, seconds: Double, sample: String?) async -> String {
    WallpaperTime.restart()
    let bare = vmInfo().phys_footprint
    var build = 0.0, window: NSWindow?, view: WallpaperView?, counter: FrameCounter?
    if let wallpaper {
        // As `wallpaperWindow` in main.swift makes it.
        let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.ignoresMouseEvents = true
        w.isReleasedWhenClosed = false
        let v = WallpaperView()
        v.preferredFramesPerSecond = max(fps, 1)
        v.frozen = fps == 0
        let start = Date()
        let scene = wallpaper.make(screen.frame.size)
        build = Date().timeIntervalSince(start) * 1000
        v.presentScene(scene)
        w.contentView = v
        counter = FrameCounter(v) // after the window, where WallpaperView makes itself its own delegate
        w.orderFront(nil)
        v.wake(for: 0.5) // as its occlusion change would: a frozen view draws its first frame
        (window, view) = (w, v)
    }
    var covered = false
    // The view draws while the main actor sleeps; nothing runs the app's event loop here, so its events are handed on
    // by hand, or the window would never learn it's visible. A view left paused though uncovered (three lines of 128
    // drew nothing that way) is set going. So is a covered one, which pauses itself as it should, but its line
    // says covered and isn't to be trusted: SpriteKit can tick its frames yet draw next to nothing into a covered
    // window (GPU near 0 on some such lines), and WindowServer has less to composite.
    func spin(until end: Date) async {
        while Date() < end {
            try? await Task.sleep(for: .seconds(min(0.25, max(0, end.timeIntervalSinceNow))))
            while let event = NSApp.nextEvent(matching: .any, until: nil, inMode: .default, dequeue: true) { NSApp.sendEvent(event) }
            guard let window, let view, fps > 0 else { continue }
            if !window.occlusionState.contains(.visible) { covered = true }
            view.isPaused = false
        }
    }
    await spin(until: Date() + 3)

    covered = false // from here on: a window still appearing isn't covered
    let windowServer = launch("/usr/bin/top", ["-l", "2", "-s", "\(Int(seconds.rounded()))", "-pid", "\(windowServerPID)", "-stats", "pid,cpu,power"])
    let sampler = sample.map { dir in
        launch("/usr/bin/sample", ["\(getpid())", "\(max(1, Int(seconds) - 2))", "-file", dir + "/\(wallpaper?.name ?? "none")-\(fps).txt"])
    }
    let before = (cpu: clock_gettime_nsec_np(CLOCK_PROCESS_CPUTIME_ID), power: powerInfo(), gpu: gpuTimes(), at: Date())
    counter?.times = []
    let footprint = vmInfo().phys_footprint
    await spin(until: before.at + seconds)
    let after = (cpu: clock_gettime_nsec_np(CLOCK_PROCESS_CPUTIME_ID), power: powerInfo(), gpu: gpuTimes(), at: Date())
    let wall = after.at.timeIntervalSince(before.at)
    windowServer.waitUntilExit()
    sampler?.waitUntilExit()

    let times = counter?.times ?? []
    let gaps = zip(times, times.dropFirst()).map { $1 - $0 }
    let hitches = fps > 0 ? gaps.filter { $0 > 1.5 / Double(fps) }.count : 0
    // The last sample of `top -l 2` is WindowServer over the interval: "pid  %cpu  power".
    let output = String(decoding: (windowServer.standardOutput as! Pipe).fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    let ws = output.split(separator: "\n").last { $0.split(separator: " ").count == 3 && Int($0.split(separator: " ")[0]) != nil }?
        .split(separator: " ").dropFirst().map(String.init) ?? ["?", "?"]

    view?.presentScene(nil)
    window?.contentView = nil
    window?.close()
    let perSecond = { (ns: UInt64) in String(format: "%.1f", Double(ns) / 1e6 / wall) } // ns → ms per second; nJ → mW
    let gpu = { (pid: pid_t) in perSecond((after.gpu[pid] ?? 0) - (before.gpu[pid] ?? 0)) }
    let pCores = Double(after.power.task_ptime - before.power.task_ptime) / Double(max(1, after.cpu - before.cpu)) * 100
    return [wallpaper?.name ?? "(no window)", "\(fps)", String(format: "%.1f", Double(times.count) / wall), covered ? "yes" : "no",
            perSecond(after.cpu - before.cpu), String(format: "%.0f", pCores), gpu(getpid()),
            perSecond(after.power.task_energy - before.power.task_energy),
            "\(hitches)", String(format: "%.0f", (gaps.max() ?? 0) * 1000), String(format: "%.0f", Double(footprint) / 1_048_576),
            String(format: "%.0f", (Double(footprint) - Double(bare)) / 1_048_576), String(format: "%.0f", build),
            ws[0], gpu(windowServerPID), ws[1]].joined(separator: "\t")
}

/// Counts the frames a `WallpaperView` draws, standing in as its delegate and handing each frame on to it.
@MainActor private final class FrameCounter: NSObject, SKViewDelegate {
    let view: WallpaperView
    var times: [TimeInterval] = []

    init(_ view: WallpaperView) {
        self.view = view
        super.init()
        view.delegate = self
    }

    nonisolated func view(_ skView: SKView, shouldRenderAtTime time: TimeInterval) -> Bool {
        MainActor.assumeIsolated {
            times.append(time)
            return view.view(skView, shouldRenderAtTime: time)
        }
    }
}

/// WindowServer's process, which composites every frame drawn: `proc_pid_rusage` and `proc_pidinfo` are refused on it
/// without root, so its CPU comes from `top` and its GPU from the accelerator's own count.
private let windowServerPID: pid_t = {
    let pgrep = launch("/usr/bin/pgrep", ["-x", "WindowServer"])
    pgrep.waitUntilExit()
    return pid_t(String(decoding: (pgrep.standardOutput as! Pipe).fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
}()

/// GPU time so far, in ns, of each process with a Metal device open, as the GPU driver counts it for Activity Monitor.
private func gpuTimes() -> [pid_t: UInt64] {
    let ioreg = launch("/usr/sbin/ioreg", ["-a", "-r", "-d", "1", "-c", "AGXDeviceUserClient"])
    let data = (ioreg.standardOutput as! Pipe).fileHandleForReading.readDataToEndOfFile()
    let clients = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [[String: Any]] ?? []
    var times: [pid_t: UInt64] = [:]
    for client in clients {
        // "pid 631, WindowServer"
        guard let pid = (client["IOUserClientCreator"] as? String)?.split(separator: ",").first?.split(separator: " ").last.flatMap({ pid_t($0) }) else { continue }
        for usage in client["AppUsage"] as? [[String: Any]] ?? [] { times[pid, default: 0] += (usage["accumulatedGPUTime"] as? NSNumber)?.uint64Value ?? 0 }
    }
    return times
}

private func launch(_ path: String, _ arguments: [String]) -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    process.standardOutput = Pipe()
    process.standardError = FileHandle.nullDevice
    try? process.run()
    return process
}

/// The kernel's power accounting for this process: `task_energy`, its estimate of the energy used in nJ (Apple silicon
/// only), and `task_ptime`, the CPU time on performance cores. Its `task_gpu_utilisation` stays at 0 for SpriteKit's
/// work here (checked 2026-10-13), so GPU time comes from `gpuTimes`.
private func powerInfo() -> task_power_info_v2 {
    var info = task_power_info_v2()
    var count = mach_msg_type_number_t(MemoryLayout<task_power_info_v2>.size / MemoryLayout<natural_t>.size)
    _ = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_POWER_INFO_V2), $0, &count) }
    }
    return info
}

private func vmInfo() -> task_vm_info_data_t {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    _ = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
    }
    return info
}
