// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Zonely",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Zonely",
            path: "Sources/Zonely",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
