// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cheq",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "Cheq",
            targets: ["Cheq"]),
    ],
    dependencies: [
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "Cheq",
            dependencies: [
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
            ]),
    ]
)

