import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class WallpaperRenderer {
    private let fileManager = FileManager.default
    private let retainSessionCount = 8

    func applyWallpaper(
        media: MediaAsset,
        displays: [DisplayInfo],
        screensByID: [CGDirectDisplayID: NSScreen],
        settings: LayoutSettings
    ) throws {
        guard let sourceImage = media.sourceImage else {
            throw WallpaperError.imageOnly
        }

        let layoutBounds = DisplayLayoutEngine.bounds(for: displays)
        let contentRect = DisplayLayoutEngine.contentRect(
            contentSize: media.contentSize,
            in: layoutBounds,
            settings: settings
        )
        let outputDirectory = try prepareOutputDirectory()

        for display in displays {
            guard let screen = screensByID[display.id] else {
                throw WallpaperError.missingScreen(display.id)
            }

            let slice = try renderSlice(
                from: sourceImage,
                globalContentRect: contentRect,
                for: display
            )
            let fileURL = outputDirectory.appendingPathComponent("display-\(display.id).png")
            try writePNG(slice, to: fileURL)

            let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
                .allowClipping: false,
                .fillColor: NSColor.black,
                .imageScaling: NSNumber(value: NSImageScaling.scaleAxesIndependently.rawValue),
            ]

            try NSWorkspace.shared.setDesktopImageURL(fileURL, for: screen, options: options)
        }

        try? cleanupOldRenderDirectories(parentDirectory: outputDirectory.deletingLastPathComponent())
    }

    func debugRenderSessionName() -> String {
        makeRenderSessionName()
    }

    private func renderSlice(
        from image: CGImage,
        globalContentRect: CGRect,
        for display: DisplayInfo
    ) throws -> CGImage {
        let width = max(Int(display.pixelSize.width.rounded()), 1)
        let height = max(Int(display.pixelSize.height.rounded()), 1)

        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw WallpaperError.failedToRenderSlice
        }

        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high

        let localRect = CGRect(
            x: (globalContentRect.minX - display.frame.minX) * display.scaleX,
            y: (globalContentRect.minY - display.frame.minY) * display.scaleY,
            width: globalContentRect.width * display.scaleX,
            height: globalContentRect.height * display.scaleY
        )
        context.draw(image, in: localRect)

        guard let rendered = context.makeImage() else {
            throw WallpaperError.failedToRenderSlice
        }

        return rendered
    }

    private func prepareOutputDirectory() throws -> URL {
        let baseDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let parentDirectory = baseDirectory
            .appendingPathComponent("WallpaperSpanner", isDirectory: true)
            .appendingPathComponent("RenderedWallpapers", isDirectory: true)
        let directory = parentDirectory
            .appendingPathComponent(makeRenderSessionName(), isDirectory: true)

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
    }

    private func makeRenderSessionName() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        return "render-\(timestamp)-\(UUID().uuidString.lowercased())"
    }

    private func cleanupOldRenderDirectories(parentDirectory: URL) throws {
        let urls = try fileManager.contentsOfDirectory(
            at: parentDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )

        let directories = try urls.filter { url in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            return values.isDirectory == true
        }

        let sorted = try directories.sorted { lhs, rhs in
            let lhsDate = try lhs.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
            let rhsDate = try rhs.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
            return lhsDate > rhsDate
        }

        for url in sorted.dropFirst(retainSessionCount) {
            try? fileManager.removeItem(at: url)
        }
    }

    private func writePNG(_ image: CGImage, to url: URL) throws {
        guard
            let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else {
            throw WallpaperError.failedToWriteImage
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw WallpaperError.failedToWriteImage
        }
    }
}
