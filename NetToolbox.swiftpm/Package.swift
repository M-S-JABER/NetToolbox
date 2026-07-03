// swift-tools-version: 5.9

// NetToolbox — thin app playground for Swift Playgrounds on iPad.
//
// All real code lives in the NetToolboxKit library at the root of this
// repository; this app only provides the @main entry point. It pulls the
// kit from GitHub, so you can also skip this project entirely and add
// the repo URL as a package to your own App playground instead.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "NetToolboxApp",
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
    dependencies: [
        .package(url: "https://github.com/M-S-JABER/NetToolbox", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "NetToolboxKit", package: "NetToolbox")
            ],
            path: "."
        )
    ]
)
