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
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AccountKit",
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "AccountKitTests",
            dependencies: ["AccountKit"],
            swiftSettings: swiftSettings,
        ),
    ]
)
