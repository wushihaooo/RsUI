import Foundation
import WindowsFoundation
import UWP
import WinUI
import RsUI
import RsHelper

fileprivate func tr(_ keyAndValue: String) -> String {
    return App.context.language == .zh_CN ? "翻译\(keyAndValue)" : keyAndValue
}

final class ClockModule: Module {
    let id = "clock"
    private weak var currentPage: ClockPage?

    init() {
        log.info("ClockModule init")
    }
    deinit {
        log.info("ClockModule deinit")
    }

    func registerNavigationViewItems(in context: WindowContext) -> [NavigationViewItem] {
        let navigationViewItem = NavigationViewItem()
        let grid = Grid()
        grid.horizontalAlignment = .stretch
        grid.verticalAlignment = .center
        
        // 定义列：标签(填充) | 动作按钮(自动)
        let textCol = ColumnDefinition()
        textCol.width = GridLength(value: 1, gridUnitType: .star)
        grid.columnDefinitions.append(textCol)

        let textBlock = TextBlock()
        textBlock.text = tr("Clock")
        textBlock.verticalAlignment = .center
        textBlock.horizontalAlignment = .left
        textBlock.textTrimming = .characterEllipsis
        try? Grid.setColumn(textBlock, 0)
        grid.children.append(textBlock)

        navigationViewItem.content = grid
        let icon = FontIcon()
        icon.glyph = "\u{E121}"
        icon.fontSize = 16
        navigationViewItem.icon = icon

        navigationViewItem.tag = Uri("rs://\(id)")

        return [navigationViewItem]
    }

    func makeNavigationTarget(for selectedItemTag: Any, in context: WindowContext) -> (header: UIElement?, page: AppPage)? {
        guard let tag = selectedItemTag as? Uri, tag.host == self.id else { return nil }

        let container = StackPanel()
        container.padding = Thickness(left: 0, top: 0, right: 0, bottom: 32)

        let titleBlock = TextBlock()
        titleBlock.text = tr("Clock")
        container.children.append(titleBlock)

        let subtitleBlock = TextBlock()
        subtitleBlock.text = tr("Real-time clock display")
        subtitleBlock.fontSize = 14
        subtitleBlock.foreground = SolidColorBrush(App.context.theme.isDark ?
            UWP.Color(a: 255, r: 180, g: 180, b: 180) :
            UWP.Color(a: 255, r: 100, g: 100, b: 100))
        container.children.append(subtitleBlock)

        let page = ClockPage()
        currentPage = page
        return (container, page)
    }

    func makeSettingsCard() -> UIElement? {
        return nil
    }

    func makeControlPanelTarget() -> UIElement? {
        func makeActionButton(_ title: String, action: @escaping () -> Void) -> Button {
            let button = Button()
            button.content = title
            button.horizontalAlignment = .stretch
            button.click.addHandler { _, _ in
                action()
            }
            return button
        }

        func makeActionRow(title: String, description: String, plusLabel: String, minusLabel: String, plus: @escaping () -> Void, minus: @escaping () -> Void, icon: String) -> UIElement {
            let buttonColumn = StackPanel()
            buttonColumn.orientation = .vertical
            buttonColumn.spacing = 6
            buttonColumn.children.append(makeActionButton(minusLabel, action: minus))
            buttonColumn.children.append(makeActionButton(plusLabel, action: plus))
            return buildSettingsRow(iconGlyph: icon, title: title, description: description, control: buttonColumn)
        }

        let container = StackPanel()
        container.spacing = 12
        container.padding = Thickness(left: 0, top: 16, right: 0, bottom: 16)

        let hourRow = makeActionRow(
            title: tr("Hours"),
            description: tr("Shift time by one hour"),
            plusLabel: tr("+1 Hour"),
            minusLabel: tr("-1 Hour"),
            plus: { [weak self] in self?.currentPage?.adjustTime(by: 3600) },
            minus: { [weak self] in self?.currentPage?.adjustTime(by: -3600) },
            icon: "\u{E823}"
        )

        let minuteRow = makeActionRow(
            title: tr("Minutes"),
            description: tr("Shift time by one minute"),
            plusLabel: tr("+1 Minute"),
            minusLabel: tr("-1 Minute"),
            plus: { [weak self] in self?.currentPage?.adjustTime(by: 60) },
            minus: { [weak self] in self?.currentPage?.adjustTime(by: -60) },
            icon: "\u{E823}"
        )

        let resetButton = makeActionButton(tr("Reset"), action: { [weak self] in
            self?.currentPage?.resetTime()
        })
        resetButton.minWidth = 160

        let resetRow = buildSettingsRow(
            iconGlyph: "\u{E777}",
            title: tr("Reset"),
            description: tr("Return to system time"),
            control: resetButton
        )

        let card = buildSettingsCard(title: tr("Time Adjustment"), content: [hourRow, minuteRow, resetRow])
        container.children.append(card)
        return container
    }
}
