// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Eave",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EaveCore", targets: ["EaveCore"]),
        .library(name: "EaveKit", targets: ["EaveKit"]),
    ],
    targets: [
        .target(name: "EaveCore"),
        .target(name: "EaveKit", dependencies: ["EaveCore"]),
        .testTarget(name: "EaveCoreTests", dependencies: ["EaveCore"]),
        .testTarget(name: "EaveKitTests", dependencies: ["EaveKit", "EaveCore"]),
    ]
)

#if os(macOS)
package.targets += [
    .target(
        name: "EaveApplication", dependencies: ["EaveCore", "EaveKit"],
        path: "Eave", exclude: ["EaveApp.swift", "AppDelegate.swift", "Info.plist"]
    ),
    .testTarget(name: "EaveApplicationTests", dependencies: ["EaveApplication", "EaveCore"]),
]
#endif
