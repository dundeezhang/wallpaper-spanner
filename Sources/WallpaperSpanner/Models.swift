import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

enum MediaKind: String {
    case image
    case video

    var label: String {
        rawValue.capitalized
    }

    static func detect(url: URL) throws -> MediaKind {
        let values = try url.resourceValues(forKeys: [.contentTypeKey])

        if let contentType = values.contentType {
            if contentType.conforms(to: .image) {
                return .image
            }

            if contentType.conforms(to: .movie) || contentType.conforms(to: .audiovisualContent) {
                return .video
            }
        }

        throw MediaLoadError.unsupportedType(url.pathExtension)
    }
}

enum ContentMode: String, CaseIterable, Identifiable {
    case fill = "Fill"
    case fit = "Fit"

    var id: String {
        rawValue
    }
}

struct LayoutSettings {
    var contentMode: ContentMode = .fill
    var zoom: Double = 1.0
    var horizontalOffset: Double = 0.0
    var verticalOffset: Double = 0.0
}

struct MediaAsset {
    let url: URL
    let displayName: String?
    let kind: MediaKind
    let previewImage: NSImage
    let sourceImage: CGImage?
    let contentSize: CGSize

    var fileName: String {
        displayName ?? url.lastPathComponent
    }
}

struct DisplayInfo: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let pixelSize: CGSize
    let scaleX: CGFloat
    let scaleY: CGFloat

    var logicalSizeDescription: String {
        "\(Int(frame.width)) x \(Int(frame.height)) pt"
    }

    var pixelSizeDescription: String {
        "\(Int(pixelSize.width)) x \(Int(pixelSize.height)) px"
    }

    init(
        id: CGDirectDisplayID,
        name: String,
        frame: CGRect,
        pixelSize: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.pixelSize = pixelSize
        self.scaleX = scaleX
        self.scaleY = scaleY
    }

    init?(screen: NSScreen) {
        guard
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            return nil
        }

        let displayID = CGDirectDisplayID(truncating: number)
        let frame = screen.frame
        let pixelSize = CGSize(
            width: CGFloat(CGDisplayPixelsWide(displayID)),
            height: CGFloat(CGDisplayPixelsHigh(displayID))
        )

        self.id = displayID
        self.name = screen.localizedName
        self.frame = frame
        self.pixelSize = pixelSize
        self.scaleX = pixelSize.width / max(frame.width, 1)
        self.scaleY = pixelSize.height / max(frame.height, 1)
    }
}

enum MediaLoadError: LocalizedError {
    case unsupportedType(String)
    case failedToDecodeImage
    case failedToCaptureVideoFrame

    var errorDescription: String? {
        switch self {
        case .unsupportedType(let fileExtension):
            return "Unsupported media type: \(fileExtension.isEmpty ? "unknown file" : fileExtension)."
        case .failedToDecodeImage:
            return "Could not decode the selected image."
        case .failedToCaptureVideoFrame:
            return "Could not read a preview frame from the selected video."
        }
    }
}

enum WallpaperError: LocalizedError {
    case imageOnly
    case missingScreen(CGDirectDisplayID)
    case failedToRenderSlice
    case failedToWriteImage

    var errorDescription: String? {
        switch self {
        case .imageOnly:
            return "Only image files can be applied as actual desktop wallpapers."
        case .missingScreen(let displayID):
            return "Display \(displayID) is no longer available."
        case .failedToRenderSlice:
            return "Failed to render a wallpaper slice."
        case .failedToWriteImage:
            return "Failed to write the rendered wallpaper image."
        }
    }
}

struct DisplayLayoutEngine {
    static func bounds(for displays: [DisplayInfo]) -> CGRect {
        displays.reduce(into: CGRect.null) { partial, display in
            partial = partial.union(display.frame)
        }
    }

    static func contentRect(
        contentSize: CGSize,
        in canvas: CGRect,
        settings: LayoutSettings
    ) -> CGRect {
        guard
            contentSize.width > 0,
            contentSize.height > 0,
            !canvas.isNull,
            canvas.width > 0,
            canvas.height > 0
        else {
            return .zero
        }

        let widthScale = canvas.width / contentSize.width
        let heightScale = canvas.height / contentSize.height
        let baseScale: CGFloat = switch settings.contentMode {
        case .fill:
            max(widthScale, heightScale)
        case .fit:
            min(widthScale, heightScale)
        }

        let scale = max(baseScale * CGFloat(settings.zoom), 0.01)
        let scaledSize = CGSize(
            width: contentSize.width * scale,
            height: contentSize.height * scale
        )
        let horizontalTravel = max(abs(scaledSize.width - canvas.width) / 2, canvas.width * 0.45)
        let verticalTravel = max(abs(scaledSize.height - canvas.height) / 2, canvas.height * 0.45)
        let xOffset = CGFloat(settings.horizontalOffset) * horizontalTravel
        let yOffset = CGFloat(settings.verticalOffset) * verticalTravel

        return CGRect(
            x: canvas.midX - (scaledSize.width / 2) + xOffset,
            y: canvas.midY - (scaledSize.height / 2) + yOffset,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }

    static func fitRect(size: CGSize, in container: CGRect, padding: CGFloat = 24) -> CGRect {
        let inset = container.insetBy(dx: padding, dy: padding)

        guard size.width > 0, size.height > 0, inset.width > 0, inset.height > 0 else {
            return .zero
        }

        let scale = min(inset.width / size.width, inset.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)

        return CGRect(
            x: inset.midX - (fitted.width / 2),
            y: inset.midY - (fitted.height / 2),
            width: fitted.width,
            height: fitted.height
        )
    }

    static func convert(
        rect: CGRect,
        from layoutBounds: CGRect,
        into previewRect: CGRect
    ) -> CGRect {
        guard layoutBounds.width > 0, layoutBounds.height > 0 else {
            return .zero
        }

        let scale = min(previewRect.width / layoutBounds.width, previewRect.height / layoutBounds.height)
        let x = previewRect.minX + (rect.minX - layoutBounds.minX) * scale
        let yFromBottom = (rect.minY - layoutBounds.minY) * scale
        let height = rect.height * scale

        return CGRect(
            x: x,
            y: previewRect.maxY - yFromBottom - height,
            width: rect.width * scale,
            height: height
        )
    }
}
