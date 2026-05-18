import Foundation
import UWP
import WinUI
import RsUI

final class PhotoHomePage: RsUI.Page {
    private let context: WindowContext
    private let module: PhotoBrowserModule

    init(context: WindowContext, module: PhotoBrowserModule) {
        self.context = context
        self.module = module
    }

    var url: URL { PhotoBrowserRoutes.home }
    var header: Any? { "Photo Browser" }

    var content: UIElement {
        let stack = PhotoBrowserUI.pageStack()
        stack.children.append(statusBar())
        stack.children.append(primaryActions())
        if module.allPhotos.isEmpty {
            stack.children.append(emptyLibraryPrompt())
        } else {
            stack.children.append(PhotoBrowserUI.sectionTitle("Recent photos", "A small working set from imported folders."))
            stack.children.append(photoGrid(module.recentPhotos))
            stack.children.append(PhotoBrowserUI.sectionTitle("Albums"))
            stack.children.append(albumGrid(module.albumSummaries))
        }
        return PhotoBrowserUI.pageScroll(stack)
    }

    private func statusBar() -> UIElement {
        let message = module.importedAlbums.isEmpty
            ? "Pick a folder to start browsing local photos."
            : module.importMessage
        return PhotoBrowserUI.infoBar(
            title: module.importedAlbums.isEmpty ? "No photos imported" : "Library updated",
            message: message,
            severity: module.importedAlbums.isEmpty ? .informational : .success
        )
    }

    private func emptyLibraryPrompt() -> UIElement {
        let stack = StackPanel()
        stack.spacing = 12
        stack.children.append(PhotoBrowserUI.sectionTitle("Start with a folder", "SampleApp now shows only images you import from local folders."))

        let actions = StackPanel()
        actions.orientation = .horizontal
        actions.spacing = 8
        actions.children.append(PhotoBrowserUI.iconButton("\u{E710}", "Pick folder") { [module, context] in
            module.pickFolder(in: context)
        })
        actions.children.append(PhotoBrowserUI.iconButton("\u{E8A7}", "Open import") { [context] in
            _ = context.navigate(to: PhotoBrowserRoutes.importFolder)
        })
        stack.children.append(actions)
        return stack
    }

    private func primaryActions() -> UIElement {
        let grid = Grid()
        grid.columnSpacing = 12
        for _ in 0..<3 {
            let column = ColumnDefinition()
            column.width = GridLength(value: 1, gridUnitType: .star)
            grid.columnDefinitions.append(column)
        }

        let cards: [Border] = [
            PhotoBrowserUI.metricCard(title: "Photos", value: "\(module.allPhotos.count)", glyph: "\u{EB9F}"),
            PhotoBrowserUI.metricCard(title: "Albums", value: "\(module.albumSummaries.count)", glyph: "\u{E8B7}"),
            PhotoBrowserUI.metricCard(title: "Imported folders", value: "\(module.importedAlbums.count)", glyph: "\u{E8F4}")
        ]

        for (index, card) in cards.enumerated() {
            try? Grid.setColumn(card, Int32(index))
            grid.children.append(card)
        }
        return grid
    }

    private func albumGrid(_ albums: [PhotoAlbumSummary]) -> UIElement {
        let grid = Grid()
        grid.columnSpacing = 12
        grid.rowSpacing = 12

        for _ in 0..<2 {
            let column = ColumnDefinition()
            column.width = GridLength(value: 1, gridUnitType: .star)
            grid.columnDefinitions.append(column)
        }

        let rowCount = max(1, Int(ceil(Double(albums.count) / 2.0)))
        for rowIndex in 0..<rowCount {
            let row = RowDefinition()
            row.height = GridLength(value: 1, gridUnitType: .auto)
            grid.rowDefinitions.append(row)

            for columnIndex in 0..<2 {
                let albumIndex = rowIndex * 2 + columnIndex
                guard albumIndex < albums.count else { continue }
                let card = albumCard(albums[albumIndex])
                try? Grid.setRow(card, Int32(rowIndex))
                try? Grid.setColumn(card, Int32(columnIndex))
                grid.children.append(card)
            }
        }
        return grid
    }

