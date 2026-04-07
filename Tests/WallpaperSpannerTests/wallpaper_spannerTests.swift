import CoreGraphics
import Testing
@testable import WallpaperSpanner

@Test
func fillModeScalesToCoverFullLayout() {
    let displays = [
        DisplayInfo(
            id: 1,
            name: "Left",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            pixelSize: CGSize(width: 1920, height: 1080),
            scaleX: 1,
            scaleY: 1
        ),
        DisplayInfo(
            id: 2,
            name: "Center",
            frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
            pixelSize: CGSize(width: 1920, height: 1080),
            scaleX: 1,
            scaleY: 1
        ),
        DisplayInfo(
            id: 3,
            name: "Right",
            frame: CGRect(x: 3840, y: 0, width: 1920, height: 1080),
            pixelSize: CGSize(width: 1920, height: 1080),
            scaleX: 1,
            scaleY: 1
        ),
    ]
    let bounds = DisplayLayoutEngine.bounds(for: displays)
    let rect = DisplayLayoutEngine.contentRect(
        contentSize: CGSize(width: 3840, height: 2160),
        in: bounds,
        settings: LayoutSettings(contentMode: .fill, zoom: 1, horizontalOffset: 0, verticalOffset: 0)
    )

    #expect(rect.width == 5760)
    #expect(rect.height == 3240)
    #expect(rect.midX == bounds.midX)
    #expect(rect.midY == bounds.midY)
}

@Test
func previewConversionMapsBottomLeftCoordinatesIntoCanvasSpace() {
    let layoutBounds = CGRect(x: -1080, y: 0, width: 3000, height: 1200)
    let previewRect = CGRect(x: 100, y: 100, width: 600, height: 240)
    let displayFrame = CGRect(x: -1080, y: 0, width: 1080, height: 1200)

    let converted = DisplayLayoutEngine.convert(
        rect: displayFrame,
        from: layoutBounds,
        into: previewRect
    )

    #expect(converted.minX == 100)
    #expect(converted.width == 216)
    #expect(converted.minY == 100)
    #expect(converted.height == 240)
}
