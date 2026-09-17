// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "archivist-dependencies",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(name: "ArchivistNetworking", targets: ["ArchivistNetworking"]),
        .library(name: "ArchivistComponents", targets: ["ArchivistComponents"]),
        .library(name: "ArchivistFeatures", targets: ["ArchivistFeatures"]),
        .library(name: "ArchivistWatch", targets: ["ArchivistWatch"]),
        .library(name: "VLCPlayerCore", targets: ["VLCPlayerCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.26.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.0"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.0"),
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.4.3"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.12.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
        // The binary-only plugin package rather than realm/SwiftLint itself. The
        // full package pins swift-syntax to an exact prerelease in every release,
        // which cannot co-resolve with the swift-syntax *range* the Point-Free
        // packages require from TCA 1.26 (the first to build on Xcode 27). Same
        // SwiftLintBuildToolPlugin, no source dependencies.
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.62.2")
    ],
    targets: [
        .target(
            name: "ArchivistNetworking",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
                .product(name: "KeychainAccess", package: "KeychainAccess")
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
        .target(
            name: "ArchivistComponents",
            dependencies: [
                "ArchivistNetworking",
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .target(name: "VLCKit", condition: .when(platforms: [.iOS, .tvOS])),
                .target(name: "VLCPlayerCore", condition: .when(platforms: [.iOS, .tvOS]))
            ],
            resources: [
                .process("Resources")
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
        .target(
            name: "ArchivistFeatures",
            dependencies: [
                "ArchivistNetworking",
                "ArchivistComponents",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SQLiteData", package: "sqlite-data")
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
        .target(
            name: "ArchivistWatch",
            dependencies: [
                "ArchivistNetworking",
                .product(name: "SQLiteData", package: "sqlite-data")
            ],
            resources: [
                .process("Resources")
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
        // VLCKit 4.0.0-a24 (tagged 2026-08-31), consumed as the official
        // Swift Package binary artifact VideoLAN began publishing in
        // 4.0.0-a22. To bump: take the url/checksum pair from the
        // Package.swift of the tag you want at github.com/videolan/VLCKit.
        .binaryTarget(
            name: "VLCKit",
            url: "https://download.videolan.org/cocoapods/unstable/VLCKit-4.0-20260831-1526.zip",
            checksum: "c61a42052ec4c1315325fba81f8893f4ccf639d92bf61dd1b3c37c3a2f26b8e3"
        ),
        // Lifted verbatim from videolan/vlc-ios. UIKit-only; we slim
        // PlaybackService to URL-driven playback (keeps the queue layer)
        // and stub the media-library / theming / coordinator pieces so
        // the player VC can mount standalone against a TA media URL.
        // No SwiftLint — third-party source we don't own style for.
        .target(
            name: "VLCPlayerCore",
            dependencies: [
                .target(name: "VLCKit", condition: .when(platforms: [.iOS, .tvOS]))
            ]
        ),
        .testTarget(
            name: "ArchivistFeaturesTests",
            dependencies: [
                "ArchivistFeatures",
                // For `PlayerEvent`, which the VideoDetail playback tests
                // feed through the reducer's event consumer directly.
                .target(name: "ArchivistComponents", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "DependenciesTestSupport", package: "swift-dependencies")
            ]
        )
    ]
)