    private func albumCard(_ album: PhotoAlbumSummary) -> Border {
        let stack = StackPanel()
        stack.spacing = 10

        let title = PhotoBrowserUI.text(album.title, size: 17, weight: FontWeights.semiBold)
        stack.children.append(title)
        stack.children.append(PhotoBrowserUI.text(album.summary, size: 13, secondary: true))
        stack.children.append(PhotoBrowserUI.iconButton("\u{E8A7}", "Open") { [context] in
            _ = context.navigate(to: PhotoBrowserRoutes.album(album.id))
        })

        return PhotoBrowserUI.card(child: stack)
    }

    private func photoGrid(_ photos: [SamplePhoto]) -> UIElement {
        let gridView = GridView()
        gridView.selectionMode = .none
        gridView.isItemClickEnabled = false
        gridView.padding = Thickness(left: 0, top: 4, right: 0, bottom: 8)

        let width = max(180, min(module.thumbnailSize, 260))
        let height = width + 96
        let panelXaml = """
            <ItemsPanelTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
                <ItemsWrapGrid Orientation="Horizontal" ItemWidth="\(Int(width + 14))" ItemHeight="\(Int(height + 10))"/>
            </ItemsPanelTemplate>
            """
        if let template = try? XamlReader.load(panelXaml) as? ItemsPanelTemplate {
            gridView.itemsPanel = template
        }

        for photo in photos {
            gridView.items.append(photoTile(photo, width: width))
        }
        return gridView
    }

    private func photoTile(_ photo: SamplePhoto, width: Double) -> UIElement {
        let stack = StackPanel()
        stack.spacing = 8
        stack.width = width

        stack.children.append(PhotoBrowserUI.preview(photo: photo, height: width * 0.62))
        stack.children.append(PhotoBrowserUI.text(photo.title, size: 15, weight: FontWeights.semiBold))
        stack.children.append(PhotoBrowserUI.iconButton("\u{E8A7}", "View") { [context] in
            _ = context.navigate(to: PhotoBrowserRoutes.photo(photo.id))
        })

        return PhotoBrowserUI.card(child: stack, padding: Thickness(left: 10, top: 10, right: 10, bottom: 12))
    }
}

final class PhotoLibraryPage: RsUI.Page {
    private let context: WindowContext
    private let module: PhotoBrowserModule

    init(context: WindowContext, module: PhotoBrowserModule) {
        self.context = context
        self.module = module
    }

    var url: URL { PhotoBrowserRoutes.library }
    var header: Any? { "Library" }

    var content: UIElement {
        let stack = PhotoBrowserUI.pageStack()
        stack.children.append(PhotoBrowserUI.sectionTitle("Library", "Browse imported folders and the photos they contain."))

        if module.importedAlbums.isEmpty {
            stack.children.append(PhotoBrowserUI.infoBar(
                title: "No imported folders",
                message: "Pick a folder to add local photos to the library.",
                severity: .informational
            ))
            stack.children.append(PhotoBrowserUI.iconButton("\u{E710}", "Pick folder") { [module, context] in
                module.pickFolder(in: context)
            })
        } else {
            stack.children.append(PhotoBrowserUI.sectionTitle("Imported folders"))
            stack.children.append(albumRows())
            if module.allPhotos.isEmpty {
                stack.children.append(PhotoBrowserUI.infoBar(
                    title: "No photos found",
                    message: "The imported folders do not contain supported image files.",
                    severity: .warning
                ))
            } else {
                stack.children.append(PhotoBrowserUI.sectionTitle("All photos"))
                stack.children.append(photoGrid(module.allPhotos))
            }
        }
        return PhotoBrowserUI.pageScroll(stack)
    }

    private func albumRows() -> UIElement {
        let stack = StackPanel()
        stack.spacing = 8
        for album in module.albumSummaries {
            stack.children.append(albumRow(album))
        }
        return stack
    }

