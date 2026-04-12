import SwiftUI

struct LayoutPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let displays: [DisplayInfo]
    let media: MediaAsset?
    let settings: LayoutSettings
    let onOffsetChange: (Double, Double) -> Void
    let onZoomChange: (Double) -> Void

    @State private var dragStartOffsets: (horizontal: Double, vertical: Double)?
    @State private var magnificationStartZoom: Double?
    @State private var selectedMedia = false
    @State private var resizeStartState: ResizeStartState?

    var body: some View {
        GeometryReader { geometry in
            let canvasRect = CGRect(origin: .zero, size: geometry.size)
            let layoutBounds = DisplayLayoutEngine.bounds(for: displays)
            let previewRect = DisplayLayoutEngine.fitRect(size: layoutBounds.size, in: canvasRect, padding: 0)
            let mediaRect = previewMediaRect(layoutBounds: layoutBounds, previewRect: previewRect)

            ZStack {
                Canvas { context, _ in
                    drawPreview(
                        in: context,
                        canvasRect: canvasRect,
                        layoutBounds: layoutBounds,
                        previewRect: previewRect
                    )
                }

                if let mediaRect, selectedMedia {
                    selectionOverlay(for: mediaRect)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(layoutBounds: layoutBounds, previewRect: previewRect, mediaRect: mediaRect))
            .simultaneousGesture(magnificationGesture())
            .simultaneousGesture(selectionGesture(mediaRect: mediaRect))
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onChange(of: media?.url) { _ in
            selectedMedia = false
            dragStartOffsets = nil
            magnificationStartZoom = nil
            resizeStartState = nil
        }
    }

    private func drawPreview(
        in context: GraphicsContext,
        canvasRect: CGRect,
        layoutBounds: CGRect,
        previewRect: CGRect
    ) {
        guard !displays.isEmpty else {
            context.draw(
                Text("Connect your displays to build the spanning layout.")
                    .font(.headline)
                    .foregroundColor(.secondary),
                at: CGPoint(x: canvasRect.midX, y: canvasRect.midY)
            )
            return
        }

        if let media {
            let contentRect = DisplayLayoutEngine.contentRect(
                contentSize: media.contentSize,
                in: layoutBounds,
                settings: settings
            )
            let previewContentRect = DisplayLayoutEngine.convert(
                rect: contentRect,
                from: layoutBounds,
                into: previewRect
            )

            context.draw(
                Image(nsImage: media.previewImage),
                in: previewContentRect
            )
        }

        for display in displays {
            let displayRect = DisplayLayoutEngine.convert(
                rect: display.frame,
                from: layoutBounds,
                into: previewRect
            )
            let displayPath = Path(
                CGPath(
                    roundedRect: displayRect,
                    cornerWidth: 18,
                    cornerHeight: 18,
                    transform: nil
                )
            )

            let strokeOpacity = media == nil ? emptyStateStrokeOpacity : 0.40
            let fillOpacity = media == nil ? emptyStateFillOpacity : 0.018

            context.stroke(displayPath, with: .color(.white.opacity(strokeOpacity)), lineWidth: 1.5)
            context.fill(displayPath, with: .color(.white.opacity(fillOpacity)))

            if media == nil {
                context.draw(
                    Text(display.name)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(emptyStateLabelOpacity)),
                    at: CGPoint(x: displayRect.midX, y: displayRect.midY)
                )
            }
        }
    }

    private var emptyStateStrokeOpacity: Double {
        colorScheme == .dark ? 0.30 : 0.34
    }

    private var emptyStateFillOpacity: Double {
        colorScheme == .dark ? 0.030 : 0.040
    }

    private var emptyStateLabelOpacity: Double {
        colorScheme == .dark ? 0.68 : 0.60
    }

    private func dragGesture(layoutBounds: CGRect, previewRect: CGRect, mediaRect: CGRect?) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard
                    let media,
                    let mediaRect,
                    mediaRect.contains(value.startLocation)
                else {
                    return
                }

                selectedMedia = true

                if dragStartOffsets == nil {
                    dragStartOffsets = (
                        horizontal: settings.horizontalOffset,
                        vertical: settings.verticalOffset
                    )
                }

                guard let dragStartOffsets else {
                    return
                }

                let delta = DisplayLayoutEngine.normalizedOffsetDelta(
                    forPreviewTranslation: value.translation,
                    previewRect: previewRect,
                    layoutBounds: layoutBounds,
                    contentSize: media.contentSize,
                    settings: settings
                )
                let nextOffsets = DisplayLayoutEngine.clampedOffsets(
                    horizontal: dragStartOffsets.horizontal + delta.horizontal,
                    vertical: dragStartOffsets.vertical + delta.vertical
                )

                onOffsetChange(nextOffsets.horizontal, nextOffsets.vertical)
            }
            .onEnded { _ in
                dragStartOffsets = nil
            }
    }

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard media != nil else {
                    return
                }

                if magnificationStartZoom == nil {
                    magnificationStartZoom = settings.zoom
                }

                guard let magnificationStartZoom else {
                    return
                }

                let nextSettings = LayoutSettings(
                    contentMode: settings.contentMode,
                    zoom: magnificationStartZoom,
                    horizontalOffset: settings.horizontalOffset,
                    verticalOffset: settings.verticalOffset
                )
                .magnified(by: value)

                onZoomChange(nextSettings.zoom)
            }
            .onEnded { _ in
                magnificationStartZoom = nil
            }
    }

    private func selectionGesture(mediaRect: CGRect?) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard let mediaRect else {
                    selectedMedia = false
                    return
                }

                selectedMedia = mediaRect.contains(value.location)
            }
    }

    private func previewMediaRect(layoutBounds: CGRect, previewRect: CGRect) -> CGRect? {
        guard let media else {
            return nil
        }

        let contentRect = DisplayLayoutEngine.contentRect(
            contentSize: media.contentSize,
            in: layoutBounds,
            settings: settings
        )

        return DisplayLayoutEngine.convert(
            rect: contentRect,
            from: layoutBounds,
            into: previewRect
        )
    }

    @ViewBuilder
    private func selectionOverlay(for mediaRect: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.34 : 0.18), lineWidth: 3)
                .frame(width: mediaRect.width, height: mediaRect.height)
                .position(x: mediaRect.midX, y: mediaRect.midY)
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.72 : 0.82), lineWidth: 1.25)
                .frame(width: mediaRect.width, height: mediaRect.height)
                .position(x: mediaRect.midX, y: mediaRect.midY)
                .allowsHitTesting(false)

            ForEach(ResizeHandleCorner.allCases) { corner in
                resizeHandle(for: corner, in: mediaRect)
            }
        }
    }

    private func resizeHandle(for corner: ResizeHandleCorner, in mediaRect: CGRect) -> some View {
        let point = corner.point(in: mediaRect)

        return Circle()
            .fill(Color.white)
            .frame(width: 14, height: 14)
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
            .position(point)
            .gesture(resizeHandleGesture(for: corner, in: mediaRect))
    }

    private func resizeHandleGesture(for corner: ResizeHandleCorner, in mediaRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                selectedMedia = true

                if resizeStartState == nil {
                    resizeStartState = ResizeStartState(
                        zoom: settings.zoom,
                        mediaRect: mediaRect,
                        corner: corner
                    )
                }

                guard let resizeStartState else {
                    return
                }

                let handlePoint = resizeStartState.corner.point(in: resizeStartState.mediaRect)
                let centerPoint = CGPoint(
                    x: resizeStartState.mediaRect.midX,
                    y: resizeStartState.mediaRect.midY
                )
                let scale = DisplayLayoutEngine.scaleForResizeHandle(
                    from: handlePoint,
                    translation: value.translation,
                    around: centerPoint
                )
                let nextZoom = LayoutSettings(
                    contentMode: settings.contentMode,
                    zoom: resizeStartState.zoom,
                    horizontalOffset: settings.horizontalOffset,
                    verticalOffset: settings.verticalOffset
                )
                .magnified(by: scale)
                .zoom

                onZoomChange(nextZoom)
            }
            .onEnded { _ in
                resizeStartState = nil
            }
    }
}

private struct ResizeStartState {
    let zoom: Double
    let mediaRect: CGRect
    let corner: ResizeHandleCorner
}

private enum ResizeHandleCorner: CaseIterable, Identifiable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var id: Self { self }

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeading:
            CGPoint(x: rect.minX, y: rect.minY)
        case .topTrailing:
            CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeading:
            CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomTrailing:
            CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
}
