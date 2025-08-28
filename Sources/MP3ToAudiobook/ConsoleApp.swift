import Foundation
import AVFoundation
import AppKit

struct ConsoleApp {
    static func main() {
        print("🎵 Аудио в M4B Конвертер (Консольная версия)")
        print("==============================================")

        let args = CommandLine.arguments

        if args.count < 2 {
            printUsage()
            return
        }

        let config = parseArguments(args)
        guard let config = config else {
            printUsage()
            return
        }

        runConversion(with: config)
    }

    private static func printUsage() {
        print("\nИспользование:")
        print("  \(CommandLine.arguments[0]) <входные_файлы> [опции]")
        print("\nПримеры:")
        print("  \(CommandLine.arguments[0]) *.mp3 --author \"Лев Толстой\" --title \"Война и мир\"")
        print("  \(CommandLine.arguments[0]) chapter1.mp3 chapter2.mp3 --output book.m4b --cover cover.jpg")
        print("  \(CommandLine.arguments[0]) /path/to/folder --auto-detect")
        print("\nОпции:")
        print("  --author <текст>       Автор книги")
        print("  --title <текст>        Название книги")
        print("  --genre <текст>        Жанр")
        print("  --description <текст>  Описание книги")
        print("  --series <текст>       Название серии")
        print("  --series-number <номер> Номер книги в серии")
        print("  --cover <файл>         Путь к обложке")
        print("  --output <файл>        Выходной файл (по умолчанию: <title>.m4b)")
        print("  --auto-detect          Автоматически определить метаданные из названия папки")
        print("  --recursive            Рекурсивный поиск аудиофайлов в папках")
        print("  --quality <уровень>    Качество экспорта (high, medium, low)")
        print("  --chapters <мин>       Разделить на главы (длительность в минутах)")
        print("  --help                 Показать эту справку")
    }

    private static func parseArguments(_ args: [String]) -> ConversionConfig? {
        var config = ConversionConfig()
        var inputFiles: [String] = []
        var i = 1

        while i < args.count {
            let arg = args[i]

            switch arg {
            case "--help":
                printUsage()
                return nil
            case "--author":
                if i + 1 < args.count {
                    config.author = args[i + 1]
                    i += 2
                } else {
                    print("❌ Ошибка: не указан автор после --author")
                    return nil
                }
            case "--title":
                if i + 1 < args.count {
                    config.title = args[i + 1]
                    i += 2
                } else {
                    print("❌ Ошибка: не указано название после --title")
                    return nil
                }
            case "--genre":
                if i + 1 < args.count {
                    config.genre = args[i + 1]
                    i += 2
                } else {
                    print("❌ Ошибка: не указан жанр после --genre")
                    return nil
                }
            case "--description":
                if i + 1 < args.count {
                    config.description = args[i + 1]
                    i += 2
                } else {
                    print("❌ Ошибка: не указано описание после --description")
                    return nil
                }
            case "--series":
                if i + 1 < args.count {
                    config.series = args[i + 1]
                    i += 2
                } else {
                    print("❌ Ошибка: не указана серия после --series")
                    return nil
                }
            case "--series-number":
                if i + 1 < args.count {
                    config.seriesNumber = args[i + 1]
                    i += 2
                } else {
                    print("❌ Ошибка: не указан номер серии после --series-number")
                    return nil
                }
            case "--cover":
                if i + 1 < args.count {
                    config.coverPath = args[i + 1]
                    i += 2
                } else {
                    print("❌ Ошибка: не указан путь к обложке после --cover")
                    return nil
                }
            case "--output":
                if i + 1 < args.count {
                    config.outputPath = args[i + 1]
                    i += 2
                } else {
                    print("❌ Ошибка: не указан выходной файл после --output")
                    return nil
                }
            case "--auto-detect":
                config.autoDetect = true
                i += 1
            case "--recursive":
                config.recursive = true
                i += 1
            case "--quality":
                if i + 1 < args.count {
                    config.quality = args[i + 1]
                    i += 2
                } else {
                    print("❌ Ошибка: не указано качество после --quality")
                    return nil
                }
            case "--chapters":
                if i + 1 < args.count {
                    config.chapterDuration = Int(args[i + 1]) ?? 0
                    i += 2
                } else {
                    print("❌ Ошибка: не указана длительность глав после --chapters")
                    return nil
                }
            default:
                // Это входной файл или папка
                inputFiles.append(arg)
                i += 1
            }
        }

        // Обработка входных файлов
        config.inputFiles = resolveInputFiles(inputFiles)

        if config.inputFiles.isEmpty {
            print("❌ Ошибка: не найдено входных файлов")
            return nil
        }

        // Автоопределение метаданных если включено
        if config.autoDetect {
            autoDetectMetadata(&config)
        }

        // Проверка обязательных полей
        if config.title.isEmpty {
            print("❌ Ошибка: не указано название книги (--title)")
            return nil
        }

        // Установка выходного файла по умолчанию
        if config.outputPath.isEmpty {
            config.outputPath = "\(config.title).m4b"
        }

        return config
    }

