// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CoreDataSPM",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "CoreDataSPM",
            targets: ["CoreDataSPM"])
    ],
    targets: [
        .target(
            name: "CoreDataSPM",
            dependencies: [],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CoreDataSPMTests",
            dependencies: ["CoreDataSPM"])
    ]
)
