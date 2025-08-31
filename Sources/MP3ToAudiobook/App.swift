import SwiftUI

class AppSettings: ObservableObject {
    @AppStorage("showLogs") var showLogs = false {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage("autoCheckUpdates") var autoCheckUpdates = true {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage("tempDirectoryPath") var tempDirectoryPath = "" {
        didSet {
            objectWillChange.send()
        }
    }

    /// Возвращает путь к временной директории (использует системную по умолчанию, если не задано)
    var effectiveTempDirectory: URL {
        if tempDirectoryPath.isEmpty {
            return FileManager.default.temporaryDirectory
        } else {
            return URL(fileURLWithPath: tempDirectoryPath)
        }
    }

    /// Сбрасывает путь к временной директории на системный по умолчанию
    func resetTempDirectoryToDefault() {
        tempDirectoryPath = ""
    }
}


@main
struct MP3ToAudiobookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Меню View
            CommandMenu("Вид") {
                Toggle("Показывать логи", isOn: $settings.showLogs)
                    .keyboardShortcut("L", modifiers: .command)

                Toggle("Автоматическая проверка обновлений", isOn: $settings.autoCheckUpdates)
            }

            // Меню Help
            CommandMenu("Справка") {
                Button("О программе") {
                    AppDelegate.shared?.showCustomAboutPanel()
                }
                .keyboardShortcut("?", modifiers: .command)

                Button("Проверить обновления") {
                    Task {
                        await AppDelegate.shared?.checkForUpdatesManually()
                    }
                }
                .keyboardShortcut("U", modifiers: [.command, .shift])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Активация приложения и показ окна
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Показ главного окна
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            window.center()
        }

        // Автоматическая проверка обновлений
        checkForUpdatesIfNeeded()
    }

    private func checkForUpdatesIfNeeded() {
        // Проверяем, включена ли автоматическая проверка
        let settings = AppSettings()
        guard settings.autoCheckUpdates else {
            return
        }

        Task {
            let updateService = UpdateService.shared

            // Проверяем, нужно ли выполнять проверку
            guard updateService.shouldCheckForUpdates() else {
                return
            }

            // Проверяем обновления
            let result = await updateService.checkForUpdates()

            switch result {
            case .updateAvailable(let release):
                await showUpdateNotification(release)
            case .error(let error):
                print("Ошибка проверки обновлений: \(error)")
            case .upToDate:
                print("Приложение обновлено до последней версии")
            }

            // Сохраняем время проверки
            updateService.saveLastCheckTime()
        }
    }

    @MainActor
    private func showUpdateNotification(_ release: GitHubRelease) async {
        let alert = NSAlert()
        alert.messageText = "Доступно обновление"
        alert.informativeText = "Версия \(release.tagName) доступна для скачивания.\n\n\(release.body ?? "")"
        alert.alertStyle = .informational

        alert.addButton(withTitle: "Скачать")
        alert.addButton(withTitle: "Позже")
        alert.addButton(withTitle: "Пропустить эту версию")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn: // Скачать
            UpdateService.shared.openReleasePage(release)
        case .alertSecondButtonReturn: // Позже
            // Ничего не делаем, просто закрываем
            break
        case .alertThirdButtonReturn: // Пропустить
            UpdateService.shared.skipVersion(release.tagName)
        default:
            break
        }
    }

    @MainActor
    func checkForUpdatesManually() async {
        let alert = NSAlert()
        alert.messageText = "Проверка обновлений"
        alert.informativeText = "Проверяем наличие новых версий..."
        alert.alertStyle = .informational

        // Показываем индикатор загрузки
        let progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        progressIndicator.style = .spinning
        progressIndicator.startAnimation(nil)
        alert.accessoryView = progressIndicator

        // Запускаем проверку в фоне
        Task {
            let result = await UpdateService.shared.checkForUpdates()
            UpdateService.shared.saveLastCheckTime()

            await MainActor.run {
                progressIndicator.stopAnimation(nil)

                switch result {
                case .updateAvailable(let release):
                    showUpdateAlert(for: release)
                case .upToDate:
                    showUpToDateAlert()
                case .error(let error):
                    showErrorAlert(error)
                }
            }
        }

        alert.runModal()
    }

    @MainActor
    private func showUpdateAlert(for release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = "Доступно обновление"
        alert.informativeText = "Версия \(release.tagName) доступна для скачивания.\n\n\(release.body ?? "")"
        alert.alertStyle = .informational

        alert.addButton(withTitle: "Скачать и установить")
        alert.addButton(withTitle: "Открыть в браузере")
        alert.addButton(withTitle: "Позже")
        alert.addButton(withTitle: "Пропустить эту версию")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn: // Скачать и установить
            Task {
                await downloadAndInstallUpdate(release)
            }
        case .alertSecondButtonReturn: // Открыть в браузере
            UpdateService.shared.openReleasePage(release)
        case .alertThirdButtonReturn: // Позже
            break
        default: // Пропустить эту версию (четвертая кнопка)
            UpdateService.shared.skipVersion(release.tagName)
        }
    }

    @MainActor
    private func downloadAndInstallUpdate(_ release: GitHubRelease) async {
        let alert = NSAlert()
        alert.messageText = "Скачивание обновления"
        alert.informativeText = "Скачиваем версию \(release.tagName)..."
        alert.alertStyle = .informational

        let progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 200, height: 20))
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = true
        progressIndicator.startAnimation(nil)
        alert.accessoryView = progressIndicator

        // Запускаем скачивание
        Task {
            do {
                try await UpdateService.shared.downloadAndInstallUpdate(release)

                await MainActor.run {
                    progressIndicator.stopAnimation(nil)
                    showDownloadCompleteAlert()
                }
            } catch {
                await MainActor.run {
                    progressIndicator.stopAnimation(nil)
                    showDownloadErrorAlert(error.localizedDescription)
                }
            }
        }

        alert.runModal()
    }

    @MainActor
    private func showDownloadCompleteAlert() {
        let alert = NSAlert()
        alert.messageText = "Скачивание завершено"
        alert.informativeText = "Обновление было скачано и готово к установке. Перезапустите приложение для применения изменений."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Перезапустить")
        alert.addButton(withTitle: "Позже")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }

    @MainActor
    private func showDownloadErrorAlert(_ error: String) {
        let alert = NSAlert()
        alert.messageText = "Ошибка скачивания"
        alert.informativeText = "Не удалось скачать обновление: \(error)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Открыть в браузере")
        alert.addButton(withTitle: "Отмена")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Открываем страницу релиза в браузере
            if let url = URL(string: "https://github.com/iwizard7/mp3_to_audiobook/releases/latest") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @MainActor
    func showCustomAboutPanel() {
        let alert = NSAlert()
        alert.messageText = "MP3ToAudiobook"
        alert.informativeText = """
        Аудио в M4B Конвертер

        \(AppVersion.current.displayString)

        © 2025 MP3ToAudiobook. Все права защищены.

        Разработано с ❤️ для создания аудиокниг

        Репозиторий: https://github.com/iwizard7/mp3_to_audiobook
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @MainActor
    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "Обновления не найдены"
        alert.informativeText = "У вас установлена последняя версия приложения."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @MainActor
    private func showErrorAlert(_ error: String) {
        let alert = NSAlert()
        alert.messageText = "Ошибка проверки обновлений"
        alert.informativeText = error
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}