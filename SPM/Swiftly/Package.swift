// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Swiftly",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "Swiftly",
            targets: ["Swiftly"])
    ],
    dependencies: [
        .package(name: "Lottie", url: "https://github.com/airbnb/lottie-ios.git", from: "3.2.1"),
        .package(path: "CoreDataSPM")
    ],
    targets: [
        .target(
            name: "Swiftly",
            dependencies: ["Lottie", "CoreDataSPM"]),
        .testTarget(
            name: "SwiftlyTests",
            dependencies: ["Swiftly"])
    ]
)