    private func albumRow(_ album: PhotoAlbumSummary) -> UIElement {
        let grid = Grid()
        grid.columnSpacing = 12

        let textColumn = ColumnDefinition()
        textColumn.width = GridLength(value: 1, gridUnitType: .star)
        grid.columnDefinitions.append(textColumn)

        let actionColumn = ColumnDefinition()
        actionColumn.width = GridLength(value: 1, gridUnitType: .auto)
        grid.columnDefinitions.append(actionColumn)

        let textStack = StackPanel()
        textStack.spacing = 4
        textStack.children.append(PhotoBrowserUI.text(album.title, size: 16, weight: FontWeights.semiBold))
        textStack.children.append(PhotoBrowserUI.text(album.summary, size: 13, secondary: true))
        try? Grid.setColumn(textStack, 0)
        grid.children.append(textStack)

        let open = PhotoBrowserUI.iconButton("\u{E8A7}", "Open") { [context] in
            _ = context.navigate(to: PhotoBrowserRoutes.album(album.id))
        }
        try? Grid.setColumn(open, 1)
        grid.children.append(open)

        return PhotoBrowserUI.card(child: grid, padding: Thickness(left: 14, top: 12, right: 14, bottom: 12))
    }

    private func photoGrid(_ photos: [SamplePhoto]) -> UIElement {
        let gridView = GridView()
        gridView.selectionMode = .none
        gridView.isItemClickEnabled = false

        let width = max(180, min(module.thumbnailSize, 280))
        let height = width + 96
        let panelXaml = """
            <ItemsPanelTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
                <ItemsWrapGrid Orientation="Horizontal" ItemWidth="\(Int(width + 14))" ItemHeight="\(Int(height + 10))"/>
            </ItemsPanelTemplate>
            """
        if let template = try? XamlReader.load(panelXaml) as? ItemsPanelTemplate {
            gridView.itemsPanel = template
        }

        for photo in photos {
            gridView.items.append(photoTile(photo, width: width))
        }
        return gridView
    }

    private func photoTile(_ photo: SamplePhoto, width: Double) -> UIElement {
        let stack = StackPanel()
        stack.spacing = 8
        stack.width = width

        stack.children.append(PhotoBrowserUI.preview(photo: photo, height: width * 0.62))
        stack.children.append(PhotoBrowserUI.text(photo.title, size: 15, weight: FontWeights.semiBold))
        stack.children.append(PhotoBrowserUI.text(photo.albumTitle, size: 12, secondary: true))
        stack.children.append(PhotoBrowserUI.iconButton("\u{E8A7}", "View") { [context] in
            _ = context.navigate(to: PhotoBrowserRoutes.photo(photo.id))
        })

        return PhotoBrowserUI.card(child: stack, padding: Thickness(left: 10, top: 10, right: 10, bottom: 12))
    }
}

final class PhotoAlbumPage: RsUI.Page {
    private let context: WindowContext
    private let module: PhotoBrowserModule
    private let albumID: String

    init(context: WindowContext, module: PhotoBrowserModule, albumID: String) {
        self.context = context
        self.module = module
        self.albumID = albumID
    }

    var url: URL { PhotoBrowserRoutes.album(albumID) }
    var header: Any? { module.albumTitle(albumID) }

    var content: UIElement {
        let photos = module.photos(for: albumID)
        let stack = PhotoBrowserUI.pageStack()
        stack.children.append(PhotoBrowserUI.sectionTitle(module.albumTitle(albumID), module.albumSummary(albumID)))
        stack.children.append(actions(photos: photos))

        if photos.isEmpty {
            stack.children.append(PhotoBrowserUI.infoBar(title: "No photos", message: "No supported image files were found in this folder.", severity: .warning))
        } else {
            for photo in photos {
                stack.children.append(photoRow(photo))
            }
        }
        return PhotoBrowserUI.pageScroll(stack)
    }

    private func actions(photos: [SamplePhoto]) -> UIElement {
        let actions = StackPanel()
        actions.orientation = .horizontal
        actions.spacing = 8
        if let first = photos.first {
            actions.children.append(PhotoBrowserUI.iconButton("\u{E8A7}", "Open first photo") { [context] in
                _ = context.navigate(to: PhotoBrowserRoutes.photo(first.id))
            })
        }
        if module.importedAlbumTitle(albumID) != nil {
            actions.children.append(PhotoBrowserUI.iconButton("\u{E72C}", "Rescan") { [module, context, albumID] in
                module.rescanImportedAlbum(albumID, context: context)
            })
            actions.children.append(PhotoBrowserUI.iconButton("\u{E74D}", "Remove") { [module, context, albumID] in
                module.removeImportedAlbum(albumID, context: context)
            })
        }
        return actions
    }

