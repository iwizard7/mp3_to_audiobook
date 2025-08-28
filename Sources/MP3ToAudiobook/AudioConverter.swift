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
        print("=== AUDIOCONVERTER FUNCTION CALLED ===")
        print("Input URLs count: \(inputURLs.count)")
        print("Output URL: \(outputURL.path)")
        print("Author: \(author)")
        print("Title: \(title)")

        print("Starting logHandler call...")
        logHandler("=== AUDIOCONVERTER СТАРТ ===")
        print("logHandler call completed")
        logHandler("Входные параметры:")
        logHandler("  Количество файлов: \(inputURLs.count)")
        logHandler("  Выходной файл: \(outputURL.path)")
        logHandler("  Автор: \(author)")
        logHandler("  Название: \(title)")
        logHandler("  Качество: \(quality)")
        logHandler("  Главы: \(chapterDurationMinutes > 0 ? "да (\(chapterDurationMinutes) мин)" : "нет")")
        logHandler("  Обложка: \(coverImage != nil ? "есть" : "нет")")

        logHandler("Проверяем входные URL:")
        for (index, url) in inputURLs.enumerated() {
            logHandler("  [\(index)]: \(url.lastPathComponent)")
            logHandler("    Полный путь: \(url.path)")
            logHandler("    Схема: \(url.scheme ?? "nil")")
        }
        logHandler("============================")

        logHandler("=== ВАЛИДАЦИЯ ПАРАМЕТРОВ ===")

        // Валидация входных параметров
        guard !inputURLs.isEmpty else {
            let error = NSError(domain: "AudioConverter", code: -10, userInfo: [NSLocalizedDescriptionKey: "Не указаны входные файлы"])
            logHandler("❌ ОШИБКА ВАЛИДАЦИИ: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        logHandler("✅ Количество файлов: \(inputURLs.count)")

        guard !author.isEmpty else {
            let error = NSError(domain: "AudioConverter", code: -11, userInfo: [NSLocalizedDescriptionKey: "Не указан автор"])
            logHandler("❌ ОШИБКА ВАЛИДАЦИИ: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        logHandler("✅ Автор: \(author)")

        guard !title.isEmpty else {
            let error = NSError(domain: "AudioConverter", code: -12, userInfo: [NSLocalizedDescriptionKey: "Не указано название"])
            logHandler("❌ ОШИБКА ВАЛИДАЦИИ: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        logHandler("✅ Название: \(title)")

        // Проверка существования входных файлов
        logHandler("Проверяем существование файлов:")
        for (index, url) in inputURLs.enumerated() {
            guard FileManager.default.fileExists(atPath: url.path) else {
                let error = NSError(domain: "AudioConverter", code: -13, userInfo: [NSLocalizedDescriptionKey: "Файл не найден: \(url.path)"])
                logHandler("❌ ОШИБКА: Файл [\(index)] не найден: \(url.lastPathComponent)")
                completion(.failure(error))
                return
            }
            logHandler("  ✅ Файл [\(index)] существует: \(url.lastPathComponent)")
        }
        logHandler("Все файлы существуют")

        print("About to start Task...")
        logHandler("=== ЗАПУСК ОБРАБОТКИ ===")
        print("logHandler for ЗАПУСК ОБРАБОТКИ completed")

        print("Creating Task...")
        Task {
            print("Task started successfully")
            do {
                print("Starting file processing...")
                print("Input URLs count in Task: \(inputURLs.count)")

                logHandler("=== НАЧАЛО ОБРАБОТКИ ФАЙЛОВ ===")
                print("logHandler for НАЧАЛО ОБРАБОТКИ ФАЙЛОВ completed")
                logHandler("Количество файлов для обработки: \(inputURLs.count)")
                print("About to create temp directory...")

            // Создаем временную директорию для промежуточных файлов
            print("Creating UUID...")
            let uuidString = UUID().uuidString
            print("UUID created: \(uuidString)")

            print("Creating temp directory path...")
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("MP3ToAudiobook_temp_\(uuidString)")
            print("Temp directory path: \(tempDir.path)")

            print("Removing existing temp directory if exists...")
            try? FileManager.default.removeItem(at: tempDir) // Удаляем если существует
            print("Creating temp directory...")

            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            print("Temp directory created successfully")

            logHandler("Создана временная директория: \(tempDir.path)")
            print("logHandler for temp directory completed")

            print("Initializing variables...")
            var wavFiles: [URL] = []
            var totalDuration: TimeInterval = 0
            var processedCount = 0
            print("Variables initialized successfully")

            // Обрабатываем файлы по одному для лучшей стабильности
            print("About to start file processing loop...")
            print("Input URLs count before loop: \(inputURLs.count)")

            for (index, inputURL) in inputURLs.enumerated() {
                print("Starting iteration [\(index)] of file processing loop")
                print("Input URL: \(inputURL)")
                print("Input URL path: \(inputURL.path)")
                print("Input URL scheme: \(inputURL.scheme ?? "nil")")

                logHandler("=== ОБРАБОТКА ФАЙЛА [\(index + 1)/\(inputURLs.count)] ===")
                print("First logHandler call in loop completed")

                logHandler("Файл: \(inputURL.lastPathComponent)")
                print("Second logHandler call in loop completed")

                logHandler("Путь: \(inputURL.path)")
                print("Third logHandler call in loop completed")

                // Проверяем существование файла
                print("About to check file existence...")
                let fileExists = FileManager.default.fileExists(atPath: inputURL.path)
                print("File exists check result: \(fileExists)")

                guard fileExists else {
                    let errorMsg = "Файл не найден: \(inputURL.path)"
                    print("File not found: \(inputURL.path)")
                    logHandler("ОШИБКА: \(errorMsg)")
                    completion(.failure(NSError(domain: "AudioConverter", code: -13, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    return
                }
                print("File existence check passed")

                do {
                    print("About to create AVAsset...")
                    let asset = AVAsset(url: inputURL)
                    print("AVAsset created successfully")
                    print("About to call logHandler for AVAsset creation...")
                    logHandler("Создан AVAsset для файла")
                    print("logHandler for AVAsset creation completed")

                    // Проверяем, можем ли мы читать файл
                    print("About to call asset.load(.isReadable)...")
                    let isReadable = try await asset.load(.isReadable)
                    print("asset.load(.isReadable) completed successfully: \(isReadable)")
                    print("About to check isReadable guard...")
                    guard isReadable else {
                        let errorMsg = "Файл не доступен для чтения: \(inputURL.lastPathComponent)"
                        print("About to call logHandler for error...")
                        logHandler("ОШИБКА: \(errorMsg)")
                        print("About to create NSError...")
                        completion(.failure(NSError(domain: "AudioConverter", code: -14, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                        print("About to return from error case...")
                        return
                    }
                    print("isReadable check passed")

                    // Пробуем альтернативный подход - используем AVAudioFile для проверки файла
                    print("About to try AVAudioFile approach...")
                    do {
                        let audioFile = try AVAudioFile(forReading: inputURL)
                        let durationSeconds = Double(audioFile.length) / audioFile.processingFormat.sampleRate
                        totalDuration += durationSeconds
                        logHandler("Длительность файла: \(durationSeconds) секунд (через AVAudioFile)")

                        // Создаем WAV файл
                        let wavURL = tempDir.appendingPathComponent(String(format: "%03d", index) + ".wav")
                        logHandler("Создаем WAV файл: \(wavURL.lastPathComponent)")

                        try await convertToWAV(inputURL: inputURL, outputURL: wavURL, logHandler: logHandler)
                        wavFiles.append(wavURL)
                        processedCount += 1

                        logHandler("✅ Файл [\(index + 1)] успешно конвертирован в WAV")

                        let currentProgress = Double(processedCount) / Double(inputURLs.count) * 0.4
                        await MainActor.run {
                            progressHandler(currentProgress)
                        }
                    } catch {
                        print("AVAudioFile approach failed: \(error.localizedDescription)")
                        logHandler("⚠️ AVAudioFile не сработал, пробуем AVAsset: \(error.localizedDescription)")

                        // Fallback to original AVAsset approach
                        let duration = try await asset.load(.duration)
                        let durationSeconds = CMTimeGetSeconds(duration)
                        totalDuration += durationSeconds
                        logHandler("Длительность файла: \(durationSeconds) секунд (через AVAsset)")

                        // Создаем WAV файл
                        let wavURL = tempDir.appendingPathComponent(String(format: "%03d", index) + ".wav")
                        logHandler("Создаем WAV файл: \(wavURL.lastPathComponent)")

                        try await convertToWAV(inputURL: inputURL, outputURL: wavURL, logHandler: logHandler)
                        wavFiles.append(wavURL)
                        processedCount += 1

                        logHandler("✅ Файл [\(index + 1)] успешно конвертирован в WAV (через AVAsset)")

                        let currentProgress = Double(processedCount) / Double(inputURLs.count) * 0.4
                        await MainActor.run {
                            progressHandler(currentProgress)
                        }
                    }

                } catch {
                    logHandler("❌ ОШИБКА при обработке файла [\(index + 1)]: \(error.localizedDescription)")
                    logHandler("Подробности ошибки: \(error)")

                    // Очищаем временные файлы перед выходом
                    try? FileManager.default.removeItem(at: tempDir)
                    completion(.failure(error))
                    return
                }
            }

            logHandler("=== ВСЕ ФАЙЛЫ ОБРАБОТАНЫ ===")
            logHandler("Общее количество обработанных файлов: \(processedCount)")
            logHandler("Общая длительность: \(totalDuration) секунд")
            logHandler("Количество WAV файлов: \(wavFiles.count)")

            // Объединяем все WAV файлы
            logHandler("=== ОБЪЕДИНЕНИЕ WAV ФАЙЛОВ ===")
            let combinedWAV = tempDir.appendingPathComponent("combined.wav")
            logHandler("Объединяем в файл: \(combinedWAV.lastPathComponent)")

            try await combineWAVFiles(inputURLs: wavFiles, outputURL: combinedWAV, logHandler: logHandler)

            await MainActor.run {
                progressHandler(0.7)
            }

            logHandler("✅ WAV файлы успешно объединены")

            // Конвертируем объединенный WAV в M4A
            logHandler("=== КОНВЕРТАЦИЯ В M4A ===")
            let coverImageData = coverImage?.tiffRepresentation
            logHandler("Выходной файл: \(outputURL.path)")
            logHandler("Обложка: \(coverImageData != nil ? "есть" : "нет")")

            if chapterDurationMinutes > 0 {
                logHandler("Используем режим с главами (по \(chapterDurationMinutes) минут)")
                exportWAVWithChapters(combinedWAV, outputURL: outputURL, author: author, title: title, genre: genre, description: description, series: series, seriesNumber: seriesNumber, quality: quality, chapterDurationMinutes: chapterDurationMinutes, coverImageData: coverImageData, logHandler: logHandler, completion: completion)
            } else {
                logHandler("Используем обычный режим экспорта")
                exportWAVToM4A(combinedWAV, outputURL: outputURL, author: author, title: title, genre: genre, description: description, series: series, seriesNumber: seriesNumber, quality: quality, coverImageData: coverImageData, logHandler: logHandler, completion: completion)
            }

            // Очищаем временные файлы
            logHandler("Очищаем временные файлы...")
            try? FileManager.default.removeItem(at: tempDir)
            logHandler("✅ Временные файлы очищены")

        } catch {
            print("ERROR in Task: \(error)")
            logHandler("❌ КРИТИЧЕСКАЯ ОШИБКА: \(error.localizedDescription)")
            logHandler("Подробности: \(error)")
            completion(.failure(error))
        }
    }
    print("Task creation completed")
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

        // Создаем временный WAV файл для обработки с главами
        let tempWAVURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_chapter_audio.wav")

        // Экспортируем композицию во временный WAV
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            let error = NSError(domain: "AudioConverter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать сессию экспорта для глав"])
            completion(.failure(error))
            return
        }

        exportSession.outputURL = tempWAVURL
        exportSession.outputFileType = .wav

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    // Теперь обрабатываем WAV с главами
                    exportWAVWithChapters(
                        tempWAVURL,
                        outputURL: outputURL,
                        author: author,
                        title: title,
                        genre: genre,
                        description: description,
                        series: series,
                        seriesNumber: seriesNumber,
                        quality: quality,
                        chapterDurationMinutes: chapterDurationMinutes,
                        coverImageData: coverImageData,
                        logHandler: { message in print(message) },
                        completion: { result in
                            // Очищаем временный файл
                            try? FileManager.default.removeItem(at: tempWAVURL)
                            completion(result)
                        }
                    )
                case .failed:
                    if let error = exportSession.error {
                        completion(.failure(error))
                    } else {
                        let error = NSError(domain: "AudioConverter", code: -4, userInfo: [NSLocalizedDescriptionKey: "Неизвестная ошибка экспорта"])
                        completion(.failure(error))
                    }
                case .cancelled:
                    let error = NSError(domain: "AudioConverter", code: -5, userInfo: [NSLocalizedDescriptionKey: "Экспорт отменен"])
                    completion(.failure(error))
                default:
                    break
                }
            }
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
            presetName = AVAssetExportPresetAppleM4A // Используем M4A пресет для аудио
        default:
            presetName = AVAssetExportPresetAppleM4A // По умолчанию используем M4A для аудио
        }

        print("Выбранный пресет: \(presetName)")

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

        // Устанавливаем жанр как аудиокнига, если не указан другой жанр
        let genreItem = AVMutableMetadataItem()
        genreItem.key = "genre" as NSString
        genreItem.keySpace = AVMetadataKeySpace.common
        genreItem.value = (!genre.isEmpty ? genre : "Audiobook") as NSString
        metadata.append(genreItem)

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

    private static func convertToWAV(inputURL: URL, outputURL: URL, logHandler: @escaping (String) -> Void) async throws {
        logHandler("  Начинаем конвертацию в WAV...")

        // Пробуем использовать AVAudioFile для более надежной конвертации
        do {
            let sourceFile = try AVAudioFile(forReading: inputURL)
            logHandler("  ✅ Успешно открыли файл через AVAudioFile")

            // Создаем формат для WAV
            let outputFormat = AVAudioFormat(standardFormatWithSampleRate: sourceFile.processingFormat.sampleRate, channels: sourceFile.processingFormat.channelCount)!

            let destinationFile = try AVAudioFile(forWriting: outputURL, settings: outputFormat.settings)
            logHandler("  ✅ Создали выходной WAV файл")

            // Читаем и записываем данные
            let buffer = AVAudioPCMBuffer(pcmFormat: sourceFile.processingFormat, frameCapacity: 1024)!
            var totalFrames: AVAudioFrameCount = 0

            while sourceFile.framePosition < sourceFile.length {
                try sourceFile.read(into: buffer)
                try destinationFile.write(from: buffer)
                totalFrames += buffer.frameLength
            }

            logHandler("  ✅ Конвертация в WAV завершена успешно через AVAudioFile (\(totalFrames) фреймов)")

        } catch {
            logHandler("  ⚠️ AVAudioFile не сработал (\(error.localizedDescription)), пробуем AVAssetExportSession...")

            // Fallback to AVAssetExportSession
            let asset = AVAsset(url: inputURL)

            guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
                let error = NSError(domain: "AudioConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать сессию экспорта для WAV"])
                logHandler("  ОШИБКА: \(error.localizedDescription)")
                throw error
            }

            session.outputURL = outputURL
            session.outputFileType = .wav
            logHandler("  Настроена сессия экспорта WAV через AVAsset")

            await withCheckedContinuation { continuation in
                session.exportAsynchronously {
                    continuation.resume()
                }
            }

            logHandler("  Статус экспорта WAV: \(session.status.rawValue)")

            switch session.status {
            case .completed:
                logHandler("  ✅ Конвертация в WAV завершена успешно через AVAsset")
            case .failed:
                if let error = session.error {
                    logHandler("  ❌ ОШИБКА экспорта WAV: \(error.localizedDescription)")
                    throw error
                } else {
                    let error = NSError(domain: "AudioConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось конвертировать в WAV"])
                    logHandler("  ❌ НЕИЗВЕСТНАЯ ОШИБКА экспорта WAV")
                    throw error
                }
            case .cancelled:
                let error = NSError(domain: "AudioConverter", code: -5, userInfo: [NSLocalizedDescriptionKey: "Конвертация в WAV отменена"])
                logHandler("  ❌ Конвертация в WAV отменена")
                throw error
            default:
                let error = NSError(domain: "AudioConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неизвестный статус экспорта WAV"])
                logHandler("  ⚠️ НЕИЗВЕСТНЫЙ СТАТУС экспорта WAV")
                throw error
            }
        }
    }

    private static func combineWAVFiles(inputURLs: [URL], outputURL: URL, logHandler: @escaping (String) -> Void) async throws {
        logHandler("  Создаем композицию из \(inputURLs.count) WAV файлов")

        let composition = AVMutableComposition()
        guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            let error = NSError(domain: "AudioConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать аудио трек для композиции"])
            logHandler("  ОШИБКА: \(error.localizedDescription)")
            throw error
        }

        var currentTime = CMTime.zero
        var totalDuration: TimeInterval = 0

        for (index, inputURL) in inputURLs.enumerated() {
            logHandler("  Добавляем файл [\(index + 1)]: \(inputURL.lastPathComponent)")

            let asset = AVAsset(url: inputURL)
            print("About to call asset.loadTracks(withMediaType: .audio)...")

            let audioTracks: [AVAssetTrack]
            do {
                audioTracks = try await asset.loadTracks(withMediaType: .audio)
                print("asset.loadTracks completed successfully, count: \(audioTracks.count)")
            } catch {
                print("ERROR in asset.loadTracks: \(error.localizedDescription)")
                print("Error details: \(error)")
                logHandler("❌ ОШИБКА загрузки аудио треков: \(error.localizedDescription)")
                throw error
            }

            guard let audioAssetTrack = audioTracks.first else {
                logHandler("  ⚠️ Пропускаем файл - не найден аудио трек")
                continue
            }

            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            totalDuration += durationSeconds

            let timeRange = CMTimeRange(start: .zero, duration: duration)
            logHandler("  Вставляем диапазон: \(durationSeconds) секунд на позицию \(CMTimeGetSeconds(currentTime))")

            try audioTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: currentTime)
            currentTime = CMTimeAdd(currentTime, timeRange.duration)

            logHandler("  ✅ Файл [\(index + 1)] добавлен в композицию")
        }

        logHandler("  Общая длительность композиции: \(totalDuration) секунд")

        // Экспортируем объединенный файл
        logHandler("  Экспортируем объединенный WAV файл...")
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            let error = NSError(domain: "AudioConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать сессию экспорта для объединения"])
            logHandler("  ОШИБКА: \(error.localizedDescription)")
            throw error
        }

        session.outputURL = outputURL
        session.outputFileType = .wav

        await withCheckedContinuation { continuation in
            session.exportAsynchronously {
                continuation.resume()
            }
        }

        logHandler("  Статус экспорта объединения: \(session.status.rawValue)")

        switch session.status {
        case .completed:
            logHandler("  ✅ Объединение WAV файлов завершено успешно")
        case .failed:
            if let error = session.error {
                logHandler("  ❌ ОШИБКА объединения: \(error.localizedDescription)")
                throw error
            } else {
                let error = NSError(domain: "AudioConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось объединить WAV файлы"])
                logHandler("  ❌ НЕИЗВЕСТНАЯ ОШИБКА объединения")
                throw error
            }
        case .cancelled:
            let error = NSError(domain: "AudioConverter", code: -5, userInfo: [NSLocalizedDescriptionKey: "Объединение WAV файлов отменено"])
            logHandler("  ❌ Объединение отменено")
            throw error
        default:
            let error = NSError(domain: "AudioConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неизвестный статус объединения WAV файлов"])
            logHandler("  ⚠️ НЕИЗВЕСТНЫЙ СТАТУС объединения")
            throw error
        }
    }

    private static func exportWAVToM4A(
        _ wavURL: URL,
        outputURL: URL,
        author: String,
        title: String,
        genre: String,
        description: String,
        series: String,
        seriesNumber: String,
        quality: String,
        coverImageData: Data?,
        logHandler: @escaping (String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        logHandler("=== НАЧАЛО ЭКСПОРТА В M4A ===")
        logHandler("Входной файл: \(wavURL.path)")
        logHandler("Выходной файл: \(outputURL.path)")

        let asset = AVAsset(url: wavURL)
        logHandler("Создан AVAsset для экспорта")

        // Выбор пресета на основе качества
        let presetName: String
        switch quality.lowercased() {
        case "low":
            presetName = AVAssetExportPresetLowQuality
        case "medium":
            presetName = AVAssetExportPresetMediumQuality
        case "high":
            presetName = AVAssetExportPresetAppleM4A
        default:
            presetName = AVAssetExportPresetAppleM4A
        }

        logHandler("Выбран пресет: \(presetName)")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: presetName) else {
            let error = NSError(domain: "AudioConverter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать сессию экспорта"])
            logHandler("❌ ОШИБКА: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        logHandler("Настроены параметры экспорта")

        // Добавление метаданных
        var metadata = [AVMutableMetadataItem]()
        logHandler("Добавляем метаданные...")

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

        // Устанавливаем жанр как аудиокнига, если не указан другой жанр
        let genreItem = AVMutableMetadataItem()
        genreItem.key = "genre" as NSString
        genreItem.keySpace = AVMetadataKeySpace.common
        genreItem.value = (!genre.isEmpty ? genre : "Audiobook") as NSString
        metadata.append(genreItem)

        if !description.isEmpty {
            let descriptionItem = AVMutableMetadataItem()
            descriptionItem.key = AVMetadataKey.commonKeyDescription as NSString
            descriptionItem.keySpace = AVMetadataKeySpace.common
            descriptionItem.value = description as NSString
            metadata.append(descriptionItem)
        }

        if let imageData = coverImageData {
            let artworkItem = AVMutableMetadataItem()
            artworkItem.key = AVMetadataKey.commonKeyArtwork as NSString
            artworkItem.keySpace = AVMetadataKeySpace.common
            artworkItem.value = imageData as NSData
            metadata.append(artworkItem)
            logHandler("Добавлена обложка")
        }

        // Добавляем дополнительные метаданные для аудиокниг
        let contentTypeItem = AVMutableMetadataItem()
        contentTypeItem.key = AVMetadataKey.commonKeyType as NSString
        contentTypeItem.keySpace = AVMetadataKeySpace.common
        contentTypeItem.value = "Audiobook" as NSString
        metadata.append(contentTypeItem)

        let mediaTypeItem = AVMutableMetadataItem()
        mediaTypeItem.key = "stik" as NSString
        mediaTypeItem.keySpace = AVMetadataKeySpace.iTunes
        mediaTypeItem.value = NSNumber(value: 2) // 2 = Audiobook
        metadata.append(mediaTypeItem)

        exportSession.metadata = metadata
        logHandler("Метаданные настроены (\(metadata.count) элементов) - тип: Аудиокнига")

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                logHandler("=== РЕЗУЛЬТАТ ЭКСПОРТА ===")
                logHandler("Статус экспорта: \(exportSession.status.rawValue)")

                switch exportSession.status {
                case .completed:
                    logHandler("✅ ЭКСПОРТ В M4A ЗАВЕРШЕН УСПЕШНО")
                    completion(.success(()))
                case .failed:
                    if let error = exportSession.error {
                        logHandler("❌ ОШИБКА ЭКСПОРТА: \(error.localizedDescription)")
                        logHandler("Подробности ошибки: \(error)")
                        completion(.failure(error))
                    } else {
                        let error = NSError(domain: "AudioConverter", code: -4, userInfo: [NSLocalizedDescriptionKey: "Неизвестная ошибка экспорта"])
                        logHandler("❌ НЕИЗВЕСТНАЯ ОШИБКА ЭКСПОРТА")
                        completion(.failure(error))
                    }
                case .cancelled:
                    let error = NSError(domain: "AudioConverter", code: -5, userInfo: [NSLocalizedDescriptionKey: "Экспорт отменен"])
                    logHandler("❌ ЭКСПОРТ ОТМЕНЕН")
                    completion(.failure(error))
                default:
                    logHandler("⚠️ НЕИЗВЕСТНЫЙ СТАТУС ЭКСПОРТА")
                    break
                }
                logHandler("========================")
            }
        }
    }

    private static func exportWAVWithChapters(
        _ wavURL: URL,
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
        logHandler: @escaping (String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        logHandler("=== ЭКСПОРТ С ГЛАВАМИ ===")
        logHandler("Длительность главы: \(chapterDurationMinutes) минут")

        Task {
            do {
                let asset = AVAsset(url: wavURL)
                let duration = try await asset.load(.duration)
                let totalDurationSeconds = CMTimeGetSeconds(duration)

                logHandler("Общая длительность аудио: \(totalDurationSeconds) секунд")

                // Рассчитываем количество глав
                let chapterDurationSeconds = Double(chapterDurationMinutes * 60)
                let numberOfChapters = Int(ceil(totalDurationSeconds / chapterDurationSeconds))

                logHandler("Будет создано \(numberOfChapters) глав")

                // Создаем композицию с главами
                let composition = AVMutableComposition()
                guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    let error = NSError(domain: "AudioConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать аудио трек для глав"])
                    logHandler("❌ ОШИБКА: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                // Разделяем аудио на главы
                var currentTime = CMTime.zero
                var chapterTitles: [String] = []

                for chapterIndex in 0..<numberOfChapters {
                    let chapterStartTime = Double(chapterIndex) * chapterDurationSeconds
                    let chapterEndTime = min(chapterStartTime + chapterDurationSeconds, totalDurationSeconds)

                    let startCMTime = CMTime(seconds: chapterStartTime, preferredTimescale: 600)
                    let durationCMTime = CMTime(seconds: chapterEndTime - chapterStartTime, preferredTimescale: 600)

                    let timeRange = CMTimeRange(start: startCMTime, duration: durationCMTime)

                    // Загружаем аудио треки
                    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                    guard let audioAssetTrack = audioTracks.first else {
                        let error = NSError(domain: "AudioConverter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Не найден аудио трек"])
                        logHandler("❌ ОШИБКА: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }

                    try audioTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: currentTime)
                    currentTime = CMTimeAdd(currentTime, durationCMTime)

                    // Создаем название главы
                    let chapterTitle = String(format: "Глава %d", chapterIndex + 1)
                    chapterTitles.append(chapterTitle)

                    logHandler("✅ Добавлена \(chapterTitle) (\(chapterEndTime - chapterStartTime) сек)")
                }

                // Экспортируем с метаданными глав
                logHandler("Экспортируем аудиокнигу с главами...")
                exportCompositionWithChapterMetadata(
                    composition,
                    outputURL: outputURL,
                    author: author,
                    title: title,
                    genre: genre,
                    description: description,
                    series: series,
                    seriesNumber: seriesNumber,
                    quality: quality,
                    chapterTitles: chapterTitles,
                    chapterDurationSeconds: chapterDurationSeconds,
                    coverImageData: coverImageData,
                    logHandler: logHandler,
                    completion: completion
                )

            } catch {
                logHandler("❌ ОШИБКА при создании глав: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    private static func exportCompositionWithChapterMetadata(
        _ composition: AVMutableComposition,
        outputURL: URL,
        author: String,
        title: String,
        genre: String,
        description: String,
        series: String,
        seriesNumber: String,
        quality: String,
        chapterTitles: [String],
        chapterDurationSeconds: Double,
        coverImageData: Data?,
        logHandler: @escaping (String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        logHandler("=== ЭКСПОРТ С МЕТАДАННЫМИ ГЛАВ ===")

        // Выбор пресета на основе качества
        let presetName: String
        switch quality.lowercased() {
        case "low":
            presetName = AVAssetExportPresetLowQuality
        case "medium":
            presetName = AVAssetExportPresetMediumQuality
        case "high":
            presetName = AVAssetExportPresetAppleM4A
        default:
            presetName = AVAssetExportPresetAppleM4A
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: presetName) else {
            let error = NSError(domain: "AudioConverter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать сессию экспорта"])
            logHandler("❌ ОШИБКА: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Добавление метаданных
        var metadata = [AVMutableMetadataItem]()
        logHandler("Добавляем метаданные...")

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

        // Устанавливаем жанр как аудиокнига
        let genreItem = AVMutableMetadataItem()
        genreItem.key = "genre" as NSString
        genreItem.keySpace = AVMetadataKeySpace.common
        genreItem.value = (!genre.isEmpty ? genre : "Audiobook") as NSString
        metadata.append(genreItem)

        if !description.isEmpty {
            let descriptionItem = AVMutableMetadataItem()
            descriptionItem.key = AVMetadataKey.commonKeyDescription as NSString
            descriptionItem.keySpace = AVMetadataKeySpace.common
            descriptionItem.value = description as NSString
            metadata.append(descriptionItem)
        }

        // Добавляем метаданные глав
        logHandler("Добавляем метаданные глав (\(chapterTitles.count) глав)...")
        for (index, chapterTitle) in chapterTitles.enumerated() {
            let chapterItem = AVMutableMetadataItem()
            chapterItem.key = "----:com.apple.iTunes:CHAPTER\(String(format: "%03d", index + 1))" as NSString
            chapterItem.keySpace = AVMetadataKeySpace.quickTimeMetadata
            chapterItem.value = chapterTitle as NSString
            metadata.append(chapterItem)

            // Время начала главы в миллисекундах
            let chapterStartTime = Int64(Double(index) * chapterDurationSeconds * 1000)
            let timeItem = AVMutableMetadataItem()
            timeItem.key = "----:com.apple.iTunes:CHAPTER\(String(format: "%03d", index + 1)):START" as NSString
            timeItem.keySpace = AVMetadataKeySpace.quickTimeMetadata
            timeItem.value = NSNumber(value: chapterStartTime)
            metadata.append(timeItem)
        }

        // Добавляем метки типа аудиокнига
        let contentTypeItem = AVMutableMetadataItem()
        contentTypeItem.key = AVMetadataKey.commonKeyType as NSString
        contentTypeItem.keySpace = AVMetadataKeySpace.common
        contentTypeItem.value = "Audiobook" as NSString
        metadata.append(contentTypeItem)

        let mediaTypeItem = AVMutableMetadataItem()
        mediaTypeItem.key = "stik" as NSString
        mediaTypeItem.keySpace = AVMetadataKeySpace.iTunes
        mediaTypeItem.value = NSNumber(value: 2) // 2 = Audiobook
        metadata.append(mediaTypeItem)

        if let imageData = coverImageData {
            let artworkItem = AVMutableMetadataItem()
            artworkItem.key = AVMetadataKey.commonKeyArtwork as NSString
            artworkItem.keySpace = AVMetadataKeySpace.common
            artworkItem.value = imageData as NSData
            metadata.append(artworkItem)
            logHandler("Добавлена обложка")
        }

        exportSession.metadata = metadata
        logHandler("Метаданные настроены (\(metadata.count) элементов) - тип: Аудиокнига с главами")

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                logHandler("=== РЕЗУЛЬТАТ ЭКСПОРТА ГЛАВ ===")
                logHandler("Статус экспорта: \(exportSession.status.rawValue)")

                switch exportSession.status {
                case .completed:
                    logHandler("✅ ЭКСПОРТ С ГЛАВАМИ ЗАВЕРШЕН УСПЕШНО")
                    completion(.success(()))
                case .failed:
                    if let error = exportSession.error {
                        logHandler("❌ ОШИБКА ЭКСПОРТА: \(error.localizedDescription)")
                        logHandler("Подробности ошибки: \(error)")
                        completion(.failure(error))
                    } else {
                        let error = NSError(domain: "AudioConverter", code: -4, userInfo: [NSLocalizedDescriptionKey: "Неизвестная ошибка экспорта"])
                        logHandler("❌ НЕИЗВЕСТНАЯ ОШИБКА ЭКСПОРТА")
                        completion(.failure(error))
                    }
                case .cancelled:
                    let error = NSError(domain: "AudioConverter", code: -5, userInfo: [NSLocalizedDescriptionKey: "Экспорт отменен"])
                    logHandler("❌ ЭКСПОРТ ОТМЕНЕН")
                    completion(.failure(error))
                default:
                    logHandler("⚠️ НЕИЗВЕСТНЫЙ СТАТУС ЭКСПОРТА")
                    break
                }
                logHandler("========================")
            }
        }
    }
}