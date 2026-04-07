// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "wallpaper-spanner",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "WallpaperSpanner",
            targets: ["WallpaperSpanner"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "WallpaperSpanner",
            path: "Sources/WallpaperSpanner"
        ),
        .testTarget(
            name: "WallpaperSpannerTests",
            dependencies: ["WallpaperSpanner"],
            path: "Tests/WallpaperSpannerTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
