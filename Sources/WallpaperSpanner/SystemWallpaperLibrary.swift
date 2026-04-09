import Foundation

enum SystemWallpaperImportQuality: String {
    case originalAsset
    case previewFallback

    var badgeText: String {
        switch self {
        case .originalAsset:
            return "Original"
        case .previewFallback:
            return "Preview"
        }
    }
}

struct SystemWallpaperItem: Identifiable, Hashable {
    let id: String
    let name: String
    let sourceURL: URL
    let previewURL: URL?
    let kind: MediaKind
    let importQuality: SystemWallpaperImportQuality
    let originPath: URL

    var subtitle: String {
        switch importQuality {
        case .originalAsset:
            return sourceURL.lastPathComponent
        case .previewFallback:
            return "Apple preview asset"
        }
    }

    var importStatusMessage: String {
        switch importQuality {
        case .originalAsset:
            return "Loaded macOS wallpaper \(name)."
        case .previewFallback:
            return "Loaded \(name) from Apple’s preview asset. Some bundled wallpapers do not expose the full original file."
        }
    }
}

enum SystemWallpaperLibraryError: LocalizedError {
    case failedToReadCatalog

    var errorDescription: String? {
        switch self {
        case .failedToReadCatalog:
            return "Could not read the macOS wallpaper catalog."
        }
    }
}

enum SystemWallpaperLibrary {
    private static let supportedExtensions = ["heic", "jpg", "jpeg", "png", "mov", "mp4"]
    private static let topLevelRoot = URL(filePath: "/System/Library/Desktop Pictures", directoryHint: .isDirectory)
    private static let hiddenWallpaperRoot = URL(filePath: "/System/Library/Desktop Pictures/.wallpapers", directoryHint: .isDirectory)
    private static let localRoot = URL(filePath: "/Library/Desktop Pictures", directoryHint: .isDirectory)

    static func loadCatalog() throws -> [SystemWallpaperItem] {
        var items: [SystemWallpaperItem] = []
        var seenIDs = Set<String>()

        try appendOrderedSystemItems(into: &items, seenIDs: &seenIDs)
        appendDirectFiles(in: topLevelRoot, recursive: false, into: &items, seenIDs: &seenIDs)
        appendDirectFiles(in: hiddenWallpaperRoot, recursive: true, into: &items, seenIDs: &seenIDs)
        appendDirectFiles(in: localRoot, recursive: true, into: &items, seenIDs: &seenIDs)

        if items.isEmpty {
            throw SystemWallpaperLibraryError.failedToReadCatalog
        }

        return items
    }

    static func resolveImportTarget(
        wrapperName: String,
        mobileAssetID: String?,
        rootDirectory: URL,
        previewURL: URL?,
        fileManager: FileManager = .default
    ) -> (sourceURL: URL?, quality: SystemWallpaperImportQuality) {
        let stems = Array(Set([wrapperName, mobileAssetID].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }))

        for stem in stems {
            for fileExtension in supportedExtensions {
                let candidate = rootDirectory.appendingPathComponent("\(stem).\(fileExtension)")
                if fileManager.fileExists(atPath: candidate.path) {
                    return (candidate, .originalAsset)
                }
            }

            let folder = rootDirectory
                .appendingPathComponent(".wallpapers", isDirectory: true)
                .appendingPathComponent(stem, isDirectory: true)
            if let nestedAsset = firstSupportedFile(in: folder, fileManager: fileManager) {
                return (nestedAsset, .originalAsset)
            }
        }

        if let previewURL, fileManager.fileExists(atPath: previewURL.path) {
            return (previewURL, .previewFallback)
        }

