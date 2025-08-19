
import SwiftUI

@main
struct mp3toaudiobookApp: App {
    var body: some Scene {
        WindowGroup {
            EnhancedContentView()
                .frame(minWidth: 600, minHeight: 700)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .help) {
                Button("О программе") {
                    showAboutWindow()
                }
            }
        }
    }
    
    private func showAboutWindow() {
        let alert = NSAlert()
        alert.messageText = "MP3 to Audiobook Converter"
        alert.informativeText = """
        Версия 2.0
        
        Конвертирует MP3 файлы в аудиокниги с поддержкой:
        • Метаданных (автор, рассказчик, описание)
        • Обложек
        • Глав
        • Различных форматов вывода
        
        Создано с использованием SwiftUI и AVFoundation
        """
        alert.alertStyle = .informational
        alert.runModal()
    }
}
