// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "HoverTranslate",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "HoverTranslate", targets: ["HoverTranslate"])],
    targets: [
        .target(name: "HoverCore"),
        .executableTarget(name: "HoverTranslate", dependencies: ["HoverCore"]),
        .testTarget(name: "HoverCoreTests", dependencies: ["HoverCore"])
    ]
)
