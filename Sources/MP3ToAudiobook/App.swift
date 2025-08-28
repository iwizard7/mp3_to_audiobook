import SwiftUI

@main
struct MP3ToAudiobookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Меню View
            CommandMenu("Вид") {
                Toggle("Показывать логи", isOn: ContentView.shared.$showLogs)
                    .keyboardShortcut("L", modifiers: .command)
            }

            // Меню Help
            CommandMenu("Справка") {
                Button("О программе") {
                    NSApplication.shared.orderFrontStandardAboutPanel()
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Активация приложения и показ окна
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Показ главного окна
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            window.center()
        }
    }
}