// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FileuploadPlugin",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "FileuploadPlugin",
            targets: ["FileuploadPluginPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", branch: "main")
    ],
    targets: [
        .target(
            name: "FileuploadPluginPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/FileuploadPluginPlugin"),
        .testTarget(
            name: "FileuploadPluginPluginTests",
            dependencies: ["FileuploadPluginPlugin"],
            path: "ios/Tests/FileuploadPluginPluginTests")
    ]
)