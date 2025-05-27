// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlashCard Creator",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "FlashCard Creator",
            targets: ["FlashCard Creator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "FlashCard Creator",
            dependencies: ["ZIPFoundation"],
            path: "FlashCard Creator",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
) 