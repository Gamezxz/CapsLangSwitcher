import Cocoa
import CoreGraphics

/// Remaps Caps Lock → F18 at the HID level (via `hidutil`), then watches for F18 key-downs.
///
/// The HID remap happens *below* macOS's built-in Caps Lock activation delay (the firmware
/// "hold briefly to engage" behavior on Apple keyboards), so the remapped key fires the
/// instant Caps Lock is pressed — there's no caps-lock lag to wait through, and no
/// `flagsChanged` round-trip. F18 is used because it's a real key code that's virtually
/// never bound to anything, so we can safely swallow it.
final class CapsLockTap {
    private let kVKF18: Int64 = 79

    // HID usage codes for hidutil's UserKeyMapping (usage page 0x07 = keyboard).
    private let capsLockUsage = 0x700000039
    private let f18Usage = 0x70000006D

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onTap: (() -> Void)?
    var isRunning: Bool { eventTap != nil }

    func start() -> Bool {
        guard eventTap == nil else { return true }

        // Remap first, then listen. Only called once Accessibility is granted, so we never
        // leave Caps Lock remapped to a dead key that we can't actually observe.
        applyRemap()

        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)
        )
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let tapSelf = Unmanaged<CapsLockTap>.fromOpaque(refcon).takeUnretainedValue()
                return tapSelf.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard event.getIntegerValueField(.keyboardEventKeycode) == kVKF18 else {
            return Unmanaged.passUnretained(event)
        }

        // Swallow both F18 down and up so the remapped key never reaches any other app.
        // Switch on key-down only, ignoring OS autorepeat, so one physical tap = one switch.
        // Called directly (not dispatched) — the tap already runs on the main run loop, so
        // this is the fastest possible path from key press to input-source switch.
        if type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            onTap?()
        }

        return nil
    }

    // MARK: - HID remap

    func applyRemap() {
        runHidutil(
            "{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":\(capsLockUsage),\"HIDKeyboardModifierMappingDst\":\(f18Usage)}]}"
        )
    }

    /// Restores Caps Lock to its normal behavior. Call on quit so the key isn't left
    /// remapped to a dead F18 while the app isn't running to handle it.
    func clearRemap() {
        runHidutil("{\"UserKeyMapping\":[]}")
    }

    private func runHidutil(_ mapping: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        proc.arguments = ["property", "--set", mapping]
        try? proc.run()
        proc.waitUntilExit()
    }
}
