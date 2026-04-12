import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var appController: AppController
    @EnvironmentObject private var model: AppModel
    @State private var showingMediaImporter = false
    @State private var inspectorWidth: CGFloat = 316

    var body: some View {
        HSplitView {
            InspectorColumn(showingMediaImporter: $showingMediaImporter)
                .frame(minWidth: 296, idealWidth: 316, maxWidth: 336, maxHeight: .infinity)

            PreviewWorkspace(showingMediaImporter: $showingMediaImporter)
                .frame(minWidth: 900, maxWidth: .infinity, maxHeight: .infinity)
        }
        .fileImporter(
            isPresented: $showingMediaImporter,
            allowedContentTypes: [.image, .movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    return
                }

                model.importMedia(from: url)
            case .failure(let error):
                model.setStatusMessage(error.localizedDescription, tone: .error)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .topLeading) {
            SidebarTitlebarStrip(width: inspectorWidth + 1)
                .allowsHitTesting(false)
        }
        .onPreferenceChange(SidebarWidthPreferenceKey.self) { width in
            guard width > 0 else {
                return
            }

            inspectorWidth = width
        }
        .overlay(
            WindowAccessor { window in
                appController.registerMainWindow(window)
            }
            .frame(width: 0, height: 0)
        )
    }

    private var primaryActionSymbol: String {
        guard let media = model.media else {
            return "plus"
        }

        switch media.kind {
        case .image:
            return "photo"
        case .video:
            return model.liveWallpaperRunning ? "play.square.stack.fill" : "play.square.fill"
        }
    }
}

private struct SidebarTitlebarStrip: View {
    @Environment(\.colorScheme) private var colorScheme
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .trailing) {
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)

            Color(
                red: colorScheme == .dark ? 0.12 : 0.94,
                green: colorScheme == .dark ? 0.12 : 0.95,
                blue: colorScheme == .dark ? 0.15 : 0.99,
                opacity: colorScheme == .dark ? 0.24 : 0.72
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.03 : 0.18),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.18))
                .frame(width: 1)
        }
        .frame(width: width)
        .frame(height: 52)
    }
}

