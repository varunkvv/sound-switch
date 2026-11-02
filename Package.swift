// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SoundSwitch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "SoundSwitch", path: "Sources/SoundSwitch")
    ]
)
