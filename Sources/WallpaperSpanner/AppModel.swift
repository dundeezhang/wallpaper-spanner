import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var displays: [DisplayInfo] = []
    @Published var media: MediaAsset?
    @Published var contentMode: ContentMode = .fill {
        didSet { updateLiveWallpaperIfNeeded() }
    }
    @Published var zoom: Double = 1.0 {
        didSet { updateLiveWallpaperIfNeeded() }
    }
    @Published var horizontalOffset: Double = 0.0 {
        didSet { updateLiveWallpaperIfNeeded() }
    }
    @Published var verticalOffset: Double = 0.0 {
        didSet { updateLiveWallpaperIfNeeded() }
    }
    @Published var statusMessage = "Choose an image or a video, line it up, then apply or start the live background."
    @Published var liveWallpaperRunning = false

    private let renderer = WallpaperRenderer()
    private let videoController = VideoWallpaperController()
    private var screensByID: [CGDirectDisplayID: NSScreen] = [:]
    private var screenObserver: NSObjectProtocol?

    init() {
        refreshDisplays()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDisplays()
                self?.updateLiveWallpaperIfNeeded()
            }
        }
    }

    var settings: LayoutSettings {
        LayoutSettings(
            contentMode: contentMode,
            zoom: zoom,
            horizontalOffset: horizontalOffset,
            verticalOffset: verticalOffset
        )
    }

    var canApplyImage: Bool {
        media?.kind == .image && !displays.isEmpty
    }

    var canStartVideo: Bool {
        media?.kind == .video && !displays.isEmpty
    }

    func refreshDisplays() {
        let pairs = NSScreen.screens.compactMap { screen -> (DisplayInfo, NSScreen)? in
            guard let info = DisplayInfo(screen: screen) else {
                return nil
            }

            return (info, screen)
        }

        displays = pairs
            .map(\.0)
            .sorted { lhs, rhs in
                if lhs.frame.minX == rhs.frame.minX {
                    return lhs.frame.minY < rhs.frame.minY
                }

                return lhs.frame.minX < rhs.frame.minX
            }

        screensByID = Dictionary(uniqueKeysWithValues: pairs.map { ($0.0.id, $0.1) })
    }

    func chooseMedia() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            media = try MediaLoader.load(from: url)

            if media?.kind == .image, liveWallpaperRunning {
                stopLiveWallpaper()
            }

            statusMessage = "Loaded \(url.lastPathComponent)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func applyImageWallpaper() {
        guard let media else {
            statusMessage = "Choose an image first."
            return
        }

        do {
            try renderer.applyWallpaper(
                media: media,
                displays: displays,
                screensByID: screensByID,
                settings: settings
            )
            statusMessage = "Applied a spanning wallpaper across \(displays.count) display(s)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func startLiveWallpaper() {
        guard let media, media.kind == .video else {
            statusMessage = "Choose a video first."
            return
        }

        videoController.start(
            url: media.url,
            contentSize: media.contentSize,
            displays: displays,
            screensByID: screensByID,
            settings: settings
        )
        liveWallpaperRunning = videoController.isRunning
        statusMessage = liveWallpaperRunning
            ? "Started the live video wallpaper. It stays active while the app is running."
            : "Could not start the live video wallpaper."
    }

    func stopLiveWallpaper() {
        videoController.stop()
        liveWallpaperRunning = false
        statusMessage = "Stopped the live video wallpaper."
    }

    private func updateLiveWallpaperIfNeeded() {
        guard liveWallpaperRunning, let media, media.kind == .video else {
            return
        }

        videoController.reconfigure(
            contentSize: media.contentSize,
            displays: displays,
            screensByID: screensByID,
            settings: settings
        )
    }
}
