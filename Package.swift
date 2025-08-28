// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MP3ToAudiobook",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MP3ToAudiobook", targets: ["MP3ToAudiobook"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MP3ToAudiobook",
            dependencies: []
        )
    ]
)