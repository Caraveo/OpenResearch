// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenDeveloper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OpenDeveloper", targets: ["OpenDeveloper"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "OpenDeveloper",
            dependencies: [],
            path: "Sources/OpenDeveloper"
        )
    ]
)
