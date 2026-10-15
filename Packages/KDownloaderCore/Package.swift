// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KDownloaderCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KDownloaderCore", targets: ["KDownloaderCore"]),
    ],
    targets: [
        .target(name: "KDownloaderCore"),
        .testTarget(
            name: "KDownloaderCoreTests",
            dependencies: ["KDownloaderCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
