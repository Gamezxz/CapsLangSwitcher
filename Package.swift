// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CapsLangSwitcher",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "CapsLangSwitcher",
            path: "Sources/CapsLangSwitcher"
        )
    ]
)
