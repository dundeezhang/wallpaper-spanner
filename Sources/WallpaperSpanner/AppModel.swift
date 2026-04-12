import AppKit
import Foundation
import SwiftUI

enum StatusTone: Equatable, Sendable {
    case neutral
    case success
    case error
}

@MainActor
final class AppModel: ObservableObject {
    @Published var displays: [DisplayInfo] = []
    @Published var media: MediaAsset?
    @Published var contentMode: ContentMode = .fill {
        didSet { refreshLiveWallpaperIfNeeded() }
    }
    @Published var zoom: Double = 1.0 {
        didSet { refreshLiveWallpaperIfNeeded() }
    }
    @Published var horizontalOffset: Double = 0.0 {
        didSet { refreshLiveWallpaperIfNeeded() }
    }
    @Published var verticalOffset: Double = 0.0 {
        didSet { refreshLiveWallpaperIfNeeded() }
    }
    @Published var statusMessage = "Choose an image or a video, line it up, then apply or start the live background."
    @Published private(set) var statusTone: StatusTone = .neutral
    @Published private(set) var statusRevision = 0
    @Published var liveWallpaperRunning = false

    private let renderer = WallpaperRenderer()
    private let videoController = VideoWallpaperController()
    private var screensByID: [CGDirectDisplayID: NSScreen] = [:]
    private var screenObserver: NSObjectProtocol?
    private var suppressLiveWallpaperUpdates = false

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

    var hasAdjustedLayout: Bool {
        settings != LayoutSettings()
    }

    var mediaSummary: String {
        guard let media else {
            return "No media selected"
        }

        return "\(media.kind.label) • \(Int(media.contentSize.width)) x \(Int(media.contentSize.height))"
    }

    var primaryActionTitle: String {
        guard let media else {
            return "Import Media"
        }

        switch media.kind {
        case .image:
            return "Apply Image Wallpaper"
        case .video:
            return liveWallpaperRunning ? "Restart Live Video Wallpaper" : "Start Live Video Wallpaper"
        }
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

    func importMedia(from url: URL) {
        loadMedia(from: url, loadedMessage: "Loaded \(url.lastPathComponent).")
    }

    func resetLayout() {
        applyLayoutSettings(LayoutSettings())
    }

    func applyFramingPreset(_ preset: FramingPreset) {
        applyLayoutSettings(settings.applying(preset))
    }

    func nudge(horizontal: Double = 0, vertical: Double = 0, zoom: Double = 0) {
        applyLayoutSettings(
            settings.nudged(horizontal: horizontal, vertical: vertical, zoom: zoom)
        )
    }

    func performPrimaryAction(openImporter: () -> Void) {
        guard let media else {
            openImporter()
            return
        }

        switch media.kind {
        case .image:
            applyImageWallpaper()
        case .video:
            startLiveWallpaper()
        }
    }

    func setStatusMessage(_ message: String, tone: StatusTone = .neutral) {
        updateStatus(message, tone: tone)
    }

    func applyImageWallpaper() {
        guard let media else {
            updateStatus("Choose an image first.", tone: .error)
            return
        }

        do {
            try renderer.applyWallpaper(
                media: media,
                displays: displays,
                screensByID: screensByID,
                settings: settings
            )
            updateStatus("Applied a spanning wallpaper across \(displays.count) display(s).", tone: .success)
        } catch {
            updateStatus(error.localizedDescription, tone: .error)
        }
    }

    func startLiveWallpaper() {
        guard let media, media.kind == .video else {
            updateStatus("Choose a video first.", tone: .error)
            return
        }

        videoController.start(
            url: media.url,
            contentSize: media.contentSize,
            displays: displays,
            settings: settings
        )
        liveWallpaperRunning = videoController.isRunning
        updateStatus(
            liveWallpaperRunning
            ? "Started the live video wallpaper. It stays active while the app is running."
            : "Could not start the live video wallpaper.",
            tone: liveWallpaperRunning ? .success : .error
        )
    }

    func stopLiveWallpaper() {
        stopLiveWallpaper(updateStatusMessage: true)
    }

    private func updateLiveWallpaperIfNeeded() {
        guard liveWallpaperRunning, let media, media.kind == .video else {
            return
        }

        videoController.reconfigure(
            contentSize: media.contentSize,
            displays: displays,
            settings: settings
        )
        liveWallpaperRunning = videoController.isRunning
    }

    private func loadMedia(from url: URL, displayName: String? = nil, loadedMessage: String) {
        do {
            let loadedMedia = try MediaLoader.load(from: url, displayName: displayName)
            applyLoadedMedia(loadedMedia, loadedMessage: loadedMessage)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func applyLoadedMedia(_ loadedMedia: MediaAsset, loadedMessage: String) {
        media = loadedMedia

        if loadedMedia.kind == .image, liveWallpaperRunning {
            stopLiveWallpaper(updateStatusMessage: false)
        }

        statusMessage = loadedMessage
    }

    private func stopLiveWallpaper(updateStatusMessage: Bool) {
        videoController.stop()
        liveWallpaperRunning = false

        if updateStatusMessage {
            updateStatus("Stopped the live video wallpaper.")
        }
    }

    private func applyLayoutSettings(_ newSettings: LayoutSettings) {
        let clampedSettings = newSettings.clamped()
        suppressLiveWallpaperUpdates = true
        contentMode = clampedSettings.contentMode
        zoom = clampedSettings.zoom
        horizontalOffset = clampedSettings.horizontalOffset
        verticalOffset = clampedSettings.verticalOffset
        suppressLiveWallpaperUpdates = false
        updateLiveWallpaperIfNeeded()
    }

    private func refreshLiveWallpaperIfNeeded() {
        guard !suppressLiveWallpaperUpdates else {
            return
        }

        updateLiveWallpaperIfNeeded()
    }

    private func updateStatus(_ message: String, tone: StatusTone = .neutral) {
        statusMessage = message
        statusTone = tone
        statusRevision += 1
    }
}
