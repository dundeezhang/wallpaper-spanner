import AppKit
import SwiftUI

@MainActor
final class AppController: NSObject, ObservableObject, NSApplicationDelegate, NSWindowDelegate {
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
        window.delegate = self
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
        NSApp.activate(ignoringOtherApps: true)
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
}
