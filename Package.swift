// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "AccountKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v27)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AccountKit",
            targets: ["AccountKit"]
        ),
        .library(
            name: "AccountKitTestSupport",
            targets: ["AccountKitTestSupport"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.26.2"),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.4.3"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.7.3"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.1"),
        .package(url: "https://github.com/pointfreeco/swift-issue-reporting", from: "2.1.2"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", "12.15.0" ..< "13.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AccountKit",
            dependencies: [
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "IssueReporting", package: "swift-issue-reporting"),
            ],
            resources: [
                .process("Localizable.xcstrings")
            ],
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "AccountKitTestSupport",
            dependencies: [
                "AccountKit",
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "AccountKitTests",
            dependencies: [
                "AccountKit",
                "AccountKitTestSupport",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ],
            swiftSettings: swiftSettings,
        ),
    ]
)
