import Foundation
import WindowsFoundation
import UWP
import WinUI

extension MainWindow {
    func tab(for item: TabViewItem) -> MainWindowTab? {
        // Primary: stable name-based lookup (avoids WinRT projection identity instability)
        if let id = tabIDByName[item.name], let tab = viewModel.tabs.first(where: { ObjectIdentifier($0) == id }) {
            return tab
        }
        // Fallback: identity comparison
        for tab in viewModel.tabs {
            if tabItemsByID[ObjectIdentifier(tab)] === item {
                return tab
            }
        }
        return nil
    }

    func selectedTabViewItem(sender: Any?, args: SelectionChangedEventArgs?) -> TabViewItem? {
        if
            let args,
            let addedItems = args.addedItems,
            addedItems.size > 0,
            let item = addedItems.getAt(0) as? TabViewItem {
            return item
        }

        if let tabView = sender as? TabView {
            return tabView.selectedItem as? TabViewItem
        }

        return tabView.selectedItem as? TabViewItem
    }

    func switchToTab(_ tab: MainWindowTab) {
        guard viewModel.selectedTab !== tab else { return }
        viewModel.select(tab: tab)
        renderSelectedTab()
    }

    func closeTab(for item: TabViewItem) {
        guard let tab = tab(for: item) else { return }
        viewModel.close(tab: tab)
        renderSelectedTab()
    }

    func closeOtherTabs() {
        viewModel.closeOtherTabs()
        renderSelectedTab()
    }

    // MARK: - Native tear-out helpers

    // Returns a window for the native tear-out to drop a tab into. Reuses the
    // current empty spare if one exists (the framework asks repeatedly during a
    // drag); otherwise creates and activates a fresh one so it owns a valid
    // AppWindow.Id. The OS positions it as it follows the cursor.
    static func tearOutReceiver() -> MainWindow {
        if let spare = MainWindow.spareReceiver, spare.viewModel?.tabs.isEmpty ?? false {
            return spare
        }
        let window = MainWindow(tearOutReceiver: true)
        try? window.activate()
        MainWindow.spareReceiver = window
        return window
    }

    // Removes a tab from this window's model (its strip item is reconciled away
    // by renderSelectedTab); the MainWindowTab object — with its history — lives
    // on to be adopted elsewhere.
    func releaseTab(_ tab: MainWindowTab) {
        guard viewModel != nil else { return }
        viewModel.detachTab(tab)
        renderSelectedTab()
    }

    // Adopts a torn tab into this window's model, building a fresh strip item for
    // it. `at` is the merge drop position; nil appends (the empty-receiver case).
    func adoptTornTab(_ tab: MainWindowTab, at index: Int? = nil) {
        guard viewModel != nil else { return }
        awaitTransferredTab = false
        viewModel.adoptTab(tab, at: index, transitionInfoOverride: SuppressNavigationTransitionInfo())
        renderSelectedTab()
    }

    // Closes this window once its last tab has been torn/merged away, so an
    // emptied floating receiver doesn't linger.
    func closeIfEmpty() {
        guard viewModel?.tabs.isEmpty ?? false else { return }
        try? close()
    }

