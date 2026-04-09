import AVFoundation
import AppKit
import Foundation
import ImageIO

enum MediaLoader {
    static func load(from url: URL, displayName: String? = nil) throws -> MediaAsset {
        switch try MediaKind.detect(url: url) {
        case .image:
            try loadImage(from: url, displayName: displayName)
        case .video:
            try loadVideo(from: url, displayName: displayName)
        }
    }

    private static func loadImage(from url: URL, displayName: String?) throws -> MediaAsset {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw MediaLoadError.failedToDecodeImage
        }

        let previewImage = NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )

        return MediaAsset(
            url: url,
            displayName: displayName,
            kind: .image,
            previewImage: previewImage,
            sourceImage: cgImage,
            contentSize: CGSize(width: cgImage.width, height: cgImage.height)
        )
    }

    private static func loadVideo(from url: URL, displayName: String?) throws -> MediaAsset {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 2400, height: 2400)

        let times = [
            CMTime(seconds: 0.0, preferredTimescale: 600),
            CMTime(seconds: 1.0, preferredTimescale: 600),
            CMTime(seconds: 2.0, preferredTimescale: 600),
        ]

        var frame: CGImage?
        for time in times {
            frame = try? generator.copyCGImage(at: time, actualTime: nil)
            if frame != nil {
                break
            }
        }

        guard let previewFrame = frame else {
            throw MediaLoadError.failedToCaptureVideoFrame
        }

        let previewImage = NSImage(
            cgImage: previewFrame,
            size: NSSize(width: previewFrame.width, height: previewFrame.height)
        )

        return MediaAsset(
            url: url,
            displayName: displayName,
            kind: .video,
            previewImage: previewImage,
            sourceImage: nil,
            contentSize: CGSize(width: previewFrame.width, height: previewFrame.height)
        )
    }
}
