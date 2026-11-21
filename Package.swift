    // swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HanziStroke",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HanziStroke", targets: ["HanziStroke"]),
    ],
    targets: [
        .target(name: "HanziStroke",
                resources: [.process("Resources")]),
        .testTarget(name: "HanziStrokeTests",
                    dependencies: ["HanziStroke"],
                    resources: [.copy("Fixtures")]),
    ]
)
