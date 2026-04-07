import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Wallpaper Spanner")
                    .font(.largeTitle.weight(.bold))

                Text("Load one image or one video, compose it once, then span it across every detected display.")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                LayoutPreview(
                    displays: model.displays,
                    media: model.media,
                    settings: model.settings
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                DisplayStrip(displays: model.displays)
            }
            .padding(28)
            .frame(minWidth: 760, maxWidth: .infinity, maxHeight: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    controlCard("Media") {
                        VStack(alignment: .leading, spacing: 12) {
                            Button("Choose Image or Video") {
                                model.chooseMedia()
                            }
                            .buttonStyle(.borderedProminent)

                            if let media = model.media {
                                LabeledValueRow(label: "File", value: media.fileName)
                                LabeledValueRow(label: "Type", value: media.kind.label)
                                LabeledValueRow(
                                    label: "Aspect",
                                    value: "\(Int(media.contentSize.width)) x \(Int(media.contentSize.height))"
                                )
                            } else {
                                Text("No media selected yet.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    controlCard("Layout") {
                        VStack(alignment: .leading, spacing: 14) {
                            Picker("Mode", selection: $model.contentMode) {
                                ForEach(ContentMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            LabeledSlider(
                                label: "Zoom",
                                value: $model.zoom,
                                range: 1.0 ... 3.0,
                                format: "%.2fx"
                            )

                            LabeledSlider(
                                label: "Pan X",
                                value: $model.horizontalOffset,
                                range: -1.0 ... 1.0,
                                format: "%.2f"
                            )

                            LabeledSlider(
                                label: "Pan Y",
                                value: $model.verticalOffset,
                                range: -1.0 ... 1.0,
                                format: "%.2f"
                            )
                        }
                    }

                    controlCard("Actions") {
                        VStack(alignment: .leading, spacing: 12) {
                            Button("Refresh Displays") {
                                model.refreshDisplays()
                            }
                            .buttonStyle(.bordered)

                            Button("Apply Image Wallpaper") {
                                model.applyImageWallpaper()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!model.canApplyImage)

                            Button(model.liveWallpaperRunning ? "Restart Live Video Wallpaper" : "Start Live Video Wallpaper") {
                                model.startLiveWallpaper()
                            }
                            .buttonStyle(.bordered)
                            .disabled(!model.canStartVideo)

                            Button("Stop Live Video Wallpaper") {
                                model.stopLiveWallpaper()
                            }
                            .buttonStyle(.bordered)
                            .disabled(!model.liveWallpaperRunning)

                            Text("Images become real macOS wallpapers. Videos run in desktop-level windows behind your icons while this app stays open.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    controlCard("Status") {
                        Text(model.statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(28)
                .frame(width: 360, alignment: .leading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private func controlCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct DisplayStrip: View {
    let displays: [DisplayInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detected Displays")
                .font(.title3.weight(.semibold))

            if displays.isEmpty {
                Text("No screens detected.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(displays) { display in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(display.name)
                                .font(.headline)
                            Text(display.logicalSizeDescription)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(display.pixelSizeDescription)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
            }
        }
    }
}

private struct LabeledValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: format, value))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $value, in: range)
        }
    }
}
