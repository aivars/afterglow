// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Afterglow",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Afterglow", targets: ["Afterglow"]),
    ],
    targets: [
        .target(
            name: "Afterglow",
            path: "Sources/Afterglow",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AfterglowTests",
            dependencies: ["Afterglow"],
            path: "Tests/AfterglowTests"
        ),
    ]
)
