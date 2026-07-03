// swift-tools-version: 5.9

// NetToolbox — network tools for iPad as an importable Swift package.
//
// Add this repository directly in Swift Playgrounds (Add Package → this
// repo URL → pick a version tag), then:
//
//     import NetToolboxKit
//     ...
//     WindowGroup { NetToolboxRootView() }
//
// The bundled `NetToolbox.swiftpm` app playground does exactly that.
//
// NOTE ON THE SSH DEPENDENCY:
// The SSH client uses Citadel (SwiftNIO SSH). This is the *only* external
// dependency in the whole project — everything else is native. It pulls a
// large transitive tree (swift-nio, swift-crypto, ...). If a build
// environment (e.g. Swift Playgrounds on iPad) can't resolve or build it,
// pin the package to 1.2.0, which ships all 20 native tools with **zero**
// dependencies and is otherwise identical minus SSH.

import PackageDescription

let package = Package(
    name: "NetToolbox",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "NetToolboxKit",
            targets: ["NetToolboxKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.7.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "NetToolboxKit",
            dependencies: [
                .product(name: "Citadel", package: "Citadel"),
                .product(name: "NIOCore", package: "swift-nio")
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                // Swift 6-style strict concurrency checking while staying
                // compatible with the Swift Playgrounds (5.9/5.10) toolchain.
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "NetToolboxKitTests",
            dependencies: ["NetToolboxKit"]
        )
    ]
)