private struct PreviewWorkspace: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var model: AppModel
    @Binding var showingMediaImporter: Bool
    @State private var activeBanner: StatusBannerState?
    @State private var bannerDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.media?.fileName ?? "Spanning Preview")
                        .font(.largeTitle.weight(.semibold))

                    Text(subtitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 24)

                if model.media != nil {
                    HStack(spacing: 10) {
                        Button {
                            model.performPrimaryAction {
                                showingMediaImporter = true
                            }
                        } label: {
                            Label(model.primaryActionTitle, systemImage: primaryActionSymbol)
                        }
                        .buttonStyle(.borderedProminent)

                        if model.liveWallpaperRunning {
                            Button {
                                model.stopLiveWallpaper()
                            } label: {
                                Label("Stop Video", systemImage: "stop.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                PreviewBadge(symbol: "display.2", text: "\(model.displays.count) Display\(model.displays.count == 1 ? "" : "s")")

                if let media = model.media {
                    PreviewBadge(symbol: media.kind == .image ? "photo" : "film", text: media.kind.label)
                    PreviewBadge(symbol: "rectangle.compress.vertical", text: model.contentMode.rawValue)
                    PreviewBadge(symbol: "plus.magnifyingglass", text: String(format: "%.2fx", model.zoom))
                    PreviewBadge(symbol: "hand.draw", text: "Drag to Position")
                }

                Spacer()
            }

            ZStack(alignment: .topTrailing) {
                GlassSurface(
                    shape: RoundedRectangle(cornerRadius: 32, style: .continuous),
                    material: .underPageBackground,
                    blendingMode: .withinWindow,
                    shadowOpacity: colorScheme == .dark ? 0.10 : 0.04
                )

                LayoutPreview(
                    displays: model.displays,
                    media: model.media,
                    settings: model.settings,
                    onOffsetChange: { horizontalOffset, verticalOffset in
                        model.horizontalOffset = horizontalOffset
                        model.verticalOffset = verticalOffset
                    },
                    onZoomChange: { zoom in
                        model.zoom = zoom
                    }
                )
                .padding(18)
                .blur(radius: model.media == nil ? 4 : 0)
                .overlay {
                    if model.media == nil {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.03 : 0.10))
                            .allowsHitTesting(false)
                    }
                }

                if model.media == nil {
                    EmptyPreviewOverlay {
                        showingMediaImporter = true
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }

                if let activeBanner {
                    PreviewStatusBanner(state: activeBanner)
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: model.media == nil)
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: activeBanner != nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.10 : 0.04), radius: 18, y: 8)

            HStack(spacing: 12) {
                Text(footerHint)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(displaySummary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                GlassSurface(
                    shape: Capsule(style: .continuous),
                    material: .underPageBackground,
                    blendingMode: .withinWindow
                )
            )
        }
        .padding(.top, 68)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            VisualEffectView(material: .windowBackground, blendingMode: .withinWindow)
                .overlay(workspaceTint)
        }
        .onChange(of: model.statusRevision) { _ in
            presentStatusBanner()
        }
        .onDisappear {
            bannerDismissTask?.cancel()
        }
    }

    private var subtitle: String {
        if model.media == nil {
            return "Import one image or video, then frame it directly on the desktop canvas."
        }

        return "\(model.mediaSummary). Compose once, then apply it as a static wallpaper or start the live layer."
    }

    private var footerHint: String {
        if model.media == nil {
            return "Use Import Media or press Command-O to start."
        }

        return "Drag to frame. Click media for resize handles. Pinch or drag a handle to resize."
    }

    private var displaySummary: String {
        guard !model.displays.isEmpty else {
            return "No displays detected"
        }

        return model.displays.map(\.name).joined(separator: " • ")
    }

    private var workspaceTint: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.02 : 0.08),
                .clear,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var primaryActionSymbol: String {
        guard let media = model.media else {
            return "plus"
        }

        switch media.kind {
        case .image:
            return "photo"
        case .video:
            return model.liveWallpaperRunning ? "play.square.stack.fill" : "play.square.fill"
        }
    }

    private func presentStatusBanner() {
        bannerDismissTask?.cancel()

        let next = StatusBannerState(
            revision: model.statusRevision,
            message: model.statusMessage,
            tone: model.statusTone
        )

        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            activeBanner = next
        }

        bannerDismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard activeBanner?.revision == next.revision else {
                    return
                }

                withAnimation(.easeOut(duration: 0.18)) {
                    activeBanner = nil
                }
            }
        }
    }
}

private struct InspectorColumn: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var model: AppModel
    @Binding var showingMediaImporter: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SidebarSectionHeader("Media")

                SidebarPrimaryRow(title: "Import Media", symbol: "plus") {
                    showingMediaImporter = true
                }
                .keyboardShortcut("o", modifiers: [.command])

                if let media = model.media {
                    SidebarInfoBlock(
                        title: media.fileName,
                        subtitle: "\(media.kind.label) • \(Int(media.contentSize.width)) x \(Int(media.contentSize.height))"
                    )
                } else {
                    SidebarNote("No media selected yet.")
                }

                SidebarSecondaryRow(title: "Refresh Displays", symbol: "arrow.clockwise") {
                    model.refreshDisplays()
                }

                SidebarSectionHeader("Framing")

                SidebarControlRow(label: "Preset") {
                    FramingPresetMenu()
                }

                SidebarControlRow(label: "Mode") {
                    FramingModeMenu()
                }

                SidebarSliderRow(
                    label: "Zoom",
                    value: $model.zoom,
                    range: LayoutSettings.zoomRange,
                    format: "%.2f",
                    suffix: "x"
                )

                SidebarSliderRow(
                    label: "Pan X",
                    value: $model.horizontalOffset,
                    range: LayoutSettings.panRange,
                    format: "%.2f"
                )

                SidebarSliderRow(
                    label: "Pan Y",
                    value: $model.verticalOffset,
                    range: LayoutSettings.panRange,
                    format: "%.2f"
                )

                SidebarSecondaryRow(title: "Reset Framing", symbol: "arrow.uturn.backward") {
                    model.resetLayout()
                }
                .disabled(!model.hasAdjustedLayout)

                SidebarSectionHeader("Output")

                if model.media == nil {
                    SidebarNote("Import media to enable wallpaper output.")
                } else {
                    SidebarPrimaryRow(title: model.primaryActionTitle, symbol: primaryActionSymbol) {
                        model.performPrimaryAction {
                            showingMediaImporter = true
                        }
                    }

                    if model.liveWallpaperRunning {
                        SidebarSecondaryRow(title: "Stop Live Video Wallpaper", symbol: "stop.fill") {
                            model.stopLiveWallpaper()
                        }
                    }
                }

                SidebarNote("Images are handed off to macOS. Video wallpapers remain active while Wallpaper Spanner is running.")
            }
            .padding(.top, 62)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .overlay(sidebarTint)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.18))
                .frame(width: 1)
        }
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SidebarWidthPreferenceKey.self, value: proxy.size.width)
            }
        }
    }

    private var sidebarTint: some View {
        ZStack {
            Color(
                red: colorScheme == .dark ? 0.12 : 0.94,
                green: colorScheme == .dark ? 0.12 : 0.95,
                blue: colorScheme == .dark ? 0.15 : 0.99,
                opacity: colorScheme == .dark ? 0.24 : 0.72
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.03 : 0.18),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var primaryActionSymbol: String {
        guard let media = model.media else {
            return "plus"
        }

        switch media.kind {
        case .image:
            return "photo"
        case .video:
            return model.liveWallpaperRunning ? "play.square.stack.fill" : "play.square.fill"
        }
    }
}

private struct SidebarWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 316

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SidebarSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.35)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 2)
    }
}

private struct SidebarPrimaryRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 14)
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.24), lineWidth: 0.75)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SidebarSecondaryRow: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 14)
                    .foregroundStyle(.secondary)

                Text(title)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct SidebarInfoBlock: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SidebarNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 1)
    }
}

private struct SidebarControlRow<Control: View>: View {
    let label: String
    let control: Control

    init(label: String, @ViewBuilder control: () -> Control) {
        self.label = label
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)

            control

            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .padding(.vertical, 1)
    }
}

private struct SidebarSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    var suffix: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text(formattedValue)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.system(size: 13))

            Slider(value: $value, in: range)
                .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 1)
    }

    private var formattedValue: String {
        let number = String(format: format, value)
        return suffix.map { number + $0 } ?? number
    }
}

private struct FramingPresetMenu: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Menu {
            Section("Framing Presets") {
                ForEach(FramingPreset.allCases) { preset in
                    Button(preset.rawValue) {
                        model.applyFramingPreset(preset)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text("Choose Preset")
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(width: 156, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 0.75)
                    )
            )
        }
        .menuStyle(.borderlessButton)
    }
}

private struct FramingModeMenu: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Menu {
            Section("Layout Mode") {
                ForEach(ContentMode.allCases) { mode in
                    Button {
                        model.contentMode = mode
                    } label: {
                        if mode == model.contentMode {
                            Label(mode.rawValue, systemImage: "checkmark")
                        } else {
                            Text(mode.rawValue)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(model.contentMode.rawValue)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(width: 104, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 0.75)
                    )
            )
        }
        .menuStyle(.borderlessButton)
    }
}

private struct PrimaryOutputCard: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showingMediaImporter: Bool

    var body: some View {
        InsetSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text(primaryDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button {
                    model.performPrimaryAction {
                        showingMediaImporter = true
                    }
                } label: {
                    Label(model.primaryActionTitle, systemImage: primaryActionSymbol)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var primaryActionSymbol: String {
        guard let media = model.media else {
            return "plus"
        }

        switch media.kind {
        case .image:
            return "photo"
        case .video:
            return model.liveWallpaperRunning ? "play.square.stack.fill" : "play.square.fill"
        }
    }

    private var primaryDescription: String {
        guard let media = model.media else {
            return "Import one image or video to start working on the canvas."
        }

        switch media.kind {
        case .image:
            return "Apply the current framing as a real macOS image wallpaper."
        case .video:
            return "Run the current framing as a live desktop video layer."
        }
    }
}

private struct PreviewBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                GlassSurface(
                    shape: Capsule(style: .continuous),
                    material: .underPageBackground,
                    blendingMode: .withinWindow
                )
            )
    }
}

