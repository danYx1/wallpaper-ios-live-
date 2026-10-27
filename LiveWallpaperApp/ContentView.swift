import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LivePhotoGalleryView()
                .tabItem {
                    Label("Библиотека", systemImage: "photo.stack")
                }

            LivePhotoCreatorView()
                .tabItem {
                    Label("Создать", systemImage: "wand.and.stars")
                }
        }
    }
}

#Preview {
    ContentView()
}