    func setupTabDragHint() {
        let hintText = TextBlock()
        hintText.text = MainWindow.tr("TabDragHint")
        hintText.fontSize = 12
        hintText.textWrapping = .wrap
        hintText.maxWidth = 460
        hintText.foreground = SolidColorBrush(UWP.Color(a: 255, r: 245, g: 249, b: 255))

        let hintBorder = Border()
        hintBorder.background = SolidColorBrush(UWP.Color(a: 230, r: 21, g: 94, b: 175))
        hintBorder.borderBrush = SolidColorBrush(UWP.Color(a: 255, r: 166, g: 215, b: 255))
        hintBorder.borderThickness = Thickness(left: 1, top: 1, right: 1, bottom: 1)
        hintBorder.cornerRadius = CornerRadius(topLeft: 10, topRight: 10, bottomRight: 10, bottomLeft: 10)
        hintBorder.padding = Thickness(left: 12, top: 8, right: 12, bottom: 8)
        hintBorder.horizontalAlignment = .center
        hintBorder.verticalAlignment = .top
        hintBorder.margin = Thickness(left: 0, top: 12, right: 0, bottom: 0)
        hintBorder.opacity = 0
        hintBorder.visibility = .collapsed
        hintBorder.isHitTestVisible = false
        hintBorder.child = hintText
        try? Canvas.setZIndex(hintBorder, 99)
        tabContentHost.children.append(hintBorder)
        tabDragHintBorder = hintBorder
        tabDragHintText = hintText

        tabView.tabDragStarting.addHandler { [weak hintBorder] _, _ in
            hintBorder?.visibility = .visible
            hintBorder?.opacity = 1
        }
        tabView.tabDragCompleted.addHandler { [weak hintBorder] _, _ in
            hintBorder?.opacity = 0
            hintBorder?.visibility = .collapsed
        }
    }

    func focusTab(matchingURL url: URL) -> Bool {
        guard let tab = viewModel.findTab(matchingURL: url) else { return false }
        switchToTab(tab)
        return true
    }

    func detachCurrentTab() -> DetachedTabInfo? {
        guard let currentTab = viewModel.selectedTab else { return nil }
        guard let index = viewModel.tabs.firstIndex(where: { $0 === currentTab }) else { return nil }
        guard let url = currentTab.currentPage?.url else { return nil }
        viewModel.detachTab(currentTab)
        renderSelectedTab()
        return DetachedTabInfo(url: url, index: index)
    }

    func insertTab(
        _ page: Page,
        atIndex index: Int? = nil,
        switchToTab: Bool = true,
        transitionInfoOverride: NavigationTransitionInfo? = nil
    ) {
        viewModel.addTab(
            at: index,
            for: page,
            transitionInfoOverride: transitionInfoOverride,
            switchToTab: switchToTab
        )
        renderSelectedTab()
    }

    static func openDetachedWindow(
        navigatingTo url: URL,
        transitionInfoOverride: NavigationTransitionInfo? = nil,
        collapseNavigationPane: Bool = false
    ) {
        // 一次性 viewer 窗口：初始折叠 NavPane，且不把折叠状态回写到全局 windowLayout。
        // 必须经 init 参数路径，因为 setupContent 一旦跑完 lazy navigationView 就定型了。
        let window = collapseNavigationPane
            ? MainWindow(initialNavigationViewPaneOpen: false, suppressLayoutPersistence: true)
            : MainWindow()
        window.initialNavigationURL = url
        window.initialNavigationTransitionInfoOverride = transitionInfoOverride
        try? window.activate()
    }

    // Opens a new window seeded with an existing tab object (tab tear-off),
    // preserving its back/forward history. The tab must already be detached
    // from its source window's view model before calling this.
    static func openDetachedWindow(transferring tab: MainWindowTab) {
        let window = MainWindow()
        window.initialTransferredTab = tab
        try? window.activate()
    }

    static func openDetachedWindow(
        opening page: Page,
        transitionInfoOverride: NavigationTransitionInfo? = nil
    ) {
        openDetachedWindow(transitionInfoOverride: transitionInfoOverride) { _ in page }
    }

    static func openDetachedWindow(
        transitionInfoOverride: NavigationTransitionInfo? = nil,
        makePage: @escaping (WindowContext) -> Page
    ) {
        let window = MainWindow()
        window.initialPageFactory = makePage
        window.initialNavigationTransitionInfoOverride = transitionInfoOverride
        try? window.activate()
    }

    // Opens a new top-level window in-process showing Home, skipping last-view
    // restore. The taskbar "New Window" reaches this after being redirected to
    // the primary instance.
    static func openDetachedWindowAtHome() {
        let window = MainWindow(forceHomeOnLaunch: true)
        try? window.activate()
    }
}
