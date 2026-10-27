import SwiftUI
import Photos
import PhotosUI

struct LivePhotoDetailView: View {
    let asset: PHAsset
    @ObservedObject var library: PhotoLibraryService
    @Environment(\.dismiss) private var dismiss
    @State private var livePhoto: PHLivePhoto?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let livePhoto {
                    LivePhotoView(livePhoto: livePhoto)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding()
                } else {
                    ProgressView()
                        .frame(height: 300)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Как поставить на блокировку", systemImage: "info.circle")
                        .font(.headline)
                    Text("1. Нажмите «Открыть в Фото»\n2. Найдите этот снимок\n3. Поделиться → Использовать как обои")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Button {
                    library.openInPhotosApp(asset: asset)
                } label: {
                    Label("Открыть в Фото", systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Предпросмотр")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .task {
                let options = PHLivePhotoRequestOptions()
                options.deliveryMode = .highQualityFormat
                PHImageManager.default().requestLivePhoto(
                    for: asset,
                    targetSize: CGSize(width: 600, height: 600),
                    contentMode: .aspectFit,
                    options: options
                ) { result, _ in
                    if let result { livePhoto = result }
                }
            }
        }
    }
}

/// UIKit-обёртка PHLivePhotoView: даёт анимацию при long-press, как в приложении "Фото".
struct LivePhotoView: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.livePhoto = livePhoto
        view.contentMode = .scaleAspectFit
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto
    }
}
