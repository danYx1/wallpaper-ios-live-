import SwiftUI
import PhotosUI
import AVFoundation

struct LivePhotoCreatorView: View {
    @StateObject private var library = PhotoLibraryService()
    @State private var pickerItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "livephoto")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .padding(.top, 40)

                Text("Выберите короткое видео (2–5 секунд). Оно станет живым обоем: неподвижный кадр + анимация по долгому нажатию, как у камеры iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                PhotosPicker(selection: $pickerItem, matching: .videos) {
                    Label("Выбрать видео", systemImage: "video.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
                .disabled(isProcessing)

                if isProcessing {
                    ProgressView("Собираем Live Photo…")
                }

                if let resultMessage {
                    Label(resultMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding(.horizontal, 32)
                }

                Spacer()
            }
            .navigationTitle("Создать")
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task { await process(newItem) }
            }
        }
    }

    private func process(_ item: PhotosPickerItem) async {
        isProcessing = true
        resultMessage = nil
        errorMessage = nil
        defer { isProcessing = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw LivePhotoMaker.MakerError.noFrame
            }
            let tempVideoURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try data.write(to: tempVideoURL)

            let pair = try await LivePhotoMaker.make(sourceVideoURL: tempVideoURL, stillTime: .zero)
            try await library.saveLivePhoto(imageURL: pair.imageURL, videoURL: pair.videoURL)

            resultMessage = "Готово! Смотрите на вкладке «Библиотека»."
        } catch {
            errorMessage = "Не получилось: \(error.localizedDescription)"
        }
    }
}
