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
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        print("=== AUDIOCONVERTER СТАРТ ===")
        print("Входные URL:")
        for (index, url) in inputURLs.enumerated() {
            print("  [\(index)]: \(url.absoluteString)")
            print("    Путь: \(url.path)")
            print("    Схема: \(url.scheme ?? "nil")")
        }
        print("Выходной URL: \(outputURL.absoluteString)")
        print("============================")

        DispatchQueue.global(qos: .background).async {
            let composition = AVMutableComposition()
            guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                let error = NSError(domain: "AudioConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать аудио трек"])
                print("ОШИБКА: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            var currentTime = CMTime.zero
            var processedFiles = 0

            func processNextFile() {
                guard processedFiles < inputURLs.count else {
                    // Все файлы обработаны, начинаем экспорт
                    print("Все файлы обработаны, начинаем экспорт...")
                    // Конвертируем NSImage в Data заранее
                    let coverImageData = coverImage?.tiffRepresentation
                    exportComposition(composition, outputURL: outputURL, author: author, title: title, coverImageData: coverImageData, completion: completion)
                    return
                }

                let inputURL = inputURLs[processedFiles]
                print("Обрабатываем файл [\(processedFiles)]: \(inputURL.lastPathComponent)")
                print("  Полный путь: \(inputURL.path)")

                let asset = AVAsset(url: inputURL)
                print("  Создан AVAsset для файла")

                // Загружаем треки асинхронно
                asset.loadTracks(withMediaType: .audio) { audioTracks, error in
                    if let error = error {
                        print("  ОШИБКА загрузки треков: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }

                    print("  Найдено аудио треков: \(audioTracks?.count ?? 0)")

                    guard let audioAssetTrack = audioTracks?.first else {
                        let errorMsg = "Не найден аудио трек в файле \(inputURL.lastPathComponent)"
                        print("  ОШИБКА: \(errorMsg)")
                        completion(.failure(NSError(domain: "AudioConverter", code: -2, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                        return
                    }

                    print("  Аудио трек найден, загружаем длительность...")

                    // Загружаем свойства асинхронно
                    Task {
                        do {
                            let duration = try await asset.load(.duration)
                            print("  Длительность: \(CMTimeGetSeconds(duration)) секунд")

                            let timeRange = CMTimeRange(start: .zero, duration: duration)
                            print("  Создан timeRange: \(CMTimeGetSeconds(timeRange.duration)) секунд")

                            try audioTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: currentTime)
                            print("  Трек вставлен в композицию")

                            currentTime = CMTimeAdd(currentTime, timeRange.duration)
                            processedFiles += 1

                            await MainActor.run {
                                progressHandler(Double(processedFiles) / Double(inputURLs.count) * 0.5)
                            }

                            print("  Файл [\(processedFiles-1)] обработан успешно")
                            // Обрабатываем следующий файл
                            processNextFile()

                        } catch {
                            print("  ОШИБКА обработки файла: \(error.localizedDescription)")
                            print("  Подробности: \(error)")
                            completion(.failure(error))
                            return
                        }
                    }
                }
            }

            // Начинаем обработку с первого файла
            processNextFile()
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
        // Создание экспорта
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            completion(.failure(NSError(domain: "AudioConverter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать сессию экспорта"])))
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

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
                switch exportSession.status {
                case .completed:
                    completion(.success(()))
                case .failed:
                    if let error = exportSession.error {
                        completion(.failure(error))
                    } else {
                        completion(.failure(NSError(domain: "AudioConverter", code: -4, userInfo: [NSLocalizedDescriptionKey: "Неизвестная ошибка экспорта"])))
                    }
                case .cancelled:
                    completion(.failure(NSError(domain: "AudioConverter", code: -5, userInfo: [NSLocalizedDescriptionKey: "Экспорт отменен"])))
                default:
                    break
                }
            }
        }
    }
}