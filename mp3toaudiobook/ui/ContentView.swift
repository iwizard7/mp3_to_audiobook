import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedFiles: [URL] = []
    @State private var outputFileName: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isConverting = false
    @State private var progress: Double = 0
    @State private var dragOver = false
    
    private let converter = Converter()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MP3 to Audiobook")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding(.top)
            
            // Зона для драг-н-дропа файлов
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
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = true
                            panel.canChooseDirectories = false
                            panel.allowedContentTypes = [UTType(filenameExtension: "mp3")!]
                            if panel.runModal() == .OK {
                                self.selectedFiles = panel.urls
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(selectedFiles, id: \.self) { file in
                                    HStack {
                                        Image(systemName: "music.note")
                                            .foregroundColor(.blue)
                                        Text(file.lastPathComponent)
                                            .lineLimit(1)
                                        Spacer()
                                        Button {
                                            selectedFiles.removeAll { $0 == file }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                .padding()
            }
            .frame(height: 300)
            .padding()
            .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
                providers.forEach { provider in
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url, url.pathExtension.lowercased() == "mp3" {
                            DispatchQueue.main.async {
                                self.selectedFiles.append(url)
                            }
                        }
                    }
                }
                return true
            }
            
            // Поле для имени выходного файла
            HStack {
                Image(systemName: "text.book.closed")
                    .foregroundColor(.blue)
                TextField("Имя аудиокниги", text: $outputFileName)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            // Кнопка конвертации и прогресс
            VStack {
                if isConverting {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .padding()
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                }
                
                Button(action: {
                    if selectedFiles.isEmpty || outputFileName.isEmpty {
                        alertMessage = "Выберите файлы и введите имя аудиокниги"
                        showAlert = true
                        return
                    }
                    
                    let savePanel = NSSavePanel()
                    savePanel.nameFieldStringValue = outputFileName
                    savePanel.allowedContentTypes = [UTType(filenameExtension: "m4b")!]
                    
                    if savePanel.runModal() == .OK {
                        if let outputURL = savePanel.url {
                            isConverting = true
                            progress = 0
                            
                            Task {
                                do {
                                    try await converter.convert(files: selectedFiles, output: outputURL) { newProgress in
                                        progress = newProgress
                                    }
                                    alertMessage = "Конвертация завершена успешно!"
                                } catch {
                                    alertMessage = "Ошибка конвертации: \(error.localizedDescription)"
                                }
                                isConverting = false
                                showAlert = true
                            }
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Конвертировать")
                    }
                    .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConverting)
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Статус"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