    private func photoRow(_ photo: SamplePhoto) -> UIElement {
        let grid = Grid()
        grid.columnSpacing = 12

        let previewColumn = ColumnDefinition()
        previewColumn.width = GridLength(value: 168, gridUnitType: .pixel)
        grid.columnDefinitions.append(previewColumn)

        let textColumn = ColumnDefinition()
        textColumn.width = GridLength(value: 1, gridUnitType: .star)
        grid.columnDefinitions.append(textColumn)

        let actionColumn = ColumnDefinition()
        actionColumn.width = GridLength(value: 1, gridUnitType: .auto)
        grid.columnDefinitions.append(actionColumn)

        let preview = PhotoBrowserUI.preview(photo: photo, height: 96)
        try? Grid.setColumn(preview, 0)
        grid.children.append(preview)

        let textStack = StackPanel()
        textStack.spacing = 4
        textStack.verticalAlignment = .center
        textStack.children.append(PhotoBrowserUI.text(photo.title, size: 16, weight: FontWeights.semiBold))
        textStack.children.append(PhotoBrowserUI.text("\(photo.fileSize) - \(photo.date)", secondary: true))
        try? Grid.setColumn(textStack, 1)
        grid.children.append(textStack)

        let open = PhotoBrowserUI.iconButton("\u{E8A7}", "View") { [context] in
            _ = context.navigate(to: PhotoBrowserRoutes.photo(photo.id))
        }
        try? Grid.setColumn(open, 2)
        grid.children.append(open)

        return PhotoBrowserUI.card(child: grid, padding: Thickness(left: 12, top: 12, right: 12, bottom: 12))
    }
}

final class PhotoDetailPage: RsUI.Page {
    private let context: WindowContext
    private let module: PhotoBrowserModule
    private let photo: SamplePhoto

    init(context: WindowContext, module: PhotoBrowserModule, photo: SamplePhoto) {
        self.context = context
        self.module = module
        self.photo = photo
    }

    var url: URL { PhotoBrowserRoutes.photo(photo.id) }
    var header: Any? { photo.title }

    var content: UIElement {
        let stack = PhotoBrowserUI.pageStack()

        let layout = Grid()
        layout.columnSpacing = 20
        let previewColumn = ColumnDefinition()
        previewColumn.width = GridLength(value: 2, gridUnitType: .star)
        layout.columnDefinitions.append(previewColumn)
        let detailsColumn = ColumnDefinition()
        detailsColumn.width = GridLength(value: 1, gridUnitType: .star)
        layout.columnDefinitions.append(detailsColumn)

        let preview = PhotoBrowserUI.preview(photo: photo, height: 460)
        try? Grid.setColumn(preview, 0)
        layout.children.append(preview)

        let detailCard = PhotoBrowserUI.card(child: detailPanel())
        try? Grid.setColumn(detailCard, 1)
        layout.children.append(detailCard)

        stack.children.append(layout)
        return PhotoBrowserUI.pageScroll(stack)
    }

    private func detailPanel() -> UIElement {
        let stack = StackPanel()
        stack.spacing = 14
        stack.children.append(PhotoBrowserUI.text(photo.title, size: 20, weight: FontWeights.semiBold))
        stack.children.append(navigationButtons())

        if module.showMetadata {
            stack.children.append(PhotoBrowserUI.metadataRow("Album", photo.albumTitle))
            stack.children.append(PhotoBrowserUI.metadataRow("Location", photo.location))
            stack.children.append(PhotoBrowserUI.metadataRow("Date", photo.date))
            stack.children.append(PhotoBrowserUI.metadataRow("Camera", photo.camera))
            stack.children.append(PhotoBrowserUI.metadataRow("Dimensions", photo.dimensions))
            stack.children.append(PhotoBrowserUI.metadataRow("File size", photo.fileSize))
            if let sourceURL = photo.sourceURL {
                stack.children.append(PhotoBrowserUI.metadataRow("Source", sourceURL.path))
            }
        }
        return stack
    }

