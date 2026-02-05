// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "xStatsMenu",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "xStatsMenu",
            targets: ["xStatsMenu"]
        )
    ],
    targets: [
        .executableTarget(
            name: "xStatsMenu",
            path: "Sources/xStatsMenu",
            exclude: ["Resources/Info.plist", "Resources/AppIcon.iconset", "Resources/DMGVolumeIcon.iconset", "Resources/DMGVolumeIcon.icns"],
            resources: [
                .process("Resources/Assets.xcassets"),
                .copy("Resources/AppIcon.icns")
            ]
        )
    ]
)
