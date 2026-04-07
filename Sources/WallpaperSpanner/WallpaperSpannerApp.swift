import SwiftUI

@main
struct WallpaperSpannerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1180, minHeight: 760)
        }
        .defaultSize(width: 1280, height: 820)
    }
}
