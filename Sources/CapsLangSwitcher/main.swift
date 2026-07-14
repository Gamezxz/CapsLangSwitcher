import Cocoa
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let tap = CapsLockTap()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.title = "…"
        buildMenu()
        updateStatusTitle()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(updateStatusTitle),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )

        guard AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        ) else {
            promptForAccessibility()
            return
        }

        startTap()
    }

    private func startTap() {
        tap.onTap = { [weak self] in
            InputSourceSwitcher.selectNext()
            self?.updateStatusTitle()
        }
        if !tap.start() {
            let alert = NSAlert()
            alert.messageText = "Couldn't start Caps Lock capture"
            alert.informativeText = "Grant Accessibility access to CapsLangSwitcher in System Settings > Privacy & Security, then relaunch."
            alert.runModal()
        }
    }

    private func promptForAccessibility() {
        // Poll until the user grants access in System Settings, then start the tap.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            if AXIsProcessTrusted() {
                self.startTap()
            } else {
                self.promptForAccessibility()
            }
        }
    }

    @objc private func updateStatusTitle() {
        guard let source = InputSourceSwitcher.currentSource() else {
            statusItem.button?.title = "⌨️"
            return
        }
        let name = InputSourceSwitcher.localizedName(source)
        statusItem.button?.title = String(name.prefix(2)).uppercased()
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "CapsLangSwitcher", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
