import CoreGraphics
import Foundation
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

@MainActor
@Test
func renderSessionNamesAreUniqueAndNamespaced() {
    let renderer = WallpaperRenderer()

    let first = renderer.debugRenderSessionName()
    let second = renderer.debugRenderSessionName()

    #expect(first.hasPrefix("render-"))
    #expect(second.hasPrefix("render-"))
    #expect(first != second)
}

@Test
func previewDragConvertsCanvasMovementIntoNormalizedOffsets() {
    let delta = DisplayLayoutEngine.normalizedOffsetDelta(
        forPreviewTranslation: CGSize(width: 57.6, height: -10.8),
        previewRect: CGRect(x: 0, y: 0, width: 576, height: 108),
        layoutBounds: CGRect(x: 0, y: 0, width: 5760, height: 1080),
        contentSize: CGSize(width: 3840, height: 2160),
        settings: LayoutSettings(contentMode: .fill, zoom: 1, horizontalOffset: 0, verticalOffset: 0)
    )

    #expect(abs(delta.horizontal - (576.0 / 2592.0)) < 0.0001)
    #expect(abs(delta.vertical - 0.1) < 0.0001)
}

@Test
func clampedOffsetsStayWithinPanBounds() {
    let clamped = DisplayLayoutEngine.clampedOffsets(horizontal: 1.4, vertical: -1.2)

    #expect(clamped.horizontal == 1)
    #expect(clamped.vertical == -1)
}

@Test
func videoWallpaperResetTriggersWhenDisplayIDsChangeButCountMatches() {
    let currentDisplayIDs: [CGDirectDisplayID] = [1, 2, 3]
    let displays = [
        DisplayInfo(id: 1, name: "One", frame: .zero, pixelSize: .zero, scaleX: 1, scaleY: 1),
        DisplayInfo(id: 4, name: "Four", frame: .zero, pixelSize: .zero, scaleX: 1, scaleY: 1),
        DisplayInfo(id: 5, name: "Five", frame: .zero, pixelSize: .zero, scaleX: 1, scaleY: 1),
    ]

    #expect(VideoWallpaperController.needsWindowReset(currentWindowDisplayIDs: currentDisplayIDs, displays: displays))
}

@Test
func videoWallpaperResetSkipsWhenDisplayIDsAreUnchanged() {
    let currentDisplayIDs: [CGDirectDisplayID] = [7, 8]
    let displays = [
        DisplayInfo(id: 8, name: "Eight", frame: .zero, pixelSize: .zero, scaleX: 1, scaleY: 1),
        DisplayInfo(id: 7, name: "Seven", frame: .zero, pixelSize: .zero, scaleX: 1, scaleY: 1),
    ]

    #expect(!VideoWallpaperController.needsWindowReset(currentWindowDisplayIDs: currentDisplayIDs, displays: displays))
}
