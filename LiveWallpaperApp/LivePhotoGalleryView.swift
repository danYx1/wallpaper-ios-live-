import SwiftUI
import Photos

struct LivePhotoGalleryView: View {
    @StateObject private var library = PhotoLibraryService()
    @State private var selectedAsset: PHAsset?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 4)]

    var body: some View {
        NavigationStack {
            Group {
                if library.authorizationDenied {
                    ContentUnavailableView(
                        "Нет доступа к Фото",
                        systemImage: "lock.circle",
                        description: Text("Разрешите доступ в Настройки → Конфиденциальность → Фото")
                    )
                } else if library.livePhotos.isEmpty {
                    ContentUnavailableView(
                        "Живых фото пока нет",
                        systemImage: "photo.stack",
                        description: Text("Создайте первое на вкладке «Создать»")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(library.livePhotos, id: \.localIdentifier) { asset in
                                ThumbnailView(asset: asset)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                                    .onTapGesture { selectedAsset = asset }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Живые обои")
            .onAppear { library.requestAccessAndLoad() }
            .sheet(item: $selectedAsset) { asset in
                LivePhotoDetailView(asset: asset, library: library)
            }
        }
    }
}

/// PHAsset не Identifiable по умолчанию — добавляем через localIdentifier.
extension PHAsset: @retroactive Identifiable {
    public var id: String { localIdentifier }
}

private struct ThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.secondary.opacity(0.15)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            Image(systemName: "livephoto")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(4)
                .background(.black.opacity(0.4), in: Circle())
                .padding(4)
        }
        .task {
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 220, height: 220),
                contentMode: .aspectFill,
                options: options
            ) { result, _ in
                if let result { image = result }
            }
        }
    }
}
