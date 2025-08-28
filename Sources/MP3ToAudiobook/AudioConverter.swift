import Foundation
import AVFoundation
import AppKit

class AudioConverter {
    static func convertMP3ToM4B(
        inputURLs: [URL],
        outputURL: URL,
        author: String,
        title: String,
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

                    // Загружаем треки асинхронно
                    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                    logHandler("  Найдено аудио треков: \(audioTracks.count)")

                    guard let audioAssetTrack = audioTracks.first else {
                        let errorMsg = "Не найден аудио трек в файле \(inputURL.lastPathComponent)"
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
                exportComposition(composition, outputURL: outputURL, author: author, title: title, coverImageData: coverImageData, completion: completion)

            } catch {
                logHandler("  ОШИБКА обработки файла: \(error.localizedDescription)")
                logHandler("  Подробности: \(error)")
                completion(.failure(error))
            }
        }
    }

    private static func exportComposition(
        _ composition: AVMutableComposition,
        outputURL: URL,
        author: String,
        title: String,
        coverImageData: Data?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        print("=== НАЧАЛО ЭКСПОРТА ===")
        print("Выходной файл: \(outputURL.path)")
        print("Автор: \(author)")
        print("Название: \(title)")
        print("Обложка: \(coverImageData != nil ? "есть" : "нет")")

        // Создание экспорта
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
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