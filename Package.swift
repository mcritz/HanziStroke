// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HanziStroke",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HanziStroke", targets: ["HanziStroke"]),
    ],
    targets: [
        .target(name: "HanziStroke"),
        .testTarget(name: "HanziStrokeTests", dependencies: ["HanziStroke"]),
    ]
)
