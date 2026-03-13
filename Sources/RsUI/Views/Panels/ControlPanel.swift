import WindowsFoundation
import WinUI


class ControlPanel {
    private let rootScrollViewer = ScrollViewer()
    private let rootStackPanel = StackPanel()
    private var observingTask: Task<Void, Never>? = nil

    var view: FrameworkElement { rootScrollViewer }

    init() {
        setupUI()
        applyTheme()
        startObserving()
    }
    
    deinit { 
        observingTask?.cancel()
    }

    private func setupUI() {
        rootScrollViewer.horizontalAlignment = .stretch
        rootScrollViewer.verticalAlignment = .stretch
        rootScrollViewer.horizontalScrollBarVisibility = .disabled
        rootScrollViewer.verticalScrollBarVisibility = .auto

        rootStackPanel.horizontalAlignment = .stretch
        rootStackPanel.verticalAlignment = .top
        rootStackPanel.padding = Thickness(left: 12, top: 0, right: 12, bottom: 16)
        rootScrollViewer.content = rootStackPanel
    }

    private func applyTheme() {

    }

    private func startObserving() {

    }

    /// 更新控制面板内容
    func updateContent(_ content: [UIElement]) {
        rootStackPanel.children.clear()
        for item in content {
            rootStackPanel.children.append(item)
        }
    }
}
