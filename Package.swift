// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "archivist-dependencies",
    platforms: [
        .iOS(.v18),
        .tvOS(.v18),
    ],
    products: [
        .library(name: "ArchivistNetworking", targets: ["ArchivistNetworking"]),
        .library(name: "ArchivistComponents", targets: ["ArchivistComponents"]),
        .library(name: "ArchivistFeatures", targets: ["ArchivistFeatures"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.20.2"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.0"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.0"),
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.4.3"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    ],
    targets: [
        .target(
            name: "ArchivistNetworking",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ]
        ),
        .target(
            name: "ArchivistComponents",
            dependencies: [
                "ArchivistNetworking",
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "ArchivistFeatures",
            dependencies: [
                "ArchivistNetworking",
                "ArchivistComponents",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SQLiteData", package: "sqlite-data"),
            ]
        ),
    ]
)
