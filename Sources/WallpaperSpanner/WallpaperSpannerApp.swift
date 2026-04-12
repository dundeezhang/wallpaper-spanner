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
        .commands {
            CommandMenu("Framing") {
                Button("Center") {
                    model.applyFramingPreset(.center)
                }

                Divider()

                Button("Nudge Left") {
                    model.nudge(horizontal: -0.03)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button("Nudge Right") {
                    model.nudge(horizontal: 0.03)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])

                Button("Nudge Up") {
                    model.nudge(vertical: 0.03)
                }
                .keyboardShortcut(.upArrow, modifiers: [])

                Button("Nudge Down") {
                    model.nudge(vertical: -0.03)
                }
                .keyboardShortcut(.downArrow, modifiers: [])

                Divider()

                Button("Zoom In") {
                    model.nudge(zoom: 0.05)
                }
                .keyboardShortcut("=", modifiers: [])

                Button("Zoom Out") {
                    model.nudge(zoom: -0.05)
                }
                .keyboardShortcut("-", modifiers: [])
            }
        }
    }
}
