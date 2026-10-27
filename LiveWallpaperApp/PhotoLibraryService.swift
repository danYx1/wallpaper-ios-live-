import Photos
import PhotosUI
import UIKit

/// Обёртка над PhotoKit: находит существующие Live Photo
/// и сохраняет новые (видео + стоп-кадр) в библиотеку.
@MainActor
final class PhotoLibraryService: ObservableObject {
    @Published var livePhotos: [PHAsset] = []
    @Published var authorizationDenied = false

    func requestAccessAndLoad() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            loadLivePhotos()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                Task { @MainActor in
                    if newStatus == .authorized || newStatus == .limited {
                        self?.loadLivePhotos()
                    } else {
                        self?.authorizationDenied = true
                    }
                }
            }
        default:
            authorizationDenied = true
        }
    }

    func loadLivePhotos() {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "(mediaSubtype & %d) != 0", PHAssetMediaSubtype.photoLive.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        livePhotos = assets
    }

    /// Сохраняет пару (видео-мувент + JPEG с нужными метаданными) как Live Photo в "Фото".
    func saveLivePhoto(imageURL: URL, videoURL: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            request.addResource(with: .photo, fileURL: imageURL, options: options)
            request.addResource(with: .pairedVideo, fileURL: videoURL, options: options)
        }
        loadLivePhotos()
    }

    /// Открывает системное приложение "Фото" на нужном ассете —
    /// дальше пользователь сам жмёт "Использовать как обои".
    func openInPhotosApp(asset: PHAsset) {
        guard let url = URL(string: "photos-redirect://") else { return }
        UIApplication.shared.open(url)
    }
}
