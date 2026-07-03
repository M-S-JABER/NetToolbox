// swift-tools-version: 5.9

// NetToolbox — Network tools for iOS, built as a Swift Playgrounds App project.
// Opens in Swift Playgrounds on iPad and in Xcode on macOS.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "NetToolbox",
    defaultLocalization: "en",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "NetToolbox",
            targets: ["AppModule"],
            bundleIdentifier: "com.aswaralmudun.nettoolbox",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .earth),
            accentColor: .presetColor(.teal),
            supportedDeviceFamilies: [
                .pad
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: ".",
            exclude: [
                "Tests"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                // Swift 6-style strict concurrency checking while staying
                // compatible with the Swift Playgrounds (5.9/5.10) toolchain.
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
