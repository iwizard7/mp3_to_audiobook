import Foundation

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
