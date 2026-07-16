// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenWriter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OpenWriter", targets: ["OpenWriter"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "OpenWriter",
            dependencies: [],
            path: "Sources/OpenWriter"
        )
    ]
)
