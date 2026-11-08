// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlipH",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "FlipH", targets: ["FlipH"])],
    targets: [
        .target(name: "FlipCore"),
        .executableTarget(name: "FlipH", dependencies: ["FlipCore"]),
        .testTarget(name: "FlipCoreTests", dependencies: ["FlipCore"])
    ],
    swiftLanguageModes: [.v5]
)