private struct EmptyPreviewOverlay: View {
    let importAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.stack")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Import media to start composing")
                    .font(.title3.weight(.semibold))

                Text("Use one image for a static wallpaper or one video for a live desktop layer.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button("Import Media") {
                importAction()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .background(
            GlassSurface(
                shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
                material: .popover,
                blendingMode: .withinWindow,
                shadowOpacity: 0.10
            )
        )
    }
}

private struct InspectorSection<Content: View>: View {
    let step: String
    let symbol: String
    let title: String
    let content: Content

    init(step: String, symbol: String, title: String, @ViewBuilder content: () -> Content) {
        self.step = step
        self.symbol = symbol
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(step)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(
                        GlassSurface(
                            shape: Circle(),
                            material: .underPageBackground,
                            blendingMode: .withinWindow
                        )
                    )

                Label(title, systemImage: symbol)
                    .font(.title3.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct InspectorInlineControl<Control: View>: View {
    let label: String
    let control: Control

    init(label: String, @ViewBuilder control: () -> Control) {
        self.label = label
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            control

            Spacer(minLength: 0)
        }
    }
}

private struct InspectorValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer(minLength: 20)

            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }
}

private struct InspectorInfoCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        InsetSurface {
            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
    }
}

private struct InspectorSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    var suffix: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formattedValue)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        GlassSurface(
                            shape: Capsule(style: .continuous),
                            material: .underPageBackground,
                            blendingMode: .withinWindow
                        )
                    )
                    .frame(minWidth: 68, alignment: .trailing)
            }

            Slider(value: $value, in: range)
        }
        .controlSize(.small)
    }

    private var formattedValue: String {
        let number = String(format: format, value)
        return suffix.map { number + $0 } ?? number
    }
}

private struct PreviewStatusBanner: View {
    @Environment(\.colorScheme) private var colorScheme
    let state: StatusBannerState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.callout.weight(.semibold))

            Text(state.message)
                .font(.callout.weight(.medium))
                .lineLimit(2)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(colorScheme == .dark ? 0.16 : 0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.14 : 0.06), radius: 14, y: 6)
    }

    private var iconName: String {
        switch state.tone {
        case .neutral:
            "info.circle.fill"
        case .success:
            "checkmark.circle.fill"
        case .error:
            "exclamationmark.triangle.fill"
        }
    }

    private var foregroundColor: Color {
        switch state.tone {
        case .neutral:
            .primary
        case .success:
            .green
        case .error:
            .red
        }
    }
}

private struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.18))
            .frame(height: 1)
    }
}

private struct LiquidGlassPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                GlassSurface(
                    shape: RoundedRectangle(cornerRadius: 28, style: .continuous),
                    material: .sidebar,
                    blendingMode: .withinWindow,
                    shadowOpacity: 0.08
                )
            )
    }
}

private struct StatusBannerState: Equatable {
    let revision: Int
    let message: String
    let tone: StatusTone
}

private struct InsetSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .background(
                GlassSurface(
                    shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                    material: .underPageBackground,
                    blendingMode: .withinWindow
                )
            )
    }
}

private struct GlassSurface<S: InsettableShape>: View {
    @Environment(\.colorScheme) private var colorScheme
    let shape: S
    var material: NSVisualEffectView.Material = .underPageBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    var shadowOpacity: Double = 0

    var body: some View {
        VisualEffectView(material: material, blendingMode: blendingMode)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.04 : 0.18),
                        Color.white.opacity(colorScheme == .dark ? 0.015 : 0.05),
                        .clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(shape)
            .overlay(
                shape.stroke(Color(nsColor: .separatorColor).opacity(colorScheme == .dark ? 0.18 : 0.10), lineWidth: 1)
            )
            .overlay(
                shape.inset(by: 1).stroke(Color.white.opacity(colorScheme == .dark ? 0.04 : 0.18), lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowOpacity > 0 ? 18 : 0, y: shadowOpacity > 0 ? 8 : 0)
    }
}
