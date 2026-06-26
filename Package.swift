// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OneEvents",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .tvOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "OneEvents",
            targets: ["OneEvents"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/avgx/OneWireFormat.git", from: "1.0.2"),
        .package(url: "https://github.com/avgx/RequestResponse.git", from: "2.0.0"),
        .package(url: "https://github.com/avgx/URLKit.git", from: "1.0.0"),
        .package(url: "https://github.com/avgx/JSONValue.git", from: "1.0.1"),
        .package(url: "https://github.com/avgx/SafeEnum.git", from: "1.0.0"),
        .package(url: "https://github.com/avgx/Get.git", from: "6.0.0"),
        .package(url: "https://github.com/avgx/SSLPinning.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/avgx/DebugThings.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "OneEvents",
            dependencies: [
                .product(name: "JSONValue", package: "JSONValue"),
                .product(name: "OneWireFormat", package: "OneWireFormat"),
                .product(name: "RequestResponse", package: "RequestResponse"),
                .product(name: "URLKit", package: "URLKit"),
                .product(name: "SafeEnum", package: "SafeEnum"),
                .product(name: "HTTP", package: "Get"),
                .product(name: "WS", package: "Get"),
                .product(name: "SSLPinning", package: "SSLPinning"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "DebugThings", package: "DebugThings"),
            ]
        ),
        .testTarget(
            name: "OneEventsTests",
            dependencies: [
                "OneEvents",
                .product(name: "OneWireFormat", package: "OneWireFormat"),
            ]
        ),
    ]
)
