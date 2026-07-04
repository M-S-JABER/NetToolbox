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
// IMPORTANT: this manifest declares NO external dependencies on purpose.
// Swift Playgrounds on iPad cannot evaluate a package manifest that pulls
// remote SPM dependencies ("Could not decode ContextModel parameter" at
// load time), which takes down the whole package. Everything here is
// therefore native (Network.framework / POSIX / CryptoKit / CoreImage).

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
    targets: [
        .target(
            name: "NetToolboxKit",
            resources: [
                .process("Resources")
            ]
            // Note: the opt-in `StrictConcurrency` experimental feature was
            // removed. It surfaced Swift 6 *preview* warnings that cannot be
            // resolved on the Swift 5 Playgrounds toolchain — SwiftData's
            // `#Predicate` macro emits non-Sendable `ReferenceWritableKeyPath`
            // references, and `NWConnection` callbacks send Sendable Results
            // through a continuation. Both are safe here; the flag only added
            // noise, so the package now builds warning-free under Swift 5.
        ),
        .testTarget(
            name: "NetToolboxKitTests",
            dependencies: ["NetToolboxKit"]
        )
    ]
)
