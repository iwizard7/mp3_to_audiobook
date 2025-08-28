import SwiftUI
import UniformTypeIdentifiers
import AppKit

extension UTType {
    static var audio: UTType {
        UTType(filenameExtension: "m4b") ?? .audio
    }
}

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings

    @State private var selectedFiles: [URL] = []
    @State private var author = ""
    @State private var title = ""
    @State private var coverImage: NSImage?
    @State private var isConverting = false
    @State private var progress = 0.0
    @State private var showFileImporter = false
    @State private var showCoverImporter = false
    @State private var showSavePanel = false
    @State private var statusMessage = ""
    @State private var statusColor = Color.primary
    @State private var logs = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("MP3 в M4B Конвертер")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Выбор файлов
                Button("Выбрать MP3 файлы") {
                    showFileImporter = true
                }
                .buttonStyle(.borderedProminent)
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.mp3],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        selectedFiles = urls
                        if let folderURL = urls.first?.deletingLastPathComponent() {
                            parseFolderName(folderURL)
                        }
                    case .failure(let error):
                        print("Ошибка выбора файлов: \(error)")
                    }
                }

                if !selectedFiles.isEmpty {
                    Text("Выбрано файлов: \(selectedFiles.count)")
                        .foregroundColor(.secondary)

                    List(selectedFiles, id: \.self) { url in
                        Text(url.lastPathComponent)
                    }
                    .frame(height: 100)
                }

                // Поля ввода
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Автор", text: $author)
                        .textFieldStyle(.roundedBorder)

                    TextField("Название книги", text: $title)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Выбрать обложку") {
                            showCoverImporter = true
                        }
                        .buttonStyle(.bordered)

                        if let image = coverImage {
                            Image(nsImage: image)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
                .padding(.horizontal)
                .fileImporter(
                    isPresented: $showCoverImporter,
                    allowedContentTypes: [.image],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            coverImage = NSImage(contentsOf: url)
                        }
                    case .failure(let error):
                        print("Ошибка выбора обложки: \(error)")
                    }
                }

                // Кнопка конвертации
                if !selectedFiles.isEmpty {
                    Button("Конвертировать в M4B") {
                        showSaveDialog()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isConverting)
                }

                if isConverting {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    Text("Конвертация... \(Int(progress * 100))%")
                }

                // Сообщение о статусе
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .foregroundColor(statusColor)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 5)
                }

                // Логи (показываются только если включено)
                if settings.showLogs {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("📋 Логи:")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Скопировать") {
                                copyLogsToClipboard()
                            }
                            .buttonStyle(.bordered)
                            Button("Очистить") {
                                clearLogs()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }

                        ScrollView {
                            Text(logs.isEmpty ? "Логи пока пусты" : logs)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(height: 150)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.vertical, 10)
                }

                // Кнопки управления
                HStack(spacing: 20) {
                    // Кнопка переключения логов
                    Button(settings.showLogs ? "Скрыть логи" : "Показать логи") {
                        settings.showLogs.toggle()
                    }
                    .buttonStyle(.bordered)

                    if !selectedFiles.isEmpty && !isConverting {
                        Button("Очистить список") {
                            clearFileList()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }

                    Button("Выход") {
                        exitApplication()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.gray)
                }
            }
            .padding()
            .frame(minWidth: 500)
        }
    }

    private func parseFolderName(_ folderURL: URL) {
        let folderName = folderURL.lastPathComponent
        let components = folderName.components(separatedBy: " - ")
        if components.count >= 2 {
            author = components[0].trimmingCharacters(in: .whitespaces)
            title = components[1].trimmingCharacters(in: .whitespaces)
        } else {
            title = folderName
        }
    }

    private func showSaveDialog() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.audio]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "\(title).m4b"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                convertToM4B(outputURL: url)
            }
        }
    }

    private func convertToM4B(outputURL: URL) {
        guard !author.isEmpty && !title.isEmpty else {
            statusMessage = "Заполните автора и название книги"
            statusColor = .red
            return
        }

        isConverting = true
        progress = 0.0
        statusMessage = ""
        logs = ""

        // Логирование начала конвертации
        if settings.showLogs {
            addLog("=== НАЧАЛО КОНВЕРТАЦИИ ===")
            addLog("Количество выбранных файлов: \(selectedFiles.count)")
            addLog("Выходной файл: \(outputURL.path)")
            addLog("Автор: \(author)")
            addLog("Название: \(title)")
            addLog("Обложка: \(coverImage != nil ? "есть" : "нет")")
            addLog("========================")
        }

        AudioConverter.convertMP3ToM4B(
            inputURLs: selectedFiles,
            outputURL: outputURL,
            author: author,
            title: title,
            coverImage: coverImage
        ) { progressValue in
            DispatchQueue.main.async {
                self.progress = progressValue
                if self.settings.showLogs {
                    self.addLog("Прогресс: \(Int(progressValue * 100))%")
                }
            }
        } completion: { result in
            DispatchQueue.main.async {
                self.isConverting = false
                self.progress = 0.0

                switch result {
                case .success:
                    self.statusMessage = "✅ Конвертация завершена успешно!"
                    self.statusColor = .green
                    if self.settings.showLogs {
                        self.addLog("✅ Конвертация завершена успешно!")
                    }
                case .failure(let error):
                    self.statusMessage = "❌ Ошибка конвертации: \(error.localizedDescription)"
                    self.statusColor = .red
                    if self.settings.showLogs {
                        self.addLog("❌ Ошибка: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs += "[\(timestamp)] \(message)\n"
    }

    private func clearFileList() {
        selectedFiles = []
        author = ""
        title = ""
        coverImage = nil
        statusMessage = ""
        logs = ""
    }

    private func exitApplication() {
        NSApplication.shared.terminate(nil)
    }

    private func copyLogsToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logs, forType: .string)
    }

    private func clearLogs() {
        logs = ""
    }
}

#Preview {
    ContentView()
}