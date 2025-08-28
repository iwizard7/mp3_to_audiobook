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
        DispatchQueue.global(qos: .background).async {
            let composition = AVMutableComposition()
            guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                completion(.failure(NSError(domain: "AudioConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать аудио трек"])))
                return
            }

            var currentTime = CMTime.zero
            var processedFiles = 0

            func processNextFile() {
                guard processedFiles < inputURLs.count else {
                    // Все файлы обработаны, начинаем экспорт
                    // Конвертируем NSImage в Data заранее
                    let coverImageData = coverImage?.tiffRepresentation
                    exportComposition(composition, outputURL: outputURL, author: author, title: title, coverImageData: coverImageData, completion: completion)
                    return
                }

                let inputURL = inputURLs[processedFiles]
                let asset = AVAsset(url: inputURL)

                // Загружаем треки асинхронно
                asset.loadTracks(withMediaType: .audio) { audioTracks, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    guard let audioAssetTrack = audioTracks?.first else {
                        completion(.failure(NSError(domain: "AudioConverter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Не найден аудио трек в файле \(inputURL.lastPathComponent)"])))
                        return
                    }

                    // Загружаем свойства асинхронно
                    Task {
                        do {
                            let duration = try await asset.load(.duration)
                            let timeRange = CMTimeRange(start: .zero, duration: duration)

                            try audioTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: currentTime)
                            currentTime = CMTimeAdd(currentTime, timeRange.duration)

                            processedFiles += 1

                            await MainActor.run {
                                progressHandler(Double(processedFiles) / Double(inputURLs.count) * 0.5)
                            }

                            // Обрабатываем следующий файл
                            processNextFile()

                        } catch {
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