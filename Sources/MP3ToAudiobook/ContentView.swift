import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var audio: UTType {
        UTType(filenameExtension: "m4b") ?? .audio
    }
}

struct ContentView: View {
    @State private var selectedFiles: [URL] = []
    @State private var originalFiles: [URL] = [] // Оригинальные URL для отображения имен
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
    @State private var showLogs = false
    
    var body: some View {
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
                    originalFiles = urls
                    // Копируем файлы во временную директорию для обеспечения доступа
                    copyFilesToTempDirectory(urls) { copiedURLs in
                        selectedFiles = copiedURLs
                        if let folderURL = urls.first?.deletingLastPathComponent() {
                            parseFolderName(folderURL)
                        }
                    }
                case .failure(let error):
                    print("Ошибка выбора файлов: \(error)")
                }
            }

            if !originalFiles.isEmpty {
                Text("Выбрано файлов: \(originalFiles.count)")
                    .foregroundColor(.secondary)

                List(originalFiles, id: \.self) { url in
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
            if !originalFiles.isEmpty {
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

            // Кнопки управления
            HStack(spacing: 20) {
                // Кнопка очистки списка
                if !originalFiles.isEmpty && !isConverting {
                    Button("Очистить список") {
                        clearFileList()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }

                // Кнопка выхода
                Button("Выход") {
                    exitApplication()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.gray)
            }

            // Область логов
            if showLogs {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Логи выполнения")
                            .font(.headline)
                        Spacer()
                        Button("Скопировать логи") {
                            copyLogsToClipboard()
                        }
                        .buttonStyle(.bordered)
                        Button("Очистить логи") {
                            clearLogs()
                        }
                        .buttonStyle(.bordered)
                        Button("Скрыть логи") {
                            showLogs.toggle()
                        }
                        .buttonStyle(.bordered)
                    }

                    ScrollView {
                        Text(logs.isEmpty ? "Логи пусты" : logs)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                    }
                    .frame(height: 200)
                }
                .padding(.top)
            } else {
                Button("Показать логи") {
                    showLogs.toggle()
                }
                .buttonStyle(.bordered)
                .padding(.top)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func parseFolderName(_ folderURL: URL) {
        let folderName = folderURL.lastPathComponent
        // Простой парсер: предполагаем формат "Автор - Название"
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

        // Логирование для диагностики
        addLog("=== НАЧАЛО КОНВЕРТАЦИИ ===")
        addLog("Количество выбранных файлов: \(selectedFiles.count)")
        addLog("Оригинальные файлы:")
        for (index, url) in originalFiles.enumerated() {
            addLog("  [\(index)]: \(url.path)")
        }
        addLog("Скопированные файлы:")
        for (index, url) in selectedFiles.enumerated() {
            addLog("  [\(index)]: \(url.path)")
            // Проверяем существование файла
            let fileManager = FileManager.default
            let exists = fileManager.fileExists(atPath: url.path)
            addLog("    Существует: \(exists)")
            if exists {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    addLog("    Размер: \(fileSize) bytes")
                } catch {
                    addLog("    Ошибка получения атрибутов: \(error)")
                }
            }
        }
        addLog("Выходной файл: \(outputURL.path)")
        addLog("========================")

        AudioConverter.convertMP3ToM4B(
            inputURLs: selectedFiles,
            outputURL: outputURL,
            author: author,
            title: title,
            coverImage: coverImage,
            progressHandler: { progressValue in
                DispatchQueue.main.async {
                    self.progress = progressValue
                }
            },
            logHandler: { logMessage in
                DispatchQueue.main.async {
                    self.addLog(logMessage)
                }
            }
        ) completion: { result in
            DispatchQueue.main.async {
                self.isConverting = false
                self.progress = 0.0

                addLog("=== РЕЗУЛЬТАТ КОНВЕРТАЦИИ ===")
                switch result {
                case .success:
                    addLog("✅ УСПЕХ")
                    self.statusMessage = "✅ Конвертация завершена успешно!"
                    self.statusColor = .green
                case .failure(let error):
                    addLog("❌ ОШИБКА: \(error.localizedDescription)")
                    addLog("Подробности ошибки: \(error)")
                    self.statusMessage = "❌ Ошибка конвертации: \(error.localizedDescription)"
                    self.statusColor = .red
                }
                addLog("==========================")
            }
        }
    }

    private func clearFileList() {
        selectedFiles = []
        originalFiles = []
        author = ""
        title = ""
        coverImage = nil
        statusMessage = ""

        // Очищаем временную директорию
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("MP3ToAudiobook")
        try? fileManager.removeItem(at: tempDirectory)
    }

    private func exitApplication() {
        NSApplication.shared.terminate(nil)
    }

    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)\n"
        logs += logEntry
        print(message) // Оставляем print для консоли
    }

    private func copyLogsToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logs, forType: .string)
        statusMessage = "Логи скопированы в буфер обмена"
        statusColor = .blue
    }

    private func clearLogs() {
        logs = ""
    }

    private func copyFilesToTempDirectory(_ urls: [URL], completion: @escaping ([URL]) -> Void) {
        addLog("=== КОПИРОВАНИЕ ФАЙЛОВ ВО ВРЕМЕННУЮ ДИРЕКТОРИЮ ===")
        addLog("Количество файлов для копирования: \(urls.count)")

        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("MP3ToAudiobook")

            self.addLog("Временная директория: \(tempDirectory.path)")

            // Создаем временную директорию если её нет
            do {
                try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
                self.addLog("Временная директория создана")
            } catch {
                self.addLog("Ошибка создания временной директории: \(error)")
            }

            // Очищаем старую временную директорию
            do {
                try fileManager.removeItem(at: tempDirectory)
                try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
                self.addLog("Старая временная директория очищена")
            } catch {
                self.addLog("Ошибка очистки временной директории: \(error)")
            }

            var copiedURLs: [URL] = []

            for (index, url) in urls.enumerated() {
                let fileName = url.lastPathComponent
                let destinationURL = tempDirectory.appendingPathComponent(fileName)

                self.addLog("Копирование файла [\(index)]: \(fileName)")
                self.addLog("  Из: \(url.path)")
                self.addLog("  В: \(destinationURL.path)")

                // Проверяем существование исходного файла
                let sourceExists = fileManager.fileExists(atPath: url.path)
                self.addLog("  Исходный файл существует: \(sourceExists)")

                if sourceExists {
                    do {
                        let sourceAttributes = try fileManager.attributesOfItem(atPath: url.path)
                        let sourceSize = sourceAttributes[.size] as? Int64 ?? 0
                        self.addLog("  Размер исходного файла: \(sourceSize) bytes")

                        try fileManager.copyItem(at: url, to: destinationURL)
                        copiedURLs.append(destinationURL)

                        // Проверяем скопированный файл
                        let destExists = fileManager.fileExists(atPath: destinationURL.path)
                        self.addLog("  Скопированный файл существует: \(destExists)")

                        if destExists {
                            let destAttributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
                            let destSize = destAttributes[.size] as? Int64 ?? 0
                            self.addLog("  Размер скопированного файла: \(destSize) bytes")
                        }

                        self.addLog("  ✅ Файл [\(index)] скопирован успешно")
                    } catch {
                        self.addLog("  ❌ Ошибка копирования файла \(fileName): \(error)")
                        // Если не удалось скопировать, используем оригинальный URL
                        copiedURLs.append(url)
                        self.addLog("  Используем оригинальный URL")
                    }
                } else {
                    self.addLog("  ❌ Исходный файл не существует")
                    copiedURLs.append(url)
                }
            }

            self.addLog("Всего скопировано файлов: \(copiedURLs.count)")
            self.addLog("===============================================")

            DispatchQueue.main.async {
                completion(copiedURLs)
            }
        }
    }
}

#Preview {
    ContentView()
}