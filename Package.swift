// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "AccountKit",
    platforms: [
        .iOS(.v27)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AccountKit",
            targets: ["AccountKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.7.3"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AccountKit",
            dependencies: [
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "AccountKitTests",
            dependencies: [
                "AccountKit",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ],
            swiftSettings: swiftSettings,
        ),
    ]
)
