// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MangaReader",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MangaReader",
            targets: ["MangaReader"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MangaReader",
            path: "MangaReader",
            exclude: [
                "Resources/Info.plist",
                "Resources/MangaReader.entitlements"
            ]
        ),
        .testTarget(
            name: "MangaReaderTests",
            dependencies: ["MangaReader"],
            path: "Tests/MangaReaderTests"
        )
    ]
)
