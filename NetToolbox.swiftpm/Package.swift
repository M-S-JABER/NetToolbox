// swift-tools-version: 6.0

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
        .iOS("26.0")
    ],
    products: [
        .iOSApplication(
            name: "NetToolbox",
            targets: ["AppModule"],
            bundleIdentifier: "com.aswaralmudun.nettoolbox",
            teamIdentifier: "",
            displayVersion: "2.3.2",
            bundleVersion: "18",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.teal),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            // Info.plist usage descriptions required by the features that touch
            // these system services. Without NSFaceIDUsageDescription in
            // particular, the app-lock's Face ID prompt would crash on device.
            capabilities: [
                .faceID(purposeString: "Locks NetToolbox so your saved hosts, SSH profiles and cameras stay private."),
                .camera(purposeString: "Scans QR codes (Wi-Fi and WireGuard configs) with the camera."),
                .photoLibraryAdd(purposeString: "Saves camera snapshots to your photo library."),
                .localNetwork(
                    purposeString: "Discovers devices and services on your local network (Bonjour, LAN scan, IP cameras).",
                    bonjourServiceTypes: [
                        "_http._tcp", "_https._tcp", "_ssh._tcp", "_smb._tcp",
                        "_airplay._tcp", "_raop._tcp", "_ipp._tcp", "_printer._tcp",
                        "_googlecast._tcp", "_rfb._tcp", "_device-info._tcp", "_homekit._tcp"
                    ]
                )
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/M-S-JABER/NetToolbox", from: "1.73.0")
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
