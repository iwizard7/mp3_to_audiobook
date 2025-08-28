import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var audio: UTType {
        UTType(filenameExtension: "m4b") ?? .audio
    }
}

struct ContentView: View {
    @State private var selectedFiles: [URL] = []
    @State private var author = ""
    @State private var title = ""
    @State private var coverImage: NSImage?
    @State private var isConverting = false
    @State private var progress = 0.0
    @State private var showFileImporter = false
    @State private var showCoverImporter = false
    @State private var showSavePanel = false
    @State private var errorMessage = ""
    @State private var showError = false
    
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
        }
        .alert("Ошибка", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
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
            errorMessage = "Заполните автора и название книги"
            showError = true
            return
        }
        
        isConverting = true
        progress = 0.0
        
        AudioConverter.convertMP3ToM4B(
            inputURLs: selectedFiles,
            outputURL: outputURL,
            author: author,
            title: title,
            coverImage: coverImage
        ) { progressValue in
            DispatchQueue.main.async {
                self.progress = progressValue
            }
        } completion: { result in
            DispatchQueue.main.async {
                self.isConverting = false
                self.progress = 0.0
                
                switch result {
                case .success:
                    self.errorMessage = "Конвертация завершена успешно!"
                    self.showError = true
                case .failure(let error):
                    self.errorMessage = "Ошибка конвертации: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}