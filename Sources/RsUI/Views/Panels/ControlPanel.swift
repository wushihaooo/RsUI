import WindowsFoundation
import WinUI


class ControlPanel {
    private let rootBorder = Border()
    private let rootGrid = Grid()
    private var observingTask: Task<Void, Never>? = nil
    private var tabView = TabView()

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
        rootBorder.borderThickness = Thickness(left: 1, top: 1, right: 1, bottom: 1)
        rootBorder.padding = Thickness(left: 12, top: 0, right: 12, bottom: 0)

        // 为 tabview 添加
        let tab = TabViewItem()
        tab.header = "欢迎"
        tab.isClosable = false

        let text = TextBlock()
        text.text = "这是首页"

        let container = Grid()
        container.children.append(text)

        tab.content = container
        tabView.tabItems.append(tab)
        tabView.selectedItem = tab
        
        rootBorder.child = self.tabView
    }

    private func applyTheme() {

    }

    private func startObserving() {

    }
}