    private static func resolveInputFiles(_ inputs: [String]) -> [URL] {
        var files: [URL] = []

        for input in inputs {
            let url = URL(fileURLWithPath: input)

            if url.hasDirectoryPath {
                // Это папка - найти все аудиофайлы
                if let folderFiles = findAudioFiles(in: url, recursive: config.recursive) {
                    files.append(contentsOf: folderFiles)
                }
            } else {
                // Это файл
                if isAudioFile(url) {
                    files.append(url)
                }
            }
        }

        return files.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func findAudioFiles(in directory: URL, recursive: Bool = true) -> [URL]? {
        let fileManager = FileManager.default
        let audioExtensions = ["mp3", "aac", "m4a", "wav", "aiff"]
        var audioFiles: [URL] = []

        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])

        while let fileURL = enumerator?.nextObject() as? URL {
            if recursive || fileURL.deletingLastPathComponent() == directory {
                let ext = fileURL.pathExtension.lowercased()
                if audioExtensions.contains(ext) {
                    audioFiles.append(fileURL)
                }
            }
        }

        return audioFiles.isEmpty ? nil : audioFiles
    }

    private static func isAudioFile(_ url: URL) -> Bool {
        let audioExtensions = ["mp3", "aac", "m4a", "wav", "aiff"]
        return audioExtensions.contains(url.pathExtension.lowercased())
    }

    private static func autoDetectMetadata(_ config: inout ConversionConfig) {
        if let firstFile = config.inputFiles.first {
            let folderURL = firstFile.deletingLastPathComponent()
            let folderName = folderURL.lastPathComponent

            let components = folderName.components(separatedBy: " - ")
            if components.count >= 2 {
                if config.author.isEmpty {
                    config.author = components[0].trimmingCharacters(in: .whitespaces)
                }
                if config.title.isEmpty {
                    config.title = components[1].trimmingCharacters(in: .whitespaces)
                }
            } else if config.title.isEmpty {
                config.title = folderName
            }
        }
    }

    private static func runConversion(with config: ConversionConfig) {
        print("\n📁 Найдено файлов: \(config.inputFiles.count)")
        for (index, file) in config.inputFiles.enumerated() {
            print("  [\(index + 1)] \(file.lastPathComponent)")
        }

        print("\n📋 Конфигурация:")
        print("  Автор: \(config.author)")
        print("  Название: \(config.title)")
        print("  Жанр: \(config.genre)")
        print("  Описание: \(config.description)")
        print("  Серия: \(config.series)")
        print("  Номер в серии: \(config.seriesNumber)")
        print("  Качество: \(config.quality)")
        print("  Главы: \(config.chapterDuration > 0 ? "\(config.chapterDuration) мин" : "без разделения")")
        print("  Обложка: \(config.coverPath ?? "нет")")
        print("  Выход: \(config.outputPath)")

        print("\n🔄 Начинаем конвертацию...")

        // Загрузка обложки
        var coverImage: NSImage?
        if let coverPath = config.coverPath {
            coverImage = NSImage(contentsOfFile: coverPath)
            if coverImage == nil {
                print("⚠️  Предупреждение: не удалось загрузить обложку \(coverPath)")
            }
        }

        // Конвертация
        AudioConverter.convertAudioToM4B(
            inputURLs: config.inputFiles,
            outputURL: URL(fileURLWithPath: config.outputPath),
            author: config.author,
            title: config.title,
            genre: config.genre,
            description: config.description,
            series: config.series,
            seriesNumber: config.seriesNumber,
            quality: config.quality,
            chapterDurationMinutes: config.chapterDuration,
            coverImage: coverImage
        ) { progress in
            print("   Прогресс: \(Int(progress * 100))%")
        } completion: { result in
            switch result {
            case .success:
                print("\n✅ Конвертация завершена успешно!")
                print("   Создан файл: \(config.outputPath)")
                if let attributes = try? FileManager.default.attributesOfItem(atPath: config.outputPath),
                   let fileSize = attributes[.size] as? Int64 {
                    let sizeMB = Double(fileSize) / 1024.0 / 1024.0
                    print("   Размер: \(String(format: "%.1f", sizeMB)) MB")
                }
                print("   Метаданные добавлены: ✓")
                print("\n🎉 Готово! Файл готов для использования в Apple Books")
            case .failure(let error):
                print("\n❌ Ошибка конвертации: \(error.localizedDescription)")
                exit(1)
            }
        }

        // Ожидание завершения (простая реализация)
        RunLoop.main.run()
    }
}

struct ConversionConfig {
    var inputFiles: [URL] = []
    var author = ""
    var title = ""
    var genre = ""
    var description = ""
    var series = ""
    var seriesNumber = ""
    var coverPath: String?
    var outputPath = ""
    var autoDetect = false
    var recursive = false
    var quality = "high" // high, medium, low
    var chapterDuration = 0 // в минутах, 0 = без разделения
}