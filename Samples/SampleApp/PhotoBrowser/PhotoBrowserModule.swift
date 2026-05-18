import Foundation
import Observation
import WindowsFoundation
import UWP
import WinUI
import RsUI

@Observable
final class PhotoBrowserModule: Module {
    let id = PhotoBrowserRoutes.host

    var importedAlbums: [ImportedPhotoAlbum] = []
    var importState = "Ready"
    var importMessage = "Pick a folder to scan local images."
    var thumbnailSize = 220.0
    var showMetadata = true

    init() {
    }

    var albumSummaries: [PhotoAlbumSummary] {
        importedAlbums.map { album in
            PhotoAlbumSummary(
                id: album.id,
                title: album.title,
                summary: album.summary
            )
        }
    }

    var allPhotos: [SamplePhoto] {
        importedAlbums.flatMap(\.photos)
    }

    var recentPhotos: [SamplePhoto] {
        Array(allPhotos.prefix(6))
    }

    func navigationViewMenuItemsRequired(in context: WindowContext) -> [NavigationViewItemBase] {
        let header = NavigationViewItemHeader()
        header.content = "Photo Browser"

        let homeItem = NavigationViewItem.build(
            iconGlyph: "\u{E80F}",
            label: "Home",
            url: PhotoBrowserRoutes.home.absoluteString
        )

        let libraryItem = NavigationViewItem.build(
            iconGlyph: "\u{E8B7}",
            label: "Library",
            url: PhotoBrowserRoutes.library.absoluteString
        )

        let importItem = NavigationViewItem.build(
            iconGlyph: "\u{E8F4}",
            label: "Import",
            url: PhotoBrowserRoutes.importFolder.absoluteString
        )

        return [header, homeItem, libraryItem, importItem]
    }

    func settingsGroupRequired() -> (title: String, cards: [UIElement])? {
        let metadataToggle = ToggleSwitch()
        metadataToggle.isOn = showMetadata
        metadataToggle.onContent = "Visible"
        metadataToggle.offContent = "Hidden"
        metadataToggle.toggled.addHandler { [weak self] sender, _ in
            guard let toggle = sender as? ToggleSwitch else { return }
            self?.showMetadata = toggle.isOn
        }

        let sizeSlider = Slider()
        sizeSlider.minimum = 180
        sizeSlider.maximum = 280
        sizeSlider.value = thumbnailSize
        sizeSlider.width = 180
        sizeSlider.valueChanged.addHandler { [weak self] sender, _ in
            guard let slider = sender as? Slider else { return }
            self?.thumbnailSize = slider.value
        }

        let densityCombo = ComboBox()
        densityCombo.minWidth = 160
        densityCombo.items.append("Comfortable")
        densityCombo.items.append("Compact")
        densityCombo.items.append("Large preview")
        densityCombo.selectedIndex = 0
        densityCombo.selectionChanged.addHandler { [weak self] sender, _ in
            guard let combo = sender as? ComboBox else { return }
            switch combo.selectedIndex {
            case 1:
                self?.thumbnailSize = 180
            case 2:
                self?.thumbnailSize = 270
            default:
                self?.thumbnailSize = 220
            }
        }

        let metadataCard = SettingsCard("\u{E946}", "Photo metadata", "Show camera, location, and file details in viewer pages.", metadataToggle)
        let thumbnailCard = SettingsCard("\u{E91B}", "Thumbnail size", "Controls the gallery item width.", sizeSlider)
        let densityCard = SettingsCard("\u{E8A9}", "Gallery density", "Choose how much space each image uses in the gallery.", densityCombo)

        let expander = SettingsExpander(
            headerIconGlyph: "\u{E713}",
            header: "Photo Browser behavior",
            description: "Gallery layout and viewing preferences.",
            content: nil,
            items: [thumbnailCard, densityCard]
        )

        return ("Photo Browser", [metadataCard, expander])
    }

    func navigationRequested(for url: URL, in context: WindowContext) -> RsUI.Page? {
        guard url.host == id else { return nil }

        let parts = url.pathComponents.filter { $0 != "/" }
        guard let first = parts.first else {
            return PhotoHomePage(context: context, module: self)
        }

        switch first {
        case "home":
            return PhotoHomePage(context: context, module: self)
        case "library":
            return PhotoLibraryPage(context: context, module: self)
        case "album":
            guard parts.count > 1 else { return PhotoLibraryPage(context: context, module: self) }
            return PhotoAlbumPage(context: context, module: self, albumID: parts[1])
        case "photo":
            guard parts.count > 1, let photo = photo(id: parts[1]) else { return nil }
            return PhotoDetailPage(context: context, module: self, photo: photo)
        case "import":
            return PhotoImportPage(context: context, module: self)
        default:
            return nil
        }
    }

    func pickFolder(in context: WindowContext) {
        context.pickFolder { [weak self] path in
            self?.importFolder(path, context: context)
        }
    }

    func importedAlbumTitle(_ albumID: String) -> String? {
        importedAlbums.first { $0.id == albumID }?.title
    }

    func albumTitle(_ albumID: String) -> String {
        return importedAlbums.first { $0.id == albumID }?.title ?? "Album"
    }

    func albumSummary(_ albumID: String) -> String {
        return importedAlbums.first { $0.id == albumID }?.summary ?? ""
    }

