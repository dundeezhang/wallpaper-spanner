import AppKit
import SwiftUI

@MainActor
final class AppController: NSObject, ObservableObject, NSApplicationDelegate, NSWindowDelegate {
    private enum WindowChrome {
        static let trafficLightLeadingInset: CGFloat = 20
        static let trafficLightTopInset: CGFloat = 16
        static let trafficLightSpacing: CGFloat = 6
    }

    private weak var mainWindow: NSWindow?
    private var statusItem: NSStatusItem?

    private var isMainWindowPresented: Bool {
        guard let mainWindow else {
            return false
        }

        return mainWindow.isVisible && !mainWindow.isMiniaturized
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.split.3x1",
                accessibilityDescription: "Wallpaper Spanner"
            )
            button.image?.isTemplate = true
            button.toolTip = "Wallpaper Spanner"
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "Show Wallpaper Spanner",
            action: #selector(showMainWindowFromStatusItem),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Wallpaper Spanner",
            action: #selector(quitFromStatusItem),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !isMainWindowPresented {
            showMainWindow()
        }

        return true
    }

    func registerMainWindow(_ window: NSWindow) {
        guard mainWindow !== window else {
            return
        }

        mainWindow = window
        window.isReleasedWhenClosed = false
        window.styleMask.insert(.fullSizeContentView)
        window.isOpaque = false
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96)
        window.delegate = self
        window.toolbarStyle = .automatic
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.toolbar?.showsBaselineSeparator = false
        positionTrafficLights(in: window)
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else {
                return
            }

            self.positionTrafficLights(in: window)
        }
        updateActivationPolicy(showInDock: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === mainWindow else {
            return true
        }

        sender.orderOut(nil)
        updateActivationPolicy(showInDock: false)
        return false
    }

    func showMainWindow() {
        guard let mainWindow else {
            return
        }

        updateActivationPolicy(showInDock: true)

        if mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
        }

        mainWindow.makeKeyAndOrderFront(nil)
        mainWindow.orderFrontRegardless()
        positionTrafficLights(in: mainWindow)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === mainWindow else {
            return
        }

        positionTrafficLights(in: window)
    }

    @objc private func showMainWindowFromStatusItem() {
        showMainWindow()
    }

    @objc private func quitFromStatusItem() {
        NSApp.terminate(nil)
    }

    private func updateActivationPolicy(showInDock: Bool) {
        let desiredPolicy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory

        guard NSApp.activationPolicy() != desiredPolicy else {
            return
        }

        NSApp.setActivationPolicy(desiredPolicy)
    }

    private func positionTrafficLights(in window: NSWindow) {
        guard
            let closeButton = window.standardWindowButton(.closeButton),
            let minimizeButton = window.standardWindowButton(.miniaturizeButton),
            let zoomButton = window.standardWindowButton(.zoomButton),
            let containerView = closeButton.superview
        else {
            return
        }

        containerView.layoutSubtreeIfNeeded()

        let buttons = [closeButton, minimizeButton, zoomButton]
        let buttonSize = closeButton.frame.size
        let originY = containerView.bounds.height - buttonSize.height - WindowChrome.trafficLightTopInset

        var originX = WindowChrome.trafficLightLeadingInset
        for button in buttons {
            button.setFrameOrigin(NSPoint(x: originX, y: originY))
            originX += buttonSize.width + WindowChrome.trafficLightSpacing
        }
    }
}
