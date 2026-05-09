import Foundation
import WindowsFoundation
import UWP
import WinAppSDK
import WinUI
import RsHelper

/// 单页全屏窗口 —— 没有 NavigationView，没有 TabView，没有前进/后退按钮，
/// 只有 TitleBar（带「还原」按钮）+ 页面内容。从 MainWindow 的「最大化此标签」
/// 按钮触发，将一个 Tab 内容独立成全屏窗口。
class FullscreenWindow: Window {
    private let page: Page
    private var contentHost: PageTransitionHost!
    private lazy var restoreButton: Button = makeRestoreButton()
    private lazy var titleBarControl: TitleBar = makeTitleBar()

    init(page: Page, displayTitle: String) {
        self.page = page
        super.init()

        setupWindow()
        setupContent()

        titleBarControl.title = displayTitle
        self.title = displayTitle
        contentHost.transition(to: page.content, transitionInfo: SuppressNavigationTransitionInfo())
    }

    private func setupWindow() {
        self.extendsContentIntoTitleBar = true
        self.appWindow.titleBar.preferredHeightOption = .tall

        let micaBackdrop = MicaBackdrop()
        micaBackdrop.kind = .base
        self.systemBackdrop = micaBackdrop
    }

    private func setupContent() {
        let root = Grid()

        let titleRow = RowDefinition()
        titleRow.height = GridLength(value: 1, gridUnitType: .auto)
        let contentRow = RowDefinition()
        contentRow.height = GridLength(value: 1, gridUnitType: .star)
        root.rowDefinitions.append(titleRow)
        root.rowDefinitions.append(contentRow)

        root.children.append(titleBarControl)
        try? Grid.setRow(titleBarControl, 0)
        try? setTitleBar(titleBarControl)

        contentHost = PageTransitionHost()
        root.children.append(contentHost)
        try? Grid.setRow(contentHost, 1)

        self.content = root
    }

    private func makeTitleBar() -> TitleBar {
        let bar = TitleBar()
        bar.height = 48
        bar.isBackButtonVisible = false
        bar.isPaneToggleButtonVisible = false

        if let iconPath = App.context.iconPath {
            let bitmap = BitmapImage()
            bitmap.uriSource = Uri(iconPath)
            let iconSource = ImageIconSource()
            iconSource.imageSource = bitmap
            bar.iconSource = iconSource
        }

        let rightHeader = StackPanel()
        rightHeader.orientation = .horizontal
        rightHeader.children.append(restoreButton)
        bar.rightHeader = rightHeader

        return bar
    }

    private func makeRestoreButton() -> Button {
        let icon = FontIcon()
        icon.glyph = "\u{E73F}"  // BackToWindow（方形 / 收起全屏）
        icon.fontSize = 12
        let btn = Button()
        btn.content = icon
        btn.minWidth = 0
        btn.minHeight = 0
        btn.padding = Thickness(left: 12, top: 0, right: 12, bottom: 0)
        btn.margin = Thickness(left: 0, top: 4, right: 8, bottom: 4)
        btn.cornerRadius = CornerRadius(topLeft: 6, topRight: 6, bottomRight: 6, bottomLeft: 6)
        btn.verticalAlignment = .stretch
        btn.allowFocusOnInteraction = false

        let transparent = SolidColorBrush(Colors.transparent)
        let hoverBrush = SolidColorBrush(UWP.Color(a: 0x18, r: 0x80, g: 0x80, b: 0x80))
        let pressedBrush = SolidColorBrush(UWP.Color(a: 0x30, r: 0x80, g: 0x80, b: 0x80))
        for key in ["ButtonBackground", "ButtonBackgroundDisabled"] {
            _ = btn.resources.insert(key, transparent)
        }
        _ = btn.resources.insert("ButtonBackgroundPointerOver", hoverBrush)
        _ = btn.resources.insert("ButtonBackgroundPressed", pressedBrush)
        for key in ["ButtonBorderBrush", "ButtonBorderBrushPointerOver",
                    "ButtonBorderBrushPressed", "ButtonBorderBrushDisabled"] {
            _ = btn.resources.insert(key, transparent)
        }

        btn.click.addHandler { [weak self] _, _ in
            self?.restore()
        }

        let toolTip = ToolTip()
        toolTip.content = App.context.tr("还原为窗口")
        try? ToolTipService.setToolTip(btn, toolTip)

        return btn
    }

    /// 将当前 URL 在新的标准 MainWindow 中打开，再关闭自己。
    private func restore() {
        MainWindow.openDetachedWindow(navigatingTo: page.url)
        try? close()
    }

    static func open(page: Page, displayTitle: String) {
        let window = FullscreenWindow(page: page, displayTitle: displayTitle)
        try? window.activate()
    }
}