    func photos(for albumID: String) -> [SamplePhoto] {
        importedAlbums.first(where: { $0.id == albumID })?.photos ?? []
    }

    func photo(id: String) -> SamplePhoto? {
        importedAlbums.lazy.flatMap(\.photos).first { $0.id == id }
    }

    private func importFolder(_ path: String, context: WindowContext) {
        let existingID = importedAlbums.first(where: { $0.path == path })?.id
        let albumID = existingID ?? "imported-\(importedAlbums.count)"
        importState = "Importing"
        importMessage = "Scanning \(path)"

        Task { [weak self] in
            let album = await Task.detached(priority: .userInitiated) {
                Self.scanFolder(path: path, albumID: albumID)
            }.value

            await MainActor.run { [weak self] in
                guard let self else { return }
                if let index = self.importedAlbums.firstIndex(where: { $0.id == album.id }) {
                    self.importedAlbums[index] = album
                } else {
                    self.importedAlbums.append(album)
                }
                self.importState = "Ready"
                self.importMessage = album.photos.isEmpty
                    ? "No supported images were found in \(path)"
                    : "Imported \(album.photos.count) image\(album.photos.count == 1 ? "" : "s") from \(album.title)"
                _ = context.navigate(to: PhotoBrowserRoutes.album(album.id))
            }
        }
    }

    func previousPhoto(before photo: SamplePhoto) -> SamplePhoto? {
        adjacentPhoto(to: photo, offset: -1)
    }

    func nextPhoto(after photo: SamplePhoto) -> SamplePhoto? {
        adjacentPhoto(to: photo, offset: 1)
    }

    func rescanImportedAlbum(_ albumID: String, context: WindowContext) {
        guard let album = importedAlbums.first(where: { $0.id == albumID }) else { return }
        importFolder(album.path, context: context)
    }

    func removeImportedAlbum(_ albumID: String, context: WindowContext? = nil) {
        guard let index = importedAlbums.firstIndex(where: { $0.id == albumID }) else { return }
        let removed = importedAlbums.remove(at: index)
        importMessage = "Removed \(removed.title)"
        if context != nil {
            // If the current page was an imported album/photo, move back to a stable route.
            context?.navigate(to: PhotoBrowserRoutes.library)
        }
    }

    private func adjacentPhoto(to photo: SamplePhoto, offset: Int) -> SamplePhoto? {
        let photos = photos(for: photo.albumID)
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else { return nil }
        let nextIndex = index + offset
        guard photos.indices.contains(nextIndex) else { return nil }
        return photos[nextIndex]
    }

    private static func scanFolder(path: String, albumID: String) -> ImportedPhotoAlbum {
        let folderURL = URL(fileURLWithPath: path)
        let folderTitle = folderURL.lastPathComponent.isEmpty ? path : folderURL.lastPathComponent
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        let urls = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )?.compactMap { $0 as? URL } ?? []

        let imageURLs = urls
            .filter { url in
                guard isSupportedImage(url) else { return false }
                return (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }
            .sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
            .prefix(300)

        let photos = imageURLs.enumerated().map { index, url in
            makeImportedPhoto(url: url, index: index, albumID: albumID, albumTitle: folderTitle)
        }

        return ImportedPhotoAlbum(id: albumID, path: path, title: folderTitle, photos: Array(photos))
    }

    private static func isSupportedImage(_ url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "bmp", "gif", "tif", "tiff", "heic", "heif", "webp":
            return true
        default:
            return false
        }
    }

    private static func makeImportedPhoto(url: URL, index: Int, albumID: String, albumTitle: String) -> SamplePhoto {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let fileSize = values?.fileSize.map(formatBytes) ?? "Unknown size"
        let date = values?.contentModificationDate.map(formatDate) ?? "Unknown date"
        let colors = importedPalette(index)
        return SamplePhoto(
            id: "\(albumID)-photo-\(index)",
            title: url.deletingPathExtension().lastPathComponent,
            albumID: albumID,
            albumTitle: albumTitle,
            location: url.deletingLastPathComponent().path,
            date: date,
            camera: "Local image file",
            dimensions: "Loaded by WinUI Image",
            fileSize: fileSize,
            accent: colors.accent,
            secondary: colors.secondary,
            sourceURL: url
        )
    }

    private static func importedPalette(_ index: Int) -> (accent: UWP.Color, secondary: UWP.Color) {
        let colors: [(UWP.Color, UWP.Color)] = [
            (UWP.Color(a: 255, r: 42, g: 128, b: 194), UWP.Color(a: 255, r: 28, g: 45, b: 72)),
            (UWP.Color(a: 255, r: 184, g: 94, b: 64), UWP.Color(a: 255, r: 63, g: 58, b: 71)),
            (UWP.Color(a: 255, r: 90, g: 145, b: 92), UWP.Color(a: 255, r: 43, g: 62, b: 60)),
            (UWP.Color(a: 255, r: 126, g: 96, b: 180), UWP.Color(a: 255, r: 42, g: 44, b: 74)),
            (UWP.Color(a: 255, r: 203, g: 72, b: 93), UWP.Color(a: 255, r: 68, g: 45, b: 59))
        ]
        return colors[index % colors.count]
    }

    private static func formatBytes(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(Int(value)) \(units[unitIndex])"
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
