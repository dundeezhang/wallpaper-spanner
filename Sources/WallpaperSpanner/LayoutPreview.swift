import SwiftUI

struct LayoutPreview: View {
    let displays: [DisplayInfo]
    let media: MediaAsset?
    let settings: LayoutSettings

    var body: some View {
        Canvas { context, size in
            let canvasRect = CGRect(origin: .zero, size: size)
            context.fill(Path(canvasRect), with: .color(Color(nsColor: .underPageBackgroundColor)))

            guard !displays.isEmpty else {
                context.draw(
                    Text("Connect your displays to build the spanning layout.")
                        .font(.headline)
                        .foregroundColor(.secondary),
                    at: CGPoint(x: size.width / 2, y: size.height / 2)
                )
                return
            }

            let layoutBounds = DisplayLayoutEngine.bounds(for: displays)
            let previewRect = DisplayLayoutEngine.fitRect(size: layoutBounds.size, in: canvasRect)
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
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
