import Cocoa
import CoreGraphics

/// Grabs the physical Caps Lock key at the HID level so the real "toggle caps" behavior
/// never reaches the system, and fires `onTap` the instant the key goes down. Because this
/// runs entirely in-process there is no OS hotkey-disambiguation delay — the switch happens
/// on the same run loop turn as the key press.
final class CapsLockTap {
    private let kVKCapsLock: Int64 = 57
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var wasAlphaShiftSet = false

    var onTap: (() -> Void)?

    var isRunning: Bool { eventTap != nil }

    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let tapSelf = Unmanaged<CapsLockTap>.fromOpaque(refcon).takeUnretainedValue()
                return tapSelf.handle(proxy: proxy, type: type, event: event)
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

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard type == .flagsChanged,
              event.getIntegerValueField(.keyboardEventKeycode) == kVKCapsLock
        else {
            return Unmanaged.passUnretained(event)
        }

        // Each physical tap sends a press event and a release event that carry the
        // *same* AlphaShift bit value as each other (it flips on one tap, flips back
        // on the next). So: fire once per actual change in that bit, in either
        // direction, and ignore the second event of a pair since it repeats the same
        // value we just saw. That gives exactly one switch per physical tap, no delay.
        let isSet = event.flags.contains(.maskAlphaShift)
        let changed = isSet != wasAlphaShiftSet
        wasAlphaShiftSet = isSet

        if changed {
            DispatchQueue.main.async { [onTap] in onTap?() }
        }

        return nil
    }
}
