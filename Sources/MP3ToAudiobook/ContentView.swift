import SwiftUI
import UniformTypeIdentifiers
import AppKit

extension UTType {
    static var audioFiles: [UTType] {
        let extensions = ["mp3", "aac", "m4a", "wav", "aiff"]
        return extensions.compactMap { UTType(filenameExtension: $0) } + [.audio]
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
    @State private var showCoverPreview = false
    @State private var statusMessage = ""
    @State private var statusColor = Color.primary
    @State private var logs = ""
    @State private var isDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Аудио в M4B Конвертер")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Выбор файлов с drag & drop
                VStack {
                    Button("Выбрать аудиофайлы") {
                        showFileImporter = true
                    }
                    .buttonStyle(.borderedProminent)
                    .fileImporter(
                        isPresented: $showFileImporter,
                        allowedContentTypes: UTType.audioFiles,
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

                    // Drag & Drop зона
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundColor(.gray.opacity(0.5))
                            .frame(height: 80)
                            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                                handleDrop(providers: providers)
                            }

                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                            Text("Перетащите аудиофайлы или папки сюда")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .opacity(isDropTargeted ? 0.5 : 1.0)
                    }
                    .background(isDropTargeted ? Color.blue.opacity(0.1) : Color.clear)
                    .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
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
                            Button(action: { showCoverPreview = true }) {
                                Image(nsImage: image)
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .foregroundColor(.gray.opacity(0.5))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            }
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

                        ScrollViewReader { scrollViewProxy in
                            ScrollView {
                                Text(logs.isEmpty ? "Логи пока пусты" : logs)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .id("logs_end")
                            }
                            .onChange(of: logs) { _ in
                                withAnimation {
                                    scrollViewProxy.scrollTo("logs_end", anchor: .bottom)
                                }
                            }
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

                // Информация о приложении
                VStack(spacing: 4) {
                    Divider()

                    HStack(spacing: 20) {
                        Text("Версия v2025.08.28.1.060543")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("© 2025 MP3ToAudiobook. Все права защищены.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("https://github.com/dmitrijsibanov/MP3ToAudiobook") {
                            if let url = URL(string: "https://github.com/dmitrijsibanov/MP3ToAudiobook") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                    .padding(.top, 8)

                    Text("Разработано с ❤️ для создания аудиокниг")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.top, 2)
                }
            }
            .padding()
            .frame(minWidth: 500)
        }
        .sheet(isPresented: $showCoverPreview) {
            if let image = coverImage {
                VStack {
                    Text("Превью обложки")
                        .font(.headline)
                        .padding()

                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 300, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button("Закрыть") {
                        showCoverPreview = false
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
                .padding()
            }
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
        savePanel.allowedContentTypes = UTType.audioFiles
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

        AudioConverter.convertAudioToM4B(
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

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                    if let data = item as? Data,
                       let urlString = String(data: data, encoding: .utf8),
                       let url = URL(string: urlString) {
                        DispatchQueue.main.async {
                            urls.append(url)
                            if urls.count == providers.count {
                                processDroppedURLs(urls)
                            }
                        }
                    }
                }
            }
        }
        return true
    }

    private func processDroppedURLs(_ urls: [URL]) {
        var audioFiles: [URL] = []

        for url in urls {
            if url.hasDirectoryPath {
                // Это папка - ищем аудиофайлы
                if let folderFiles = findAudioFiles(in: url) {
                    audioFiles.append(contentsOf: folderFiles)
                }
            } else if isAudioFile(url) {
                // Это аудиофайл
                audioFiles.append(url)
            }
        }

        if !audioFiles.isEmpty {
            selectedFiles = audioFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
            if let folderURL = audioFiles.first?.deletingLastPathComponent() {
                parseFolderName(folderURL)
            }
        }
    }

    private func findAudioFiles(in directory: URL) -> [URL]? {
        let fileManager = FileManager.default
        let audioExtensions = ["mp3", "aac", "m4a", "wav", "aiff"]
        var audioFiles: [URL] = []

        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])

        while let fileURL = enumerator?.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if audioExtensions.contains(ext) {
                audioFiles.append(fileURL)
            }
        }

        return audioFiles.isEmpty ? nil : audioFiles
    }

    private func isAudioFile(_ url: URL) -> Bool {
        let audioExtensions = ["mp3", "aac", "m4a", "wav", "aiff"]
        return audioExtensions.contains(url.pathExtension.lowercased())
    }
}

#Preview {
    ContentView()
}