import AppKit
import QuickLookThumbnailing
import SwiftUI

struct SystemWallpaperBrowserView: View {
    let items: [SystemWallpaperItem]
    let isLoading: Bool
    let errorMessage: String?
    let refresh: () -> Void
    let choose: (SystemWallpaperItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredItems: [SystemWallpaperItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return items
        }

        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(trimmed) ||
            item.subtitle.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 16),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("macOS Wallpapers")
                        .font(.largeTitle.weight(.bold))
                    Text("Import Apple’s bundled wallpaper files directly into the span editor.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Reload") {
                    refresh()
                }
                .buttonStyle(.bordered)

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            TextField("Search wallpapers", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Reading Apple wallpaper assets…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredItems.isEmpty {
                Text("No wallpapers matched your search.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredItems) { item in
                            Button {
                                choose(item)
                                dismiss()
                            } label: {
                                WallpaperTile(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 980, minHeight: 720)
    }
}

private struct WallpaperTile: View {
    let item: SystemWallpaperItem
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(
                                Image(systemName: item.kind == .video ? "video.fill" : "photo.fill")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                .frame(height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(item.importQuality.badgeText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .padding(8)
            }

            Text(item.name)
                .font(.headline)
                .lineLimit(2)

            Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .task(id: item.id) {
            thumbnail = await WallpaperThumbnailProvider.shared.thumbnail(for: item)
        }
    }
}

@MainActor
private final class WallpaperThumbnailProvider {
    static let shared = WallpaperThumbnailProvider()

    private let cache = NSCache<NSString, NSImage>()

    func thumbnail(for item: SystemWallpaperItem) async -> NSImage? {
        if let cached = cache.object(forKey: item.id as NSString) {
            return cached
        }

        let fileURL = item.previewURL ?? item.sourceURL
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: 420, height: 260),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                let image: NSImage?
                if let cgImage = representation?.cgImage {
                    image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                } else {
                    image = NSWorkspace.shared.icon(forFile: fileURL.path)
                }

                Task { @MainActor in
                    if let image {
                        self.cache.setObject(image, forKey: item.id as NSString)
                    }

                    continuation.resume(returning: image)
                }
            }
        }
    }
}
