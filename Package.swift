// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "fibricheck-ios-native-camera-sdk",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "fibricheck-ios-native-camera-sdk",
            targets: ["fibricheck-ios-native-camera-sdk"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "fibricheck-ios-native-camera-sdk",
            dependencies: []),
        .testTarget(
            name: "fibricheck-ios-native-camera-sdkTests",
            dependencies: ["fibricheck-ios-native-camera-sdk"]),
    ]
)
