import AVFoundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Собирает Live Photo из короткого видео: берёт стоп-кадр,
/// прописывает в оба файла общий assetIdentifier — именно так
/// iOS распознаёт пару "фото + видео" как единое Live Photo.
enum LivePhotoMaker {

    enum MakerError: Error {
        case noFrame
        case exportFailed
    }

    /// - Parameter sourceVideoURL: короткое видео (идеально 2-4 секунды, как снимает камера).
    /// - Parameter stillTime: момент, который станет неподвижным превью.
    static func make(sourceVideoURL: URL, stillTime: CMTime) async throws -> (imageURL: URL, videoURL: URL) {
        let assetIdentifier = UUID().uuidString
        let tempDir = FileManager.default.temporaryDirectory
        let imageURL = tempDir.appendingPathComponent("\(assetIdentifier).jpg")
        let videoURL = tempDir.appendingPathComponent("\(assetIdentifier).mov")

        let stillImage = try await extractFrame(from: sourceVideoURL, at: stillTime)
        try writeJPEG(stillImage, assetIdentifier: assetIdentifier, to: imageURL)
        try await writeTaggedVideo(
            sourceURL: sourceVideoURL,
            destinationURL: videoURL,
            assetIdentifier: assetIdentifier,
            stillTime: stillTime
        )

        return (imageURL, videoURL)
    }

    // MARK: - Стоп-кадр

    private static func extractFrame(from videoURL: URL, at time: CMTime) async throws -> UIImage {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let cgImage = try await generator.image(at: time).image
        return UIImage(cgImage: cgImage)
    }

    private static func writeJPEG(_ image: UIImage, assetIdentifier: String, to url: URL) throws {
        guard let cgImage = image.cgImage,
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw MakerError.exportFailed }

        // Ключ "17" в словаре Apple Maker Note — то место, куда iOS кладёт
        // общий идентификатор для связки фото с видео-партнёром.
        let makerNote: [String: Any] = ["17": assetIdentifier]
        let metadata: [CFString: Any] = [
            kCGImagePropertyMakerAppleDictionary: makerNote
        ]

        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw MakerError.exportFailed }
    }

    // MARK: - Видео с метаданными

    private static func writeTaggedVideo(
        sourceURL: URL,
        destinationURL: URL,
        assetIdentifier: String,
        stillTime: CMTime
    ) async throws {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        let asset = AVURLAsset(url: sourceURL)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw MakerError.exportFailed
        }

        let contentIdentifierItem = AVMutableMetadataItem()
        contentIdentifierItem.key = AVMetadataKey.quickTimeMetadataKeyContentIdentifier as NSString
        contentIdentifierItem.keySpace = AVMetadataKeySpace.quickTimeMetadata
        contentIdentifierItem.value = assetIdentifier as NSString

        let stillImageTimeItem = AVMutableMetadataItem()
        stillImageTimeItem.key = "com.apple.quicktime.still-image-time" as NSString
        stillImageTimeItem.keySpace = AVMetadataKeySpace.quickTimeMetadata
        stillImageTimeItem.value = 0 as NSNumber
        stillImageTimeItem.dataType = kCMMetadataBaseDataType_SInt8 as String

        export.metadata = [contentIdentifierItem, stillImageTimeItem]
        export.outputURL = destinationURL
        export.outputFileType = .mov

        await export.export()

        guard export.status == .completed else { throw MakerError.exportFailed }
    }
}
