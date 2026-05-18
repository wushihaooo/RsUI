import Foundation
import WindowsFoundation
import UWP
import WinUI
import RsUI

enum PhotoBrowserUI {
    static var isDark: Bool {
        App.context.theme.isDark
    }

    static func pageScroll(_ child: UIElement) -> ScrollViewer {
        let scrollViewer = ScrollViewer()
        scrollViewer.verticalScrollBarVisibility = .auto
        scrollViewer.content = child
        return scrollViewer
    }

    static func pageStack() -> StackPanel {
        let stack = StackPanel()
        stack.orientation = .vertical
        stack.spacing = 20
        stack.padding = Thickness(left: 12, top: 12, right: 16, bottom: 32)
        stack.horizontalAlignment = .stretch
        stack.maxWidth = 1440
        return stack
    }

    static func sectionTitle(_ text: String, _ caption: String? = nil) -> UIElement {
        let stack = StackPanel()
        stack.spacing = 4

        let title = TextBlock()
        title.text = text
        title.fontSize = 20
        title.fontWeight = FontWeights.semiBold
        title.textWrapping = .wrap
        stack.children.append(title)

        if let caption {
            let subtitle = TextBlock()
            subtitle.text = caption
            subtitle.fontSize = 13
            subtitle.textWrapping = .wrap
            subtitle.foreground = secondaryBrush()
            stack.children.append(subtitle)
        }

        return stack
    }

    static func text(_ value: String, size: Double = 14, weight: FontWeight? = nil, secondary: Bool = false) -> TextBlock {
        let block = TextBlock()
        block.text = value
        block.fontSize = size
        block.textWrapping = .wrap
        if let weight {
            block.fontWeight = weight
        }
        if secondary {
            block.foreground = secondaryBrush()
        }
        return block
    }

    static func iconButton(_ glyph: String, _ text: String, action: @escaping () -> Void) -> Button {
        let button = Button()
        button.minWidth = 0
        button.padding = Thickness(left: 12, top: 8, right: 12, bottom: 8)
        button.cornerRadius = CornerRadius(topLeft: 6, topRight: 6, bottomRight: 6, bottomLeft: 6)

        let stack = StackPanel()
        stack.orientation = .horizontal
        stack.spacing = 8

        let icon = FontIcon()
        icon.glyph = glyph
        icon.fontSize = 14
        stack.children.append(icon)

        let label = TextBlock()
        label.text = text
        label.textWrapping = .noWrap
        stack.children.append(label)

        button.content = stack
        button.click.addHandler { _, _ in action() }
        return button
    }

    static func infoBar(title: String, message: String, severity: InfoBarSeverity = .informational) -> InfoBar {
        let bar = InfoBar()
        bar.title = title
        bar.message = message
        bar.severity = severity
        bar.isClosable = false
        bar.isOpen = true
        return bar
    }

    static func card(child: UIElement, padding: Thickness = Thickness(left: 18, top: 16, right: 18, bottom: 16)) -> Border {
        let border = Border()
        border.cornerRadius = CornerRadius(topLeft: 8, topRight: 8, bottomRight: 8, bottomLeft: 8)
        border.borderThickness = Thickness(left: 1, top: 1, right: 1, bottom: 1)
        border.background = SolidColorBrush(isDark
            ? UWP.Color(a: 255, r: 34, g: 37, b: 43)
            : UWP.Color(a: 255, r: 252, g: 252, b: 253))
        border.borderBrush = SolidColorBrush(isDark
            ? UWP.Color(a: 255, r: 61, g: 66, b: 76)
            : UWP.Color(a: 255, r: 228, g: 231, b: 236))
        border.padding = padding
        border.child = child
        return border
    }

    static func metricCard(title: String, value: String, glyph: String) -> Border {
        let stack = StackPanel()
        stack.spacing = 10

        let icon = FontIcon()
        icon.glyph = glyph
        icon.fontSize = 20
        stack.children.append(icon)

        stack.children.append(text(value, size: 26, weight: FontWeights.semiBold))
        stack.children.append(text(title, size: 13, secondary: true))

        return card(child: stack)
    }

    static func preview(photo: SamplePhoto, height: Double) -> Border {
        let preview = Border()
        preview.height = height
        preview.cornerRadius = CornerRadius(topLeft: 8, topRight: 8, bottomRight: 8, bottomLeft: 8)
        preview.background = SolidColorBrush(photo.accent)

        let grid = Grid()
        grid.background = SolidColorBrush(photo.secondary)
        grid.opacity = 0.92

        let label = TextBlock()
        label.text = photo.title
        label.fontSize = 13
        label.fontWeight = FontWeights.semiBold
        label.foreground = SolidColorBrush(UWP.Color(a: 235, r: 255, g: 255, b: 255))
        label.margin = Thickness(left: 14, top: 0, right: 14, bottom: 12)
        label.verticalAlignment = .bottom
        label.textWrapping = .wrap

        if let sourceURL = photo.sourceURL {
            let bitmap = BitmapImage()
            bitmap.decodePixelWidth = 900
            bitmap.uriSource = Uri(imageSourceString(for: sourceURL))

            let image = WinUI.Image()
            image.source = bitmap
            image.stretch = .uniformToFill
            image.horizontalAlignment = .stretch
            image.verticalAlignment = .stretch
            image.imageFailed.addHandler { _, _ in
                label.text = "Image failed to load"
            }
            grid.children.append(image)
        } else {
            let icon = FontIcon()
            icon.glyph = "\u{EB9F}"
            icon.fontSize = 42
            icon.horizontalAlignment = .center
            icon.verticalAlignment = .center
            icon.foreground = SolidColorBrush(UWP.Color(a: 235, r: 255, g: 255, b: 255))
            grid.children.append(icon)
        }

        grid.children.append(label)

        preview.child = grid
        return preview
    }

    static func imageSourceString(for url: URL) -> String {
        if url.isFileURL, !url.path.isEmpty {
            return url.path
        }
        return url.absoluteString
    }

    static func metadataRow(_ label: String, _ value: String) -> UIElement {
        let grid = Grid()
        grid.columnSpacing = 16

        let labelColumn = ColumnDefinition()
        labelColumn.width = GridLength(value: 140, gridUnitType: .pixel)
        grid.columnDefinitions.append(labelColumn)

        let valueColumn = ColumnDefinition()
        valueColumn.width = GridLength(value: 1, gridUnitType: .star)
        grid.columnDefinitions.append(valueColumn)

        let labelBlock = text(label, secondary: true)
        try? Grid.setColumn(labelBlock, 0)
        grid.children.append(labelBlock)

        let valueBlock = text(value, weight: FontWeights.semiBold)
        try? Grid.setColumn(valueBlock, 1)
        grid.children.append(valueBlock)

        return grid
    }

    static func secondaryBrush() -> SolidColorBrush {
        SolidColorBrush(isDark
            ? UWP.Color(a: 255, r: 182, g: 187, b: 198)
            : UWP.Color(a: 255, r: 89, g: 96, b: 108))
    }
}