        return (nil, .previewFallback)
    }

    private static func appendOrderedSystemItems(
        into items: inout [SystemWallpaperItem],
        seenIDs: inout Set<String>
    ) throws {
        let orderedListURL = topLevelRoot.appendingPathComponent(".orderedPictures.plist")
        guard FileManager.default.fileExists(atPath: orderedListURL.path) else {
            return
        }

        let data = try Data(contentsOf: orderedListURL)
        guard let orderedNames = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String] else {
            throw SystemWallpaperLibraryError.failedToReadCatalog
        }

        for name in orderedNames {
            let fileURL = topLevelRoot.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                continue
            }

            if fileURL.pathExtension.lowercased() == "madesktop" {
                if let item = makeMadesktopItem(from: fileURL, rootDirectory: topLevelRoot) {
                    insert(item, into: &items, seenIDs: &seenIDs)
                }
                continue
            }

            if let item = makeDirectItem(from: fileURL, displayName: fileURL.deletingPathExtension().lastPathComponent) {
                insert(item, into: &items, seenIDs: &seenIDs)
            }
        }
    }

    private static func appendDirectFiles(
        in directory: URL,
        recursive: Bool,
        into items: inout [SystemWallpaperItem],
        seenIDs: inout Set<String>
    ) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }

        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]

        if recursive {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return
            }

            for case let fileURL as URL in enumerator {
                guard let item = makeDirectItem(from: fileURL) else {
                    continue
                }
                insert(item, into: &items, seenIDs: &seenIDs)
            }

            return
        }

        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for fileURL in fileURLs {
            guard let item = makeDirectItem(from: fileURL) else {
                continue
            }
            insert(item, into: &items, seenIDs: &seenIDs)
        }
    }

    private static func makeDirectItem(from fileURL: URL, displayName: String? = nil) -> SystemWallpaperItem? {
        guard isSupportedMediaFile(fileURL) else {
            return nil
        }

        guard let kind = try? MediaKind.detect(url: fileURL) else {
            return nil
        }

        let name = displayName ?? fileURL.deletingPathExtension().lastPathComponent
        let previewURL = preferredPreviewURL(for: fileURL)

        return SystemWallpaperItem(
            id: fileURL.path,
            name: name,
            sourceURL: fileURL,
            previewURL: previewURL,
            kind: kind,
            importQuality: .originalAsset,
            originPath: fileURL
        )
    }

    private static func makeMadesktopItem(from wrapperURL: URL, rootDirectory: URL) -> SystemWallpaperItem? {
        guard
            let wrapper = try? MadesktopWrapper(contentsOf: wrapperURL),
            let resolved = resolvedMadesktopItem(wrapperURL: wrapperURL, wrapper: wrapper, rootDirectory: rootDirectory)
        else {
            return nil
        }

        return resolved
    }

    private static func resolvedMadesktopItem(
        wrapperURL: URL,
        wrapper: MadesktopWrapper,
        rootDirectory: URL
    ) -> SystemWallpaperItem? {
        let name = wrapperURL.deletingPathExtension().lastPathComponent
        let resolution = resolveImportTarget(
            wrapperName: name,
            mobileAssetID: wrapper.mobileAssetID,
            rootDirectory: rootDirectory,
            previewURL: wrapper.thumbnailURL
        )

        guard
            let sourceURL = resolution.sourceURL,
            let kind = try? MediaKind.detect(url: sourceURL)
        else {
            return nil
        }

        return SystemWallpaperItem(
            id: wrapperURL.path,
            name: name,
            sourceURL: sourceURL,
            previewURL: wrapper.thumbnailURL,
            kind: kind,
            importQuality: resolution.quality,
            originPath: wrapperURL
        )
    }

    private static func preferredPreviewURL(for fileURL: URL) -> URL? {
        if fileURL.path.contains("/.wallpapers/") {
            let folder = fileURL.deletingLastPathComponent()
            if let thumbnail = folderContents(in: folder)?
                .first(where: { $0.lastPathComponent.localizedCaseInsensitiveContains("thumbnail") }) {
                return thumbnail
            }
        }

        guard fileURL.deletingLastPathComponent() == topLevelRoot else {
            return nil
        }

        let thumbnailURL = topLevelRoot
            .appendingPathComponent(".thumbnails", isDirectory: true)
            .appendingPathComponent(fileURL.lastPathComponent)

        return FileManager.default.fileExists(atPath: thumbnailURL.path) ? thumbnailURL : nil
    }

    private static func folderContents(in directory: URL) -> [URL]? {
        try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    }

    private static func firstSupportedFile(in directory: URL, fileManager: FileManager) -> URL? {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let sorted = files
            .filter(isSupportedMediaFile)
            .sorted { lhs, rhs in
                if lhs.lastPathComponent.localizedCaseInsensitiveContains("thumbnail") {
                    return false
                }
                if rhs.lastPathComponent.localizedCaseInsensitiveContains("thumbnail") {
                    return true
                }
                return lhs.lastPathComponent < rhs.lastPathComponent
            }

        return sorted.first
    }

    private static func isSupportedMediaFile(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            return false
        }

        if url.lastPathComponent.localizedCaseInsensitiveContains("thumbnail") {
            return false
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return false
        }

        return true
    }

    private static func insert(
        _ item: SystemWallpaperItem,
        into items: inout [SystemWallpaperItem],
        seenIDs: inout Set<String>
    ) {
        guard seenIDs.insert(item.id).inserted else {
            return
        }

        items.append(item)
    }
}

private struct MadesktopWrapper {
    let mobileAssetID: String?
    let thumbnailURL: URL?

    init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        let dictionary = plist as? [String: Any]

        self.mobileAssetID = dictionary?["mobileAssetID"] as? String

        if let thumbnailPath = dictionary?["thumbnailPath"] as? String {
            self.thumbnailURL = URL(fileURLWithPath: thumbnailPath)
        } else {
            self.thumbnailURL = nil
        }
    }
}
