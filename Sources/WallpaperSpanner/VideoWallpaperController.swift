import AVFoundation
import AppKit
import QuartzCore

@MainActor
final class VideoWallpaperController {
    private var windows: [DesktopVideoWindow] = []
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    var isRunning: Bool {
        player != nil && !windows.isEmpty
    }

    func start(
        url: URL,
        contentSize: CGSize,
        displays: [DisplayInfo],
        screensByID: [CGDirectDisplayID: NSScreen],
        settings: LayoutSettings
    ) {
        stop()

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        let bounds = DisplayLayoutEngine.bounds(for: displays)
        let contentRect = DisplayLayoutEngine.contentRect(
            contentSize: contentSize,
            in: bounds,
            settings: settings
        )

        let windows = displays.compactMap { display -> DesktopVideoWindow? in
            guard let screen = screensByID[display.id] else {
                return nil
            }

            return DesktopVideoWindow(
                screen: screen,
                display: display,
                player: queuePlayer,
                contentRect: contentRect
            )
        }

        self.windows = windows
        self.player = queuePlayer
        self.looper = looper

        queuePlayer.isMuted = true
        queuePlayer.play()
    }

    func reconfigure(
        contentSize: CGSize,
        displays: [DisplayInfo],
        screensByID: [CGDirectDisplayID: NSScreen],
        settings: LayoutSettings
    ) {
        guard let player else {
            return
        }

        if windows.count != displays.count {
            if let currentURL = player.currentItem?.asset as? AVURLAsset {
                start(
                    url: currentURL.url,
                    contentSize: contentSize,
                    displays: displays,
                    screensByID: screensByID,
                    settings: settings
                )
            }
            return
        }

        let bounds = DisplayLayoutEngine.bounds(for: displays)
        let contentRect = DisplayLayoutEngine.contentRect(
            contentSize: contentSize,
            in: bounds,
            settings: settings
        )
        let displaysByID = Dictionary(uniqueKeysWithValues: displays.map { ($0.id, $0) })

        for window in windows {
            guard
                let display = displaysByID[window.displayID],
                let screen = screensByID[window.displayID]
            else {
                continue
            }

            window.update(screen: screen, display: display, player: player, contentRect: contentRect)
        }
    }

    func stop() {
        player?.pause()
        looper = nil
        player = nil

        for window in windows {
            window.close()
        }

        windows.removeAll()
    }
}

@MainActor
private final class DesktopVideoWindow: NSWindow {
    private(set) var displayID: CGDirectDisplayID = 0
    private let sliceView = VideoSliceView(frame: .zero)

    init(
        screen: NSScreen,
        display: DisplayInfo,
        player: AVPlayer,
        contentRect: CGRect
    ) {
        super.init(
            contentRect: display.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.displayID = display.id

        backgroundColor = .black
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        hasShadow = false
        ignoresMouseEvents = true
        isOpaque = true
        isReleasedWhenClosed = false
        level = .init(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)

        sliceView.autoresizingMask = [.width, .height]
        contentView = sliceView

        update(screen: screen, display: display, player: player, contentRect: contentRect)
        orderFront(nil)
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing bufferingType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: bufferingType,
            defer: flag
        )
    }

    func update(
        screen: NSScreen,
        display: DisplayInfo,
        player: AVPlayer,
        contentRect: CGRect
    ) {
        setFrame(display.frame, display: true)
        setFrameOrigin(display.frame.origin)
        setContentSize(display.frame.size)

        if sliceView.frame.size != display.frame.size {
            sliceView.frame = CGRect(origin: .zero, size: display.frame.size)
        }

        sliceView.configure(
            player: player,
            screenFrame: display.frame,
            contentRect: contentRect
        )
        orderFront(nil)
    }
}

@MainActor
private final class VideoSliceView: NSView {
    private let playerLayer = AVPlayerLayer()
    private var screenFrame: CGRect = .zero
    private var contentRect: CGRect = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updatePlayerFrame()
    }

    func configure(
        player: AVPlayer,
        screenFrame: CGRect,
        contentRect: CGRect
    ) {
        self.screenFrame = screenFrame
        self.contentRect = contentRect

        if playerLayer.superlayer == nil {
            layer?.addSublayer(playerLayer)
        }

        playerLayer.player = player
        playerLayer.videoGravity = .resize
        updatePlayerFrame()
    }

    private func updatePlayerFrame() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        playerLayer.frame = CGRect(
            x: contentRect.minX - screenFrame.minX,
            y: contentRect.minY - screenFrame.minY,
            width: contentRect.width,
            height: contentRect.height
        )

        CATransaction.commit()
    }
}
