import WindowsFoundation
import WinUI


class ControlPanel {
    private let rootBorder = Border()
    private let rootGrid = Grid()
    private var observingTask: Task<Void, Never>? = nil
    private var tabView = TabView()
    private var pivot = Pivot()

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

        for i in 0..<3 {
            let item = PivotItem()
            item.header = "pivot\(i)"
            let tb = TextBlock()
            tb.text = "这是首页"
            item.content = tb
            self.pivot.items.append(item)
        }
        
        rootBorder.child = self.pivot
    }

    private func applyTheme() {

    }

    private func startObserving() {

    }
}
