// swift-tools-version: 6.0

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
// IMPORTANT: this manifest declares NO external dependencies on purpose.
// Swift Playgrounds on iPad cannot evaluate a package manifest that pulls
// remote SPM dependencies ("Could not decode ContextModel parameter" at
// load time), which takes down the whole package. Everything here is
// therefore native (Network.framework / POSIX / CryptoKit / CoreImage).

import PackageDescription

let package = Package(
    name: "NetToolboxKit",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .library(
            name: "NetToolboxKit",
            targets: ["NetToolboxKit"]
        )
    ],
    targets: [
        .target(
            name: "NetToolboxKit",
            resources: [
                .process("Resources")
            ],
            // Phase 2 of the Swift 6.3 / iOS 26.5 migration: full Swift 6
            // language mode with strict concurrency checking.
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "NetToolboxKitTests",
            dependencies: ["NetToolboxKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
