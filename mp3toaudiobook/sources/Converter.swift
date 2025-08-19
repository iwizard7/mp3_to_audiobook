import Foundation
import AVFoundation

// MARK: - Models (временно здесь для простоты компиляции)

public struct AudiobookMetadata {
    let title: String
    let author: String?
    let narrator: String?
    let description: String?
    let genre: String
    let year: String?
    let coverImage: Data?
    let language: String
    
    public init(
        title: String,
        author: String? = nil,
        narrator: String? = nil,
        description: String? = nil,
        genre: String = "Audiobook",
        year: String? = nil,
        coverImage: Data? = nil,
        language: String = "ru"
    ) {
        self.title = title
        self.author = author
        self.narrator = narrator
        self.description = description
        self.genre = genre
        self.year = year
        self.coverImage = coverImage
        self.language = language
    }
}

public enum ConversionError: LocalizedError {
    case invalidInputFile(String)
    case noAudioTracks
    case exportFailed(String)
    case insufficientDiskSpace
    case unsupportedFormat(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidInputFile(let filename):
            return "Недопустимый входной файл: \(filename)"
        case .noAudioTracks:
            return "В файле не найдены аудиодорожки"
        case .exportFailed(let reason):
            return "Ошибка экспорта: \(reason)"
        case .insufficientDiskSpace:
            return "Недостаточно места на диске"
        case .unsupportedFormat(let format):
            return "Неподдерживаемый формат: \(format)"
        }
    }
}

public struct ConversionSettings {
    let outputFormat: OutputFormat
    let quality: AudioQuality
    let includeChapters: Bool
    let normalizeAudio: Bool
    
    public init(
        outputFormat: OutputFormat = .m4b,
        quality: AudioQuality = .high,
        includeChapters: Bool = true,
        normalizeAudio: Bool = false
    ) {
        self.outputFormat = outputFormat
        self.quality = quality
        self.includeChapters = includeChapters
        self.normalizeAudio = normalizeAudio
    }
}

public enum OutputFormat: String, CaseIterable {
    case m4b = "m4b"
    case m4a = "m4a"
    case mp3 = "mp3"
    
    var fileExtension: String {
        return rawValue
    }
    
    var displayName: String {
        switch self {
        case .m4b: return "M4B (Audiobook)"
        case .m4a: return "M4A (AAC Audio)"
        case .mp3: return "MP3"
        }
    }
}

public enum AudioQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case lossless = "lossless"
    
    var bitrate: String {
        switch self {
        case .low: return "64k"
        case .medium: return "128k"
        case .high: return "256k"
        case .lossless: return "0" // VBR
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "Низкое (64 kbps)"
        case .medium: return "Среднее (128 kbps)"
        case .high: return "Высокое (256 kbps)"
        case .lossless: return "Без потерь"
        }
    }
}

// MARK: - Chapter

public struct Chapter {
    let title: String
    let startTime: CMTime
    let duration: CMTime
    
    public init(title: String, startTime: CMTime, duration: CMTime) {
        self.title = title
        self.startTime = startTime
        self.duration = duration
    }
}

public class Converter {
    public init() {}
    
    public func convert(
        files: [URL], 
        output: URL, 
        metadata: AudiobookMetadata,
        settings: ConversionSettings = ConversionSettings(),
        progress: @escaping (Double) -> Void
    ) async throws {
        // Валидация входных файлов
        try await validateInputFiles(files)
        
        // Проверка доступного места на диске
        try checkDiskSpace(for: files, outputURL: output)
        let composition = AVMutableComposition()
        
        // Создаем аудио трек
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ConversionError.exportFailed("Не удалось создать аудиодорожку")
        }
        
        
        // Добавляем все файлы последовательно и создаем главы
        var currentTime = CMTime.zero
        var chapters: [Chapter] = []
        
        for (index, file) in files.enumerated() {
            let asset = AVURLAsset(url: file)
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            
            guard let track = tracks.first else { 
                throw ConversionError.noAudioTracks
            }
            
            let duration = try await asset.load(.duration)
            
            try audioTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: track,
                at: currentTime
            )
            
            let chapterTitle = file.deletingPathExtension().lastPathComponent
            let chapter = Chapter(
                title: chapterTitle,
                startTime: currentTime,
                duration: duration
            )
            chapters.append(chapter)
            currentTime = CMTimeAdd(currentTime, duration)
            
