// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BulkAIEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BulkAIEngine", targets: ["BulkAIEngine"])
    ],
    targets: [
        .target(name: "BulkAIEngine"),
        .testTarget(name: "BulkAIEngineTests", dependencies: ["BulkAIEngine"])
    ]
)
