import SwiftUI
import AppKit

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var appIcon: Image {
        if let path = Bundle.main.path(forResource: "logo", ofType: "png"),
           let img = NSImage(contentsOfFile: path) {
            return Image(nsImage: img)
        }
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let img = NSImage(contentsOfFile: path) {
            return Image(nsImage: img)
        }
        return Image(systemName: "capslock.fill")
    }

    var body: some View {
        VStack(spacing: 14) {
            appIcon
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .shadow(color: Color(red: 0.8, green: 0.44, blue: 0.3).opacity(0.35), radius: 14, y: 6)

            Text("CapsLangSwitcher")
                .font(.title2).bold()
            Text("Version \(version)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Tap Caps Lock, switch languages — instantly.\nNo macOS hotkey delay, ever.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider().padding(.horizontal, 30)

            VStack(spacing: 4) {
                Text("Created by")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Gamezxz 🧙‍♂️")
                    .font(.headline)
            }

            HStack(spacing: 14) {
                Link("GitHub", destination: URL(string: "https://github.com/Gamezxz/CapsLangSwitcher")!)
                Link("Website", destination: URL(string: "https://gamezxz.github.io/CapsLangSwitcher/")!)
            }
            .font(.callout)

            Text("© 2026 Gamezxz — free & open source")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(28)
        .frame(width: 340)
    }
}
