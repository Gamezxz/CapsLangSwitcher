<p align="center">
  <img src="assets/logo.png" width="120" alt="CapsLangSwitcher logo">
</p>

<h1 align="center">CapsLangSwitcher</h1>

<p align="center">
  Tap Caps Lock, switch input languages — instantly. No macOS hotkey delay, ever.
</p>

## Why

On macOS, binding Caps Lock to "switch input source" goes through the system's
hotkey-disambiguation logic, which adds a noticeable delay before the switch
actually happens — especially annoying for Thai/English (ก/A) switching. On top
of that, Apple's built-in keyboards apply a firmware "hold briefly to engage"
delay to Caps Lock itself, so even a custom app that watches the caps-lock state
change (`flagsChanged`) still has to wait that delay out.

CapsLangSwitcher sidesteps both. It remaps Caps Lock → **F18** at the HID level
using `hidutil` — a remap that happens *below* the caps-lock activation delay, so
the key fires as an ordinary key-down the instant it's pressed. The app then
watches for F18 via a `CGEventTap`, swallows it, and calls the Text Input Source
Services API (`TISSelectInputSource`) directly, in-process. No OS hotkey
subsystem, no caps-lock firmware delay, nothing to wait on.

## Features

- **Zero-delay switching** — bypasses the OS hotkey-disambiguation delay entirely
- **Real Caps Lock repurposed** — the physical key never triggers actual caps
  lock while the app is running
- **Cycles any input sources** — works with however many keyboard layouts you
  have enabled, not hardcoded to Thai/English
- **Lives in the menu bar** — shows the current input source, no Dock icon
- **Featherweight** — pure Swift, no Electron, tiny binary
- **Auto-updates** — checks GitHub for new releases via Sparkle, in-app

## Install

Download the latest build from [Releases](https://github.com/Gamezxz/CapsLangSwitcher/releases),
unzip, and move `CapsLangSwitcher.app` to `/Applications`.

Signed with a Developer ID and notarized by Apple — just double-click to open,
no Gatekeeper warnings.

### Build from source

```bash
git clone https://github.com/Gamezxz/CapsLangSwitcher.git
cd CapsLangSwitcher
./build_app.sh
open CapsLangSwitcher.app
```

Requires Xcode Command Line Tools (Swift 5.9+).

## Setup

1. Launch the app once — it will prompt for **Accessibility** access
   (System Settings → Privacy & Security → Accessibility). Allow it. Once
   granted, the app applies the Caps Lock → F18 remap automatically.
2. Go to System Settings → Keyboard → Keyboard Shortcuts → Input Sources, and
   turn off any existing shortcut bound to Caps Lock (e.g. "Select previous
   input source") so it doesn't fight with the app.
3. Tap Caps Lock. Your input source switches immediately.

While the app runs, Caps Lock is fully repurposed (no actual caps-lock toggle).
The remap is restored to normal on quit. If the app is force-killed, Caps Lock
stays remapped until you relaunch it or log out; run
`hidutil property --set '{"UserKeyMapping":[]}'` to reset it by hand.

## How it works

- `CapsLockTap.swift` — on start, remaps Caps Lock (HID usage `0x700000039`) →
  F18 (`0x70000006D`) via `hidutil property --set`. Then a `CGEventTap` at
  `.cghidEventTap` watches for F18 key-downs (keycode 79), swallows them
  (`return nil`), and fires `onTap` once per press (ignoring OS autorepeat).
  The remap is cleared on quit.
- `InputSourceSwitcher.swift` — enumerates the enabled, selectable keyboard
  input sources via `TISCreateInputSourceList` and calls `TISSelectInputSource`
  on the next one in the list, mirroring what the system's own "next input
  source" shortcut does.
- `main.swift` — a menu-bar-only (`LSUIElement`) app that wires the two
  together, shows a menu bar icon, and clears the remap in
  `applicationWillTerminate`.
- Auto-update via [Sparkle](https://sparkle-project.org/) — checks
  `docs/appcast.xml` on launch and daily. `make_release.sh` builds, signs,
  notarizes, EdDSA-signs the update, and publishes a GitHub release in one go.

## License

MIT
