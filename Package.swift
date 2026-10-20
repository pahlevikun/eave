// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Eave",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EaveCore", targets: ["EaveCore"]),
    ],
    targets: [
        .target(name: "EaveCore"),
        .testTarget(name: "EaveCoreTests", dependencies: ["EaveCore"]),
    ]
)
