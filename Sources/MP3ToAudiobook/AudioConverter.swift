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
            
            for (index, inputURL) in inputURLs.enumerated() {
                let asset = AVAsset(url: inputURL)
                
                do {
                    let audioAssetTracks = asset.tracks(withMediaType: .audio)
                    guard let audioAssetTrack = audioAssetTracks.first else {
                        completion(.failure(NSError(domain: "AudioConverter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Не найден аудио трек в файле \(inputURL.lastPathComponent)"])))
                        return
                    }

                    let duration = asset.duration
                    let timeRange = CMTimeRange(start: .zero, duration: duration)

                    try audioTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: currentTime)
                    currentTime = CMTimeAdd(currentTime, timeRange.duration)

                    DispatchQueue.main.async {
                        progressHandler(Double(index + 1) / Double(inputURLs.count) * 0.5)
                    }
                } catch {
                    completion(.failure(error))
                    return
                }
            }
            
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
            
            if let coverImage = coverImage, let imageData = coverImage.tiffRepresentation {
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
                        progressHandler(1.0)
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
}