import Foundation

struct AppVersion {
    static let current = Version(
        major: 2025,
        minor: 8,
        patch: 28,
        build: 1,
        timestamp: "060543"
    )

    struct Version {
        let major: Int
        let minor: Int
        let patch: Int
        let build: Int
        let timestamp: String

        var versionString: String {
            "v\(major).\(String(format: "%02d", minor)).\(String(format: "%02d", patch)).\(build).\(timestamp)"
        }

        var displayString: String {
            "Версия \(versionString)"
        }
    }

    static let copyright = "© 2025 MP3ToAudiobook. Все права защищены."
    static let githubURL = "https://github.com/dmitrijsibanov/MP3ToAudiobook"
    static let author = "Разработано с ❤️ для создания аудиокниг"
}