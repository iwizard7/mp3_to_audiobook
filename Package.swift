// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MP3toAudiobook",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "mp3toaudiobook",
            targets: ["MP3toAudiobook"]
        ),
    ],
    dependencies: [
        // Добавить зависимости при необходимости
    ],
    targets: [
        .executableTarget(
            name: "MP3toAudiobook",
            dependencies: [],
            path: "mp3toaudiobook"
        ),
        .testTarget(
            name: "MP3toAudiobookTests",
            dependencies: ["MP3toAudiobook"],
            path: "Tests"
        ),
    ]
)
