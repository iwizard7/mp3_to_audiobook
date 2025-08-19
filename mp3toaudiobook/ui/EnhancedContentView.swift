import SwiftUI
import UniformTypeIdentifiers

struct EnhancedContentView: View {
    @State private var selectedFiles: [URL] = []
    @State private var outputFileName: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isConverting = false
    @State private var progress: Double = 0
    @State private var dragOver = false
    
    // Метаданные аудиокниги
    @State private var bookTitle: String = ""
    @State private var author: String = ""
    @State private var narrator: String = ""
    @State private var description: String = ""
    @State private var year: String = ""
    @State private var coverImageData: Data?
    
    // Настройки конвертации
    @State private var selectedFormat: OutputFormat = .m4b
    @State private var selectedQuality: AudioQuality = .high
    @State private var includeChapters: Bool = true
    
    // UI состояние
    @State private var showingMetadataSheet = false
    @State private var showingSettingsSheet = false
    
    private let converter = Converter()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerView
                fileDropZone
                metadataSection
                settingsSection
                conversionSection
            }
            .frame(minWidth: 600, minHeight: 700)
            .padding()
            .navigationTitle("MP3 to Audiobook")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Настройки") {
                        showingSettingsSheet = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Статус"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingMetadataSheet) {
            MetadataEditView(
                title: $bookTitle,
                author: $author,
                narrator: $narrator,
                description: $description,
                year: $year,
                coverImageData: $coverImageData
            )
        }
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsView(
                format: $selectedFormat,
                quality: $selectedQuality,
                includeChapters: $includeChapters
            )
        }
    }
    
    private var headerView: some View {
        VStack {
            Image(systemName: "book.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            Text("MP3 to Audiobook Converter")
                .font(.system(size: 24, weight: .bold, design: .rounded))
        }
    }
    
    private var fileDropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(dragOver ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                        .foregroundColor(dragOver ? .blue : .gray)
                )
            
            VStack(spacing: 16) {
                Image(systemName: selectedFiles.isEmpty ? "arrow.down.doc" : "music.note.list")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                if selectedFiles.isEmpty {
                    Text("Перетащите MP3 файлы сюда")
                        .font(.headline)
                    Text("или")
                    Button("Выберите файлы") {
                        selectFiles()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    fileListView
                }
            }
            .padding()
        }
        .frame(height: 300)
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleFileDrop(providers: providers)
            return true
        }
    }
    
    private var fileListView: some View {
        VStack {
            HStack {
                Text("Выбрано файлов: \(selectedFiles.count)")
                    .font(.headline)
                Spacer()
                Button("Очистить") {
                    selectedFiles.removeAll()
                }
                .buttonStyle(.bordered)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(selectedFiles.enumerated()), id: \.offset) { index, file in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                            Image(systemName: "music.note")
                                .foregroundColor(.blue)
                            Text(file.lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                selectedFiles.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
    }
    
    private var metadataSection: some View {
        GroupBox("Информация об аудиокниге") {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "text.book.closed")
                        .foregroundColor(.blue)
                    TextField("Название аудиокниги", text: $bookTitle)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.blue)
                    TextField("Автор", text: $author)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button("Дополнительные метаданные...") {
                    showingMetadataSheet = true
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var settingsSection: some View {
        GroupBox("Настройки экспорта") {
            HStack {
                VStack(alignment: .leading) {
                    Text("Формат: \(selectedFormat.displayName)")
                    Text("Качество: \(selectedQuality.displayName)")
                    Text("Главы: \(includeChapters ? "Включены" : "Отключены")")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Изменить") {
                    showingSettingsSheet = true
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var conversionSection: some View {
        VStack(spacing: 16) {
            if isConverting {
                VStack {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    Text("\(Int(progress * 100))% - Конвертация...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: startConversion) {
                HStack {
                    Image(systemName: isConverting ? "stop.circle" : "arrow.triangle.2.circlepath")
                    Text(isConverting ? "Отменить" : "Создать аудиокнигу")
                }
                .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedFiles.isEmpty || bookTitle.isEmpty)
        }
    }
    
    // MARK: - Actions
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "mp3")!]
        if panel.runModal() == .OK {
            selectedFiles = panel.urls
        }
    }
    
    private func handleFileDrop(providers: [NSItemProvider]) {
        providers.forEach { provider in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.pathExtension.lowercased() == "mp3" {
                    DispatchQueue.main.async {
                        if !selectedFiles.contains(url) {
                            selectedFiles.append(url)
                        }
                    }
                }
            }
        }
    }
    
    private func startConversion() {
        guard !selectedFiles.isEmpty, !bookTitle.isEmpty else {
            alertMessage = "Выберите файлы и введите название аудиокниги"
            showAlert = true
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = bookTitle
        savePanel.allowedContentTypes = [UTType(filenameExtension: selectedFormat.fileExtension)!]
        
        if savePanel.runModal() == .OK {
            if let outputURL = savePanel.url {
                performConversion(to: outputURL)
            }
        }
    }
    
    private func performConversion(to outputURL: URL) {
        isConverting = true
        progress = 0
        
        let metadata = AudiobookMetadata(
            title: bookTitle,
            author: author.isEmpty ? nil : author,
            narrator: narrator.isEmpty ? nil : narrator,
            description: description.isEmpty ? nil : description,
            year: year.isEmpty ? nil : year,
            coverImage: coverImageData
        )
        
        let settings = ConversionSettings(
            outputFormat: selectedFormat,
            quality: selectedQuality,
            includeChapters: includeChapters
        )
        
        Task {
            do {
                try await converter.convert(
                    files: selectedFiles,
                    output: outputURL,
                    metadata: metadata,
                    settings: settings
                ) { newProgress in
                    progress = newProgress
                }
                
                await MainActor.run {
                    alertMessage = "Аудиокнига успешно создана!\nФайл: \(outputURL.lastPathComponent)"
                    isConverting = false
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Ошибка создания аудиокниги:\n\(error.localizedDescription)"
                    isConverting = false
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct MetadataEditView: View {
    @Binding var title: String
    @Binding var author: String
    @Binding var narrator: String
    @Binding var description: String
    @Binding var year: String
    @Binding var coverImageData: Data?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Основная информация") {
                    TextField("Название", text: $title)
                    TextField("Автор", text: $author)
                    TextField("Рассказчик", text: $narrator)
                    TextField("Год", text: $year)
                }
                
                Section("Описание") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
                
                Section("Обложка") {
                    if let imageData = coverImageData,
                       let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                    }
                    
                    Button("Выбрать обложку") {
                        selectCoverImage()
                    }
                    
                    if coverImageData != nil {
                        Button("Удалить обложку") {
                            coverImageData = nil
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Метаданные")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private func selectCoverImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK,
           let url = panel.url {
            coverImageData = try? Data(contentsOf: url)
        }
    }
}

struct SettingsView: View {
    @Binding var format: OutputFormat
    @Binding var quality: AudioQuality
    @Binding var includeChapters: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Формат вывода") {
                    Picker("Формат", selection: $format) {
                        ForEach(OutputFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Качество аудио") {
                    Picker("Качество", selection: $quality) {
                        ForEach(AudioQuality.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Дополнительные опции") {
                    Toggle("Включить главы", isOn: $includeChapters)
                }
            }
            .navigationTitle("Настройки экспорта")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    EnhancedContentView()
}
