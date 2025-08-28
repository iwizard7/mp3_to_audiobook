import Foundation
import Combine
import AppKit

/// Модель для информации о релизе с GitHub
struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String?
    let publishedAt: String
    let htmlUrl: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case publishedAt = "published_at"
        case htmlUrl = "html_url"
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

/// Результат проверки обновлений
enum UpdateCheckResult {
    case upToDate
    case updateAvailable(GitHubRelease)
    case error(String)
}

/// Сервис для проверки обновлений через GitHub API
class UpdateService {
    static let shared = UpdateService()

    private let githubAPI = "https://api.github.com/repos/iwizard7/mp3_to_audiobook/releases/latest"
    private let lastCheckKey = "LastUpdateCheck"
    private let skipVersionKey = "SkipVersion"

    private init() {}

    /// Проверяет наличие обновлений
    func checkForUpdates() async -> UpdateCheckResult {
        do {
            guard let url = URL(string: githubAPI) else {
                return .error("Неверный URL GitHub API")
            }

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return .error("Ошибка сети при проверке обновлений")
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

            // Сравниваем версии
            if isNewerVersion(release.tagName) {
                // Проверяем, не пропустил ли пользователь эту версию
                if let skipVersion = UserDefaults.standard.string(forKey: skipVersionKey),
                   skipVersion == release.tagName {
                    return .upToDate
                }
                return .updateAvailable(release)
            } else {
                return .upToDate
            }

        } catch {
            return .error("Ошибка при проверке обновлений: \(error.localizedDescription)")
        }
    }

    /// Проверяет, является ли версия новее текущей
    private func isNewerVersion(_ versionTag: String) -> Bool {
        let currentVersion = AppVersion.current.versionString

        // Убираем префикс "v" если есть
        let cleanVersionTag = versionTag.hasPrefix("v") ? String(versionTag.dropFirst()) : versionTag
        let cleanCurrentVersion = currentVersion.hasPrefix("v") ? String(currentVersion.dropFirst()) : currentVersion

        return compareVersions(cleanVersionTag, cleanCurrentVersion) > 0
    }

    /// Сравнивает две версии
    private func compareVersions(_ version1: String, _ version2: String) -> Int {
        let components1 = version1.components(separatedBy: ".")
        let components2 = version2.components(separatedBy: ".")

        let maxLength = max(components1.count, components2.count)

        for i in 0..<maxLength {
            let part1 = i < components1.count ? components1[i] : "0"
            let part2 = i < components2.count ? components2[i] : "0"

            if let num1 = Int(part1), let num2 = Int(part2) {
                if num1 > num2 {
                    return 1
                } else if num1 < num2 {
                    return -1
                }
            } else {
                // Если не числа, сравниваем как строки
                let comparison = part1.compare(part2, options: .numeric)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending ? -1 : 1
                }
            }
        }

        return 0
    }

    /// Сохраняет время последней проверки
    func saveLastCheckTime() {
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
    }

    /// Получает время последней проверки
    func getLastCheckTime() -> Date? {
        return UserDefaults.standard.object(forKey: lastCheckKey) as? Date
    }

    /// Пропускает указанную версию
    func skipVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: skipVersionKey)
    }

    /// Проверяет, нужно ли выполнять автоматическую проверку
    func shouldCheckForUpdates() -> Bool {
        guard let lastCheck = getLastCheckTime() else {
            return true // Первая проверка
        }

        let daysSinceLastCheck = Calendar.current.dateComponents([.day], from: lastCheck, to: Date()).day ?? 0
        return daysSinceLastCheck >= 7 // Проверяем раз в неделю
    }

    /// Открывает страницу релиза в браузере
    func openReleasePage(_ release: GitHubRelease) {
        if let url = URL(string: release.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Скачивает и устанавливает обновление
    func downloadAndInstallUpdate(_ release: GitHubRelease) async throws {
        // Находим подходящий asset для macOS
        guard let asset = release.assets.first(where: { $0.name.contains("macOS") || $0.name.contains(".dmg") }) else {
            throw UpdateError.noSuitableAsset
        }

        guard let downloadURL = URL(string: asset.browserDownloadUrl) else {
            throw UpdateError.invalidDownloadURL
        }

        // Создаем временную директорию для скачивания
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(asset.name)

        // Скачиваем файл
        let (data, _) = try await URLSession.shared.data(from: downloadURL)
        try data.write(to: tempFileURL)

        // Открываем файл (для .dmg это откроет установщик)
        NSWorkspace.shared.open(tempFileURL)
    }
}

/// Ошибки обновления
enum UpdateError: LocalizedError {
    case noSuitableAsset
    case invalidDownloadURL
    case downloadFailed
    case installationFailed

    var errorDescription: String? {
        switch self {
        case .noSuitableAsset:
            return "Не найден подходящий файл для скачивания"
        case .invalidDownloadURL:
            return "Неверная ссылка для скачивания"
        case .downloadFailed:
            return "Ошибка при скачивании обновления"
        case .installationFailed:
            return "Ошибка при установке обновления"
        }
    }
}