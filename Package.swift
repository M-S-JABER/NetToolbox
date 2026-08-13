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
        // iOS 17 هو الحد الأدنى التقني الحقيقي: `@Observable` (Observation)
        // و SwiftData و `Section(isExpanded:)` كلها من iOS 17، ولا تستخدم
        // المكتبة أي واجهة أحدث من ذلك. الحد كان 26.0 سابقاً بلا ضرورة
        // تقنية، وكان يستثني كل جهاز أقدم من iPhone 11 تقريباً.
        //
        // ملاحظة: وضع لغة Swift 6 أدناه مستقل تماماً عن حد النشر — يحدّده
        // إصدار المترجم لا إصدار النظام المستهدف.
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
            ],
            // Full Swift 6 language mode with strict concurrency checking.
            // This is a *compiler* setting and is independent of the iOS
            // deployment target above — Swift 6 concurrency back-deploys.
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
