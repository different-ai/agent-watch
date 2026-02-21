// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "agent-watch",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "ScreenTextKit", targets: ["ScreenTextKit"]),
        .executable(name: "agent-watch", targets: ["agentwatch"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.7.0"),
    ],
    targets: [
        .target(
            name: "ScreenTextKit",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ImageIO"),
                .linkedFramework("Network"),
                .linkedFramework("Vision"),
            ]
        ),
        .executableTarget(
            name: "agentwatch",
            dependencies: ["ScreenTextKit"]
        ),
        .testTarget(
            name: "ScreenTextKitTests",
            dependencies: [
                "ScreenTextKit",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
