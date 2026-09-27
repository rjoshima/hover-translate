// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "SelectTranslate",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "SelectTranslate", targets: ["SelectTranslate"])],
    targets: [
        .target(name: "TranslationCore"),
        .executableTarget(name: "SelectTranslate", dependencies: ["TranslationCore"]),
        .testTarget(name: "TranslationCoreTests", dependencies: ["TranslationCore"])
    ]
)
