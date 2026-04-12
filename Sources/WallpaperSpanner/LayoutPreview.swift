import SwiftUI

struct LayoutPreview: View {
    let displays: [DisplayInfo]
    let media: MediaAsset?
    let settings: LayoutSettings
    let onOffsetChange: (Double, Double) -> Void

    @State private var dragStartOffsets: (horizontal: Double, vertical: Double)?

    var body: some View {
        GeometryReader { geometry in
            let canvasRect = CGRect(origin: .zero, size: geometry.size)
            let layoutBounds = DisplayLayoutEngine.bounds(for: displays)
            let previewRect = DisplayLayoutEngine.fitRect(size: layoutBounds.size, in: canvasRect)

            Canvas { context, _ in
                drawPreview(
                    in: context,
                    canvasRect: canvasRect,
                    layoutBounds: layoutBounds,
                    previewRect: previewRect
                )
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(layoutBounds: layoutBounds, previewRect: previewRect))
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func drawPreview(
        in context: GraphicsContext,
        canvasRect: CGRect,
        layoutBounds: CGRect,
        previewRect: CGRect
    ) {
        context.fill(Path(canvasRect), with: .color(Color(nsColor: .underPageBackgroundColor)))

        guard !displays.isEmpty else {
            context.draw(
                Text("Connect your displays to build the spanning layout.")
                    .font(.headline)
                    .foregroundColor(.secondary),
                at: CGPoint(x: canvasRect.midX, y: canvasRect.midY)
            )
            return
        }

        let previewPath = Path(
            CGPath(
                roundedRect: previewRect,
                cornerWidth: 24,
                cornerHeight: 24,
                transform: nil
            )
        )

        context.fill(previewPath, with: .color(.black.opacity(0.85)))

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

            context.stroke(displayPath, with: .color(.white.opacity(0.9)), lineWidth: 2)
            context.fill(displayPath, with: .color(.white.opacity(0.06)))
            context.draw(
                Text(display.name)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white),
                at: CGPoint(x: displayRect.midX, y: displayRect.midY)
            )
        }
    }

    private func dragGesture(layoutBounds: CGRect, previewRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard
                    let media,
                    previewRect.contains(value.startLocation)
                else {
                    return
                }

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
}