    private func navigationButtons() -> UIElement {
        let actions = StackPanel()
        actions.orientation = .horizontal
        actions.spacing = 8
        if let previous = module.previousPhoto(before: photo) {
            actions.children.append(PhotoBrowserUI.iconButton("\u{E72B}", "Previous") { [context] in
                _ = context.navigate(to: PhotoBrowserRoutes.photo(previous.id))
            })
        }
        if let next = module.nextPhoto(after: photo) {
            actions.children.append(PhotoBrowserUI.iconButton("\u{E72A}", "Next") { [context] in
                _ = context.navigate(to: PhotoBrowserRoutes.photo(next.id))
            })
        }
        actions.children.append(PhotoBrowserUI.iconButton("\u{E8B7}", "Album") { [context, photo] in
            _ = context.navigate(to: PhotoBrowserRoutes.album(photo.albumID))
        })
        return actions
    }
}

final class PhotoImportPage: RsUI.Page {
    private let context: WindowContext
    private let module: PhotoBrowserModule

    init(context: WindowContext, module: PhotoBrowserModule) {
        self.context = context
        self.module = module
    }

    var url: URL { PhotoBrowserRoutes.importFolder }
    var header: Any? { "Import" }

    var content: UIElement {
        let stack = PhotoBrowserUI.pageStack()
        stack.children.append(PhotoBrowserUI.sectionTitle("Import folders", "Pick a local folder and scan supported image files."))
        stack.children.append(PhotoBrowserUI.infoBar(
            title: module.importState,
            message: module.importMessage,
            severity: module.importState == "Importing" ? .informational : .success
        ))

        let actions = StackPanel()
        actions.orientation = .horizontal
        actions.spacing = 8
        actions.children.append(PhotoBrowserUI.iconButton("\u{E710}", "Pick folder") { [module, context] in
            module.pickFolder(in: context)
        })
        actions.children.append(PhotoBrowserUI.iconButton("\u{E8A7}", "Open library") { [context] in
            _ = context.navigate(to: PhotoBrowserRoutes.library)
        })
        stack.children.append(actions)

        if module.importedAlbums.isEmpty {
            stack.children.append(PhotoBrowserUI.infoBar(
                title: "No imported folders",
                message: "Pick a folder to add it to the library.",
                severity: .warning
            ))
        } else {
            for album in module.importedAlbums {
                stack.children.append(folderRow(album: album))
            }
        }
        return PhotoBrowserUI.pageScroll(stack)
    }

    private func folderRow(album: ImportedPhotoAlbum) -> UIElement {
        let grid = Grid()
        grid.columnSpacing = 12
        let textColumn = ColumnDefinition()
        textColumn.width = GridLength(value: 1, gridUnitType: .star)
        grid.columnDefinitions.append(textColumn)
        let actionColumn = ColumnDefinition()
        actionColumn.width = GridLength(value: 1, gridUnitType: .auto)
        grid.columnDefinitions.append(actionColumn)

        let textStack = StackPanel()
        textStack.spacing = 4
        textStack.children.append(PhotoBrowserUI.text(album.title, size: 16, weight: FontWeights.semiBold))
        textStack.children.append(PhotoBrowserUI.text("\(album.photos.count) image\(album.photos.count == 1 ? "" : "s") - \(album.path)", secondary: true))
        try? Grid.setColumn(textStack, 0)
        grid.children.append(textStack)

        let actions = StackPanel()
        actions.orientation = .horizontal
        actions.spacing = 8
        actions.children.append(PhotoBrowserUI.iconButton("\u{E8A7}", "Open") { [context] in
            _ = context.navigate(to: PhotoBrowserRoutes.album(album.id))
        })
        actions.children.append(PhotoBrowserUI.iconButton("\u{E72C}", "Rescan") { [module, context] in
            module.rescanImportedAlbum(album.id, context: context)
        })
        actions.children.append(PhotoBrowserUI.iconButton("\u{E74D}", "Remove") { [module, context] in
            module.removeImportedAlbum(album.id, context: context)
        })
        try? Grid.setColumn(actions, 1)
        grid.children.append(actions)

        return PhotoBrowserUI.card(child: grid)
    }
}
