// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "xStats",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "xStats",
            targets: ["xStats"]
        )
    ],
    targets: [
        .executableTarget(
            name: "xStats",
            path: "Sources/xStatsMenu",
            exclude: ["Resources/Info.plist", "Resources/AppIcon.iconset", "Resources/DMGVolumeIcon.iconset", "Resources/DMGVolumeIcon.icns"],
            resources: [
                .process("Resources/Assets.xcassets"),
                .copy("Resources/AppIcon.icns")
            ]
        )
    ]
)
