// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenPaper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OpenPaper", targets: ["OpenPaper"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "OpenPaper",
            dependencies: [],
            path: "Sources/OpenPaper"
        )
    ]
)