            let fileProgress = Double(index + 1) / Double(files.count) * 0.5
            await MainActor.run {
                progress(fileProgress)
            }
        }
        
        // Создаем расширенные метаданные
        let metadataItems = createAudiobookMetadata(from: metadata)
        
        // Настраиваем экспорт
        let presetName = getExportPreset(for: settings.quality)
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: presetName
        ) else {
            throw ConversionError.exportFailed("Не удалось создать сессию экспорта")
        }
        
        exportSession.outputURL = output
        exportSession.outputFileType = getOutputFileType(for: settings.outputFormat)
        exportSession.metadata = metadataItems
        
        // Добавляем главы если требуется
        if settings.includeChapters {
            exportSession.metadata?.append(contentsOf: createChapterMetadata(chapters: chapters))
        }
        
        // Наблюдаем за прогрессом экспорта
        let progressTask = Task {
            while !Task.isCancelled {
                let exportProgress = exportSession.progress
                await MainActor.run {
                    progress(0.5 + (Double(exportProgress) * 0.5))
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                if exportProgress >= 1.0 || exportSession.status == .completed {
                    break
                }
            }
        }
        
        // Выполняем экспорт
        await exportSession.export()
        progressTask.cancel()
        
        // Проверяем результат экспорта
        switch exportSession.status {
        case .completed:
            break
        case .failed:
            if let error = exportSession.error {
                throw ConversionError.exportFailed(error.localizedDescription)
            } else {
                throw ConversionError.exportFailed("Неизвестная ошибка экспорта")
            }
        case .cancelled:
            throw ConversionError.exportFailed("Экспорт был отменен")
        default:
            throw ConversionError.exportFailed("Неожиданный статус экспорта")
        }
    }
    
    // MARK: - Private Methods
    
    private func validateInputFiles(_ files: [URL]) async throws {
        for file in files {
            guard file.pathExtension.lowercased() == "mp3" else {
                throw ConversionError.unsupportedFormat(file.pathExtension)
            }
            
            guard FileManager.default.fileExists(atPath: file.path) else {
                throw ConversionError.invalidInputFile(file.lastPathComponent)
            }
        }
    }
    
    private func checkDiskSpace(for files: [URL], outputURL: URL) throws {
        let totalSize = files.compactMap { file in
            try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int64
        }.reduce(0, +)
        
        let outputDirectory = outputURL.deletingLastPathComponent()
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: outputDirectory.path),
           let freeSpace = attributes[.systemFreeSize] as? Int64 {
            if freeSpace < totalSize * 2 { // Требуем в 2 раза больше места для безопасности
                throw ConversionError.insufficientDiskSpace
            }
        }
    }
    
    private func getExportPreset(for quality: AudioQuality) -> String {
        switch quality {
        case .low:
            return AVAssetExportPresetLowQuality
        case .medium:
            return AVAssetExportPresetMediumQuality
        case .high, .lossless:
            return AVAssetExportPresetAppleM4A
        }
    }
    
    private func getOutputFileType(for format: OutputFormat) -> AVFileType {
        switch format {
        case .m4b, .m4a:
            return .m4a
        case .mp3:
            return .mp3
        }
    }
    
    private func createChapterMetadata(chapters: [Chapter]) -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []
        
        for (index, chapter) in chapters.enumerated() {
            let titleItem = AVMutableMetadataItem()
            titleItem.identifier = .commonIdentifierTitle
            titleItem.value = chapter.title as NSString
            titleItem.extendedLanguageTag = "und"
            titleItem.time = chapter.startTime
            titleItem.duration = chapter.duration
            
            items.append(titleItem)
        }
        
        return items
    }
    
    private func createAudiobookMetadata(from metadata: AudiobookMetadata) -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []
        
        // Название
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = metadata.title as NSString
        titleItem.extendedLanguageTag = metadata.language
        items.append(titleItem)
        
        // Автор
        if let author = metadata.author {
            let authorItem = AVMutableMetadataItem()
            authorItem.identifier = .commonIdentifierArtist
            authorItem.value = author as NSString
            authorItem.extendedLanguageTag = metadata.language
            items.append(authorItem)
        }
        
        // Рассказчик
        if let narrator = metadata.narrator {
            let narratorItem = AVMutableMetadataItem()
            narratorItem.identifier = .iTunesMetadataTrackSubTitle
            narratorItem.value = narrator as NSString
            narratorItem.extendedLanguageTag = metadata.language
            items.append(narratorItem)
        }
        
        // Жанр
        let genreItem = AVMutableMetadataItem()
        genreItem.identifier = .commonIdentifierType
        genreItem.value = metadata.genre as NSString
        genreItem.extendedLanguageTag = metadata.language
        items.append(genreItem)
        
        // Год
        if let year = metadata.year {
            let yearItem = AVMutableMetadataItem()
            yearItem.identifier = .commonIdentifierCreationDate
            yearItem.value = year as NSString
            yearItem.extendedLanguageTag = metadata.language
            items.append(yearItem)
        }
        
        // Описание
        if let description = metadata.description {
            let descriptionItem = AVMutableMetadataItem()
            descriptionItem.identifier = .commonIdentifierDescription
            descriptionItem.value = description as NSString
            descriptionItem.extendedLanguageTag = metadata.language
            items.append(descriptionItem)
        }
        
        // Обложка
        if let coverImage = metadata.coverImage {
            let artworkItem = AVMutableMetadataItem()
            artworkItem.identifier = .commonIdentifierArtwork
            artworkItem.value = coverImage as NSData
            artworkItem.dataType = kCMMetadataBaseDataType_JPEG as String
            items.append(artworkItem)
        }
        
        return items
    }
}
