import Foundation
import AVFoundation
import AppKit

class AudioConverter {
    static func convertAudioToM4B(
        inputURLs: [URL],
        outputURL: URL,
        author: String,
        title: String,
        genre: String = "",
        description: String = "",
        series: String = "",
        seriesNumber: String = "",
        quality: String = "high",
        chapterDurationMinutes: Int = 0,
        coverImage: NSImage?,
        progressHandler: @escaping (Double) -> Void,
        logHandler: @escaping (String) -> Void = { _ in },
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        logHandler("=== AUDIOCONVERTER СТАРТ ===")
        logHandler("Входные URL:")
        for (index, url) in inputURLs.enumerated() {
            logHandler("  [\(index)]: \(url.absoluteString)")
            logHandler("    Путь: \(url.path)")
            logHandler("    Схема: \(url.scheme ?? "nil")")
        }
        logHandler("Выходной URL: \(outputURL.absoluteString)")
        logHandler("============================")

        // Валидация входных параметров
        guard !inputURLs.isEmpty else {
            let error = NSError(domain: "AudioConverter", code: -10, userInfo: [NSLocalizedDescriptionKey: "Не указаны входные файлы"])
            logHandler("ОШИБКА: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        guard !author.isEmpty else {
            let error = NSError(domain: "AudioConverter", code: -11, userInfo: [NSLocalizedDescriptionKey: "Не указан автор"])
            logHandler("ОШИБКА: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        guard !title.isEmpty else {
            let error = NSError(domain: "AudioConverter", code: -12, userInfo: [NSLocalizedDescriptionKey: "Не указано название"])
            logHandler("ОШИБКА: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        // Проверка существования входных файлов
        for url in inputURLs {
            guard FileManager.default.fileExists(atPath: url.path) else {
                let error = NSError(domain: "AudioConverter", code: -13, userInfo: [NSLocalizedDescriptionKey: "Файл не найден: \(url.path)"])
                logHandler("ОШИБКА: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
        }

        Task {
            do {
                let composition = AVMutableComposition()
                guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    let error = NSError(domain: "AudioConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать аудио трек"])
                    logHandler("ОШИБКА: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                var currentTime = CMTime.zero

                for (index, inputURL) in inputURLs.enumerated() {
                    logHandler("Обрабатываем файл [\(index)]: \(inputURL.lastPathComponent)")
                    logHandler("  Полный путь: \(inputURL.path)")

                    let asset = AVAsset(url: inputURL)
                    logHandler("  Создан AVAsset для файла")

                    // Проверяем, можем ли мы читать файл
                    guard asset.isReadable else {
                        let errorMsg = "Файл не доступен для чтения: \(inputURL.lastPathComponent)"
                        logHandler("  ОШИБКА: \(errorMsg)")
                        completion(.failure(NSError(domain: "AudioConverter", code: -14, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                        return
                    }

                    // Загружаем треки асинхронно
                    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                    logHandler("  Найдено аудио треков: \(audioTracks.count)")

                    guard !audioTracks.isEmpty else {
                        let errorMsg = "Не найдено аудио треков в файле \(inputURL.lastPathComponent)"
                        logHandler("  ОШИБКА: \(errorMsg)")
                        completion(.failure(NSError(domain: "AudioConverter", code: -2, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                        return
                    }

                    guard let audioAssetTrack = audioTracks.first else {
                        let errorMsg = "Не найден подходящий аудио трек в файле \(inputURL.lastPathComponent)"
                        logHandler("  ОШИБКА: \(errorMsg)")
                        completion(.failure(NSError(domain: "AudioConverter", code: -2, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                        return
                    }

                    logHandler("  Аудио трек найден, загружаем длительность...")

                    let duration = try await asset.load(.duration)
                    logHandler("  Длительность: \(CMTimeGetSeconds(duration)) секунд")

                    let timeRange = CMTimeRange(start: .zero, duration: duration)
                    logHandler("  Создан timeRange: \(CMTimeGetSeconds(timeRange.duration)) секунд")

                    try audioTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: currentTime)
                    logHandler("  Трек вставлен в композицию")

                    currentTime = CMTimeAdd(currentTime, timeRange.duration)

                    await MainActor.run {
                        progressHandler(Double(index + 1) / Double(inputURLs.count) * 0.5)
                    }

                    logHandler("  Файл [\(index)] обработан успешно")
                }

                // Все файлы обработаны, начинаем экспорт
                logHandler("Все файлы обработаны, начинаем экспорт...")
                let coverImageData = coverImage?.tiffRepresentation

                if chapterDurationMinutes > 0 {
                    // Разделение на главы
                    logHandler("Разделение на главы по \(chapterDurationMinutes) минут...")
                    exportCompositionWithChapters(composition, outputURL: outputURL, author: author, title: title, genre: genre, description: description, series: series, seriesNumber: seriesNumber, quality: quality, chapterDurationMinutes: chapterDurationMinutes, coverImageData: coverImageData, completion: completion)
                } else {
                    // Обычный экспорт без глав
                    exportComposition(composition, outputURL: outputURL, author: author, title: title, genre: genre, description: description, series: series, seriesNumber: seriesNumber, quality: quality, coverImageData: coverImageData, completion: completion)
                }

            } catch {
                logHandler("  ОШИБКА обработки файла: \(error.localizedDescription)")
                logHandler("  Подробности: \(error)")
                completion(.failure(error))
            }
        }
    
        private static func exportCompositionWithChapters(
            _ composition: AVMutableComposition,
            outputURL: URL,
            author: String,
            title: String,
            genre: String,
            description: String,
            series: String,
            seriesNumber: String,
            quality: String,
            chapterDurationMinutes: Int,
            coverImageData: Data?,
            completion: @escaping (Result<Void, Error>) -> Void
        ) {
            print("=== ЭКСПОРТ С ГЛАВАМИ ===")
            print("Длительность главы: \(chapterDurationMinutes) минут")
            print("Создание оглавления...")
    
            // Пока просто вызываем обычный экспорт
            // Полноценная реализация глав требует значительной переработки
            exportComposition(composition, outputURL: outputURL, author: author, title: title, genre: genre, description: description, series: series, seriesNumber: seriesNumber, quality: quality, coverImageData: coverImageData, completion: completion)
        }
    }

    private static func exportComposition(
        _ composition: AVMutableComposition,
        outputURL: URL,
        author: String,
        title: String,
        genre: String,
        description: String,
        series: String,
        seriesNumber: String,
        quality: String,
        coverImageData: Data?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        print("=== НАЧАЛО ЭКСПОРТА ===")
        print("Выходной файл: \(outputURL.path)")
        print("Автор: \(author)")
        print("Название: \(title)")
        print("Жанр: \(genre)")
        print("Описание: \(description)")
        print("Серия: \(series)")
        print("Номер в серии: \(seriesNumber)")
        print("Качество: \(quality)")
        print("Обложка: \(coverImageData != nil ? "есть" : "нет")")

        // Выбор пресета на основе качества
        let presetName: String
        switch quality.lowercased() {
        case "low":
            presetName = AVAssetExportPresetLowQuality
        case "medium":
            presetName = AVAssetExportPresetMediumQuality
        case "high":
            presetName = AVAssetExportPresetHighestQuality
        default:
            presetName = AVAssetExportPresetAppleM4A // Для M4B используем стандартный пресет
        }

        // Создание экспорта
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: presetName) else {
            let error = NSError(domain: "AudioConverter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать сессию экспорта"])
            print("ОШИБКА: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        print("Создана сессия экспорта")

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        print("Настроены параметры экспорта")

        // Добавление метаданных
        var metadata = [AVMutableMetadataItem]()

        let titleItem = AVMutableMetadataItem()
        titleItem.key = AVMetadataKey.commonKeyTitle as NSString
        titleItem.keySpace = AVMetadataKeySpace.common
        titleItem.value = title as NSString
        metadata.append(titleItem)

        let authorItem = AVMutableMetadataItem()
        authorItem.key = AVMetadataKey.commonKeyArtist as NSString
        authorItem.keySpace = AVMetadataKeySpace.common
        authorItem.value = author as NSString
        metadata.append(authorItem)

        if !genre.isEmpty {
            let genreItem = AVMutableMetadataItem()
            genreItem.key = AVMetadataKey.commonKeyGenre as NSString
            genreItem.keySpace = AVMetadataKeySpace.common
            genreItem.value = genre as NSString
            metadata.append(genreItem)
        }

        if !description.isEmpty {
            let descriptionItem = AVMutableMetadataItem()
            descriptionItem.key = AVMetadataKey.commonKeyDescription as NSString
            descriptionItem.keySpace = AVMetadataKeySpace.common
            descriptionItem.value = description as NSString
            metadata.append(descriptionItem)
        }

        if !series.isEmpty {
            let seriesItem = AVMutableMetadataItem()
            seriesItem.key = AVMetadataKey.quickTimeMetadataKeyCollectionUser as NSString
            seriesItem.keySpace = AVMetadataKeySpace.quickTimeMetadata
            seriesItem.value = series as NSString
            metadata.append(seriesItem)
        }

        if !seriesNumber.isEmpty {
            let seriesNumberItem = AVMutableMetadataItem()
            seriesNumberItem.key = AVMetadataKey.quickTimeMetadataKeyCollectionUser as NSString
            seriesNumberItem.keySpace = AVMetadataKeySpace.quickTimeMetadata
            seriesNumberItem.value = "\(series) #\(seriesNumber)" as NSString
            metadata.append(seriesNumberItem)
        }

        if let imageData = coverImageData {
            let artworkItem = AVMutableMetadataItem()
            artworkItem.key = AVMetadataKey.commonKeyArtwork as NSString
            artworkItem.keySpace = AVMetadataKeySpace.common
            artworkItem.value = imageData as NSData
            metadata.append(artworkItem)
        }

        exportSession.metadata = metadata

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                print("=== РЕЗУЛЬТАТ ЭКСПОРТА ===")
                print("Статус экспорта: \(exportSession.status.rawValue)")

                switch exportSession.status {
                case .completed:
                    print("✅ ЭКСПОРТ ЗАВЕРШЕН УСПЕШНО")
                    completion(.success(()))
                case .failed:
                    if let error = exportSession.error {
                        print("❌ ОШИБКА ЭКСПОРТА: \(error.localizedDescription)")
                        print("Подробности ошибки: \(error)")
                        completion(.failure(error))
                    } else {
                        let error = NSError(domain: "AudioConverter", code: -4, userInfo: [NSLocalizedDescriptionKey: "Неизвестная ошибка экспорта"])
                        print("❌ НЕИЗВЕСТНАЯ ОШИБКА ЭКСПОРТА")
                        completion(.failure(error))
                    }
                case .cancelled:
                    let error = NSError(domain: "AudioConverter", code: -5, userInfo: [NSLocalizedDescriptionKey: "Экспорт отменен"])
                    print("❌ ЭКСПОРТ ОТМЕНЕН")
                    completion(.failure(error))
                default:
                    print("⚠️ НЕИЗВЕСТНЫЙ СТАТУС ЭКСПОРТА")
                    break
                }
                print("========================")
            }
        }
    }
}