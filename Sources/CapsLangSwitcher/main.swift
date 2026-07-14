import Cocoa
import SwiftUI
import Carbon
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let tap = CapsLockTap()
    private var updaterController: SPUStandardUpdaterController!
    private var aboutWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let icon = NSImage(systemSymbolName: "capslock.fill", accessibilityDescription: "CapsLangSwitcher")
        icon?.isTemplate = true // adapts to light/dark menu bar automatically, like other status items
        statusItem.button?.image = icon
        buildMenu()
        updateStatusTitle()

        // Sparkle auto-updater (checks SUFeedURL on launch + daily)
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

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
        // Icon stays fixed; the tooltip shows which input source is active on hover.
        guard let source = InputSourceSwitcher.currentSource() else { return }
        statusItem.button?.toolTip = InputSourceSwitcher.localizedName(source)
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "CapsLangSwitcher", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "About CapsLangSwitcher", action: #selector(openAbout), keyEquivalent: "")
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp // NSApplication.terminate(_:) lives on NSApp, not on this delegate
        menu.addItem(quit)

        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func checkForUpdates() {
        updaterController?.updater.checkForUpdates()
    }

    @objc private func openAbout() {
        if aboutWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "About CapsLangSwitcher"
            w.contentView = NSHostingView(rootView: AboutView())
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            aboutWindow = w
        }
        // Menu-bar app (.accessory) can't receive keyboard focus
        // → switch to .regular temporarily so the window can become key
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    // Return to menu-bar mode when the About window closes (hide from Dock)
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === aboutWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // Restore Caps Lock to normal on quit — otherwise it stays remapped to F18 (a dead key)
    // while the app isn't running to handle it.
    func applicationWillTerminate(_ notification: Notification) {
        tap.clearRemap()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
