// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CapsLangSwitcher",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "CapsLangSwitcher",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/CapsLangSwitcher"
        )
    ]
)
