import Observation
import UWP
import WinUI

/***
  * StatusBar
  * rootBorder
  *   Border
  *     Grid
  *       leftStack
  *       rigthStack
  */
class StatusBar {
    private let rootBorder = Border()
    private let rootGrid = Grid()
    private let leftStackPanel = StackPanel()
    private let rightStackPanel = StackPanel()
    private var observingTask: Task<Void, Never>? = nil

    var view: Border { rootBorder }

    init() {
        setupUI()
        applyTheme()
        startObserving()
    }

    deinit {
        observingTask?.cancel()
    }

    private func setupUI() {
        rootBorder.borderThickness = Thickness(left: 0, top: 1, right: 0, bottom: 0)
        rootBorder.padding = Thickness(left: 12, top: 0, right: 12, bottom: 0)

        let leftColumn = ColumnDefinition()
        leftColumn.width = GridLength(value: 1, gridUnitType: .star)
        rootGrid.columnDefinitions.append(leftColumn)

        let rightColumn = ColumnDefinition()
        rightColumn.width = GridLength(value: 1, gridUnitType: .auto)
        rootGrid.columnDefinitions.append(rightColumn)

        // leftLabel.fontSize = 12
        // leftLabel.verticalAlignment = .center
        // leftLabel.text = ""
        // rootGrid.children.append(leftLabel)
        // try? Grid.setColumn(leftLabel, 0)

        let tb = TextBlock()
        tb.text = "this is left prompt"
        leftStackPanel.children.append(tb)
        
        leftStackPanel.verticalAlignment = .center
        leftStackPanel.horizontalAlignment = .left
        leftStackPanel.orientation = .horizontal
        leftStackPanel.spacing = 16
        try? Grid.setColumn(leftStackPanel, 0)
        rootGrid.children.append(leftStackPanel)

        // rightLabel.fontSize = 12
        // rightLabel.verticalAlignment = .center
        // rightLabel.text = ""
        // rootGrid.children.append(rightLabel)
        // try? Grid.setColumn(rightLabel, 1)
        
        rightStackPanel.verticalAlignment = .center
        rightStackPanel.horizontalAlignment = .right
        try? Grid.setColumn(rightStackPanel, 1)
        rootGrid.children.append(rightStackPanel)

        let tb1 = TextBlock()
        tb1.text = "this is right"
        rightStackPanel.children.append(tb1)

        for module in App.context.modules {
            if let tmp = module.makeStatusItem() {
                leftStackPanel.children.append(tmp)
            }
        }

        rootBorder.child = rootGrid
    }

    private func startObserving() {
        let env = Observations {
            (App.context.theme)
        }
        observingTask = Task { [weak self] in
            for await _ in env {
                await MainActor.run { [weak self] in
                    self?.applyTheme()
                }
            }
        }
    }

    private func applyTheme() {
        let isDark = App.context.theme.isDark
        let backgroundColor = isDark
            ? Color(a: 255, r: 24, g: 27, b: 34)
            : Color(a: 255, r: 248, g: 249, b: 252)
        let borderColor = isDark
            ? Color(a: 255, r: 55, g: 59, b: 73)
            : Color(a: 255, r: 223, g: 226, b: 233)
        let textColor = isDark
            ? Color(a: 255, r: 189, g: 193, b: 207)
            : Color(a: 255, r: 88, g: 96, b: 105)

        rootBorder.background = SolidColorBrush(backgroundColor)
        rootBorder.borderBrush = SolidColorBrush(borderColor)
        // leftLabel.foreground = SolidColorBrush(textColor)
        // rightLabel.foreground = SolidColorBrush(textColor)
    }
}
