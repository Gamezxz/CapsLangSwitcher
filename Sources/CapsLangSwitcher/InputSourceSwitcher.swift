import Carbon
import Carbon.HIToolbox

enum InputSourceSwitcher {

    /// Enabled, selectable keyboard input sources, in the same order the OS input menu uses.
    private static func selectableKeyboardSources() -> [TISInputSource] {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsSelectCapable: true,
        ]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?
            .takeRetainedValue() as? [TISInputSource]
        else { return [] }

        return list.filter { source in
            guard let enabledPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled) else {
                return false
            }
            return Unmanaged<CFBoolean>.fromOpaque(enabledPtr).takeUnretainedValue() == kCFBooleanTrue
        }
    }

    private static func sourceID(_ source: TISInputSource) -> String {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return "" }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    static func localizedName(_ source: TISInputSource) -> String {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { return "?" }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    static func currentSource() -> TISInputSource? {
        TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
    }

    /// Selects the next enabled keyboard input source, wrapping around. Mirrors what the
    /// system "Select next source in Input menu" shortcut does, but we call it ourselves
    /// so there is no OS hotkey-disambiguation delay involved.
    @discardableResult
    static func selectNext() -> TISInputSource? {
        let sources = selectableKeyboardSources()
        guard !sources.isEmpty else { return nil }

        let currentID = currentSource().map(sourceID)
        let currentIndex = sources.firstIndex { sourceID($0) == currentID } ?? 0
        let next = sources[(currentIndex + 1) % sources.count]

        TISSelectInputSource(next)
        return next
    }
}
