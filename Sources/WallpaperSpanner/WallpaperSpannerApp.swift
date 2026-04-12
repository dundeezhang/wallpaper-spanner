import SwiftUI

@main
struct WallpaperSpannerApp: App {
    @NSApplicationDelegateAdaptor(AppController.self) private var appController
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appController)
                .environmentObject(model)
                .frame(minWidth: 1180, minHeight: 760)
        }
        .defaultSize(width: 1280, height: 820)
    }
}
