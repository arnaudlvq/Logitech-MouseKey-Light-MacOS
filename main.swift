// mousekeys: map mouse buttons to Ctrl+Arrow. Event-driven, so it sits at 0% CPU when idle.
//   mousekeys learn   press 4 inputs (for Ctrl+Up, Down, Left, Right) and save them to the config
//   mousekeys         run with the saved mapping (needs Accessibility permission)
import CoreGraphics

let configDir = String(cString: getenv("HOME")) + "/.config"
let configPath = configDir + "/mousekeys.conf"
let arrowKeys: [String: CGKeyCode] = ["left": 123, "right": 124, "down": 125, "up": 126]
let learnOrder = ["up", "down", "left", "right"]

nonisolated(unsafe) var tap: CFMachPort?
nonisolated(unsafe) var mapping: [String: CGKeyCode] = [:]
nonisolated(unsafe) var learned: [String] = []
nonisolated(unsafe) var lastScroll = (name: "", time: CGEventTimestamp(0))

// "button3" for extra buttons (2 = middle), "hscroll+" / "hscroll-" for wheel tilt or a horizontal wheel.
func inputName(_ type: CGEventType, _ e: CGEvent) -> String? {
    switch type {
    case .otherMouseDown, .otherMouseUp:
        return "button\(e.getIntegerValueField(.mouseEventButtonNumber))"
    case .scrollWheel:
        // Trackpad scrolling is "continuous"; leave it alone so two-finger swipes keep working.
        if e.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 { return nil }
        let dx = e.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        return dx == 0 ? nil : (dx > 0 ? "hscroll+" : "hscroll-")
    default:
        return nil
    }
}

// Holding the wheel tilt sends a burst of scroll events; only the first one after 0.4s of quiet counts.
func isNewScroll(_ name: String, _ e: CGEvent) -> Bool {
    let now = e.timestamp  // nanoseconds since boot
    defer { lastScroll = (name, now) }
    return name != lastScroll.name || now > lastScroll.time + 400_000_000
}

func press(_ key: CGKeyCode) {
    let src = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        guard let e = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: down) else { continue }
        // Arrow keys carry the fn flag; the system Ctrl+Arrow shortcuts only match with it set.
        e.flags = [.maskControl, .maskSecondaryFn]
        e.post(tap: .cghidEventTap)
    }
}

let runCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    guard let name = inputName(type, event), let key = mapping[name] else {
        return Unmanaged.passUnretained(event)
    }
    if type == .otherMouseDown || (type == .scrollWheel && isNewScroll(name, event)) { press(key) }
    return nil  // swallow the mapped button (and its mouse-up) so apps don't also see it
}

let learnCallback: CGEventTapCallBack = { _, type, event, _ in
    guard let name = inputName(type, event) else { return Unmanaged.passUnretained(event) }
    if type == .scrollWheel && !isNewScroll(name, event) { return Unmanaged.passUnretained(event) }
    if learned.contains(name) {
        print("  \(name) already used, ignored")
    } else {
        learned.append(name)
        print("  Ctrl+\(learnOrder[learned.count - 1]) <- \(name)")
        if learned.count == learnOrder.count {
            mkdir(configDir, 0o755)
            guard let f = fopen(configPath, "w") else { print("Could not write \(configPath)"); exit(1) }
            for (input, action) in zip(learned, learnOrder) { fputs("\(input) \(action)\n", f) }
            fclose(f)
            print("Saved \(configPath)")
            exit(0)
        }
    }
    fflush(stdout)
    return Unmanaged.passUnretained(event)
}

let learning = CommandLine.arguments.dropFirst().first == "learn"
if learning {
    print("Press the input for Ctrl+Up, then Ctrl+Down, Ctrl+Left, Ctrl+Right:")
    fflush(stdout)
} else if let f = fopen(configPath, "r") {
    // Config lines look like "button3 up".
    var line: UnsafeMutablePointer<CChar>?
    var size = 0
    while getline(&line, &size, f) > 0 {
        let parts = String(cString: line!).split(whereSeparator: { $0 == " " || $0 == "\n" })
        if parts.count == 2, let key = arrowKeys[String(parts[1])] { mapping[String(parts[0])] = key }
    }
    fclose(f)
}
if !learning && mapping.isEmpty { print("No mapping in \(configPath); run: mousekeys learn"); exit(1) }

let mask = [CGEventType.otherMouseDown, .otherMouseUp, .scrollWheel]
    .reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                        options: learning ? .listenOnly : .defaultTap, eventsOfInterest: mask,
                        callback: learning ? learnCallback : runCallback, userInfo: nil)
// Without Accessibility permission this fails; launchd retries every 10s until it is granted.
guard let tap else { print("Could not create event tap: allow mousekeys in Accessibility"); exit(1) }
CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
if !learning { print("Active: \(mapping.count) inputs mapped"); fflush(stdout) }
CFRunLoopRun()
