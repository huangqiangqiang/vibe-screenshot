// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenshotTool",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ScreenshotCore",
            targets: ["ScreenshotCore"]
        ),
        .executable(
            name: "ScreenshotTool",
            targets: ["ScreenshotTool"]
        ),
        .executable(
            name: "ScreenshotCompanionExtension",
            targets: ["ScreenshotCompanionExtension"]
        )
    ],
    targets: [
        .target(
            name: "ScreenshotCore"
        ),
        .executableTarget(
            name: "ScreenshotTool",
            dependencies: ["ScreenshotCore"]
        ),
        .executableTarget(
            name: "ScreenshotCompanionExtension"
        ),
        .testTarget(
            name: "ScreenshotCoreTests",
            dependencies: ["ScreenshotCore"]
        )
    ]
)
