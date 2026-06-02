import Foundation
import WindowsFoundation
import UWP
import WinUI
import RsHelper

extension MainWindow {
    func setupContent() {
        let root = Grid()

        // 设置行定义
        let titleRowDef = RowDefinition()
        titleRowDef.height = GridLength(value: 1, gridUnitType: .auto)
        root.rowDefinitions.append(titleRowDef)
        
        let contentRowDef = RowDefinition()
        contentRowDef.height = GridLength(value: 1, gridUnitType: .star)
        root.rowDefinitions.append(contentRowDef)
        
        root.children.append(titleBar)
        try? Grid.setRow(titleBar, 0)
        try? setTitleBar(titleBar)

        configureNavigationViewSelection()
        configureTabViewEvents()
        if MainWindow.isTabTearOffMergeEnabled {
            setupTabDragHint()
        }
        configurePaneEvents()

        let navWrapper = makeNavigationWrapper()
        self.navWrapper = navWrapper
        root.children.append(navWrapper)
        try? Grid.setRow(navWrapper, 1)

        self.content = root

        installFullscreenEscapeAccelerator(on: root)
    }

    private func configureNavigationViewSelection() {
        navigationView.selectionChanged.addHandler { [weak self] _, args in
            guard let self, let args, !self.isSyncingSelection else { return }

            if args.isSettingsSelected {
                navigate(to: SettingsPage(), transitionInfoOverride: SuppressNavigationTransitionInfo())
            } else if
                let item = args.selectedItem as? NavigationViewItem,
                let tag = item.tag,
                let str = tag as? HString,
                let url = URL(string: String(hString: str)) {
                _ = navigate(to: url, transitionInfoOverride: SuppressNavigationTransitionInfo())
            }
        }
    }

    private func configureTabViewEvents() {
        tabView.selectionChanged.addHandler { [weak self] sender, args in
            guard let self, !self.isSyncingTabSelection else { return }
            guard let item = self.selectedTabViewItem(sender: sender, args: args) else { return }
            guard let tab = self.tab(for: item) else { return }
            self.switchToTab(tab)
        }

        tabView.tabCloseRequested.addHandler { [weak self] _, args in
            guard let self, let args, let item = args.tab else { return }
            self.closeTab(for: item)
        }

        tabView.addTabButtonClick.addHandler { [weak self] _, _ in
            self?.openNewTabFromTabStrip()
        }

        guard MainWindow.isTabTearOffMergeEnabled else { return }

        // Source: record which tab is being dragged and expose it via static state for cross-window drop.
        tabView.tabDragStarting.addHandler { [weak self] _, args in
            guard let self, let args, args.tab != nil else { return }
            // args.tab is unreliable here: because TabItems hold TabViewItems
            // directly (no ItemsSource), it resolves to the first strip item
            // regardless of which tab is dragged. WinUI selects the pressed tab
            // before the drag begins, so the selected tab IS the dragged one.
            guard let tab = self.viewModel.selectedTab else { return }
            guard let url = tab.currentPage?.url else { return }
            // DIAGNOSTIC (temporary): viaArgsIndex should show the buggy 0 while
            // selectedIndex tracks the real dragged tab — confirms the fix.
            let viaArgsIndex = (args.tab).flatMap { self.tab(for: $0) }
                .flatMap { r in self.viewModel.tabs.firstIndex(where: { $0 === r }) }
            let selectedIndex = self.viewModel.tabs.firstIndex(where: { $0 === tab })
            log.info("[TabDrag] start viaArgsIndex=\(viaArgsIndex.map(String.init) ?? "nil") selectedIndex=\(selectedIndex.map(String.init) ?? "nil") draggURL=\(url.lastPathComponent)")
            self.draggingTabForDrop = tab
            MainWindow.activeDrag = DragState(sourceWindowID: ObjectIdentifier(self), tab: tab, tabURL: url)
        }

        // Source: flag that the tab was physically dropped outside (vs drag cancelled by Escape).
        tabView.tabDroppedOutside.addHandler { [weak self] _, _ in
            log.info("[TabDrag] droppedOutside")
            self?.dragDroppedOutside = true
        }

        // Source: decide outcome once drag completes.
        tabView.tabDragCompleted.addHandler { [weak self] _, args in
            guard let self, let args else { return }
            let wasDroppedOutside = self.dragDroppedOutside
            let didMerge = MainWindow.dragMergedIntoOtherWindow
            // DIAGNOSTIC (temporary): record the inputs that pick the outcome.
            let draggingIndex = self.viewModel.tabs.firstIndex(where: { $0 === self.draggingTabForDrop })
            log.info("[TabDrag] completed dropResult=\(args.dropResult.rawValue) wasDroppedOutside=\(wasDroppedOutside) didMerge=\(didMerge) draggingIndex=\(draggingIndex.map(String.init) ?? "nil") draggingURL=\(self.draggingTabForDrop?.currentPage?.url.lastPathComponent ?? "nil") count=\(self.viewModel.tabs.count)")
            defer {
                self.dragDroppedOutside = false
                self.draggingTabForDrop = nil
                MainWindow.activeDrag = nil
                MainWindow.dragMergedIntoOtherWindow = false
            }
            guard let tab = self.draggingTabForDrop else { return }
            guard self.viewModel.tabs.count > 1 else { return }
            guard self.viewModel.tabs.contains(where: { $0 === tab }) else { return }

            if args.dropResult == .none {
                guard wasDroppedOutside else { return }
                log.info("[TabDrag] -> tearOff url=\(tab.currentPage?.url.lastPathComponent ?? "nil")")
                // Transfer the tab object itself (not just its URL) so its
                // back/forward history moves with it to the new window.
                self.viewModel.detachTab(tab)
                self.renderSelectedTab()
                MainWindow.openDetachedWindow(transferring: tab)
            } else if didMerge {
                log.info("[TabDrag] -> merge (detach source) url=\(tab.currentPage?.url.lastPathComponent ?? "nil")")
                // The destination window already adopted this tab object in its
                // drop handler, so just detach it here (don't close/destroy it).
                self.viewModel.detachTab(tab)
                self.renderSelectedTab()
            } else {
                // In-window reorder: WinUI already moved the strip item, so just
                // persist the new order to the view model.
                log.info("[TabDrag] -> reorder")
                self.syncTabOrderFromStrip()
            }
        }

        // Destination: accept tab drops from other windows' TabViews.
        tabView.dragOver.addHandler { [weak self] _, args in
            guard let self, let args else { return }
            guard let drag = MainWindow.activeDrag, drag.sourceWindowID != ObjectIdentifier(self) else { return }
            args.acceptedOperation = .move
        }
        tabView.drop.addHandler { [weak self] _, _ in
            guard let self else { return }
            guard let drag = MainWindow.activeDrag, drag.sourceWindowID != ObjectIdentifier(self) else { return }
            log.info("[TabDrag] drop(dest) acceptURL=\(drag.tabURL.lastPathComponent)")
            MainWindow.dragMergedIntoOtherWindow = true
            // Adopt the dragged tab object itself so its back/forward history
            // survives the merge. The source window detaches it in its own
            // tabDragCompleted handler, which fires right after this returns.
            self.viewModel.adoptTab(drag.tab, transitionInfoOverride: SuppressNavigationTransitionInfo())
            self.renderSelectedTab()
        }
    }

    private func configurePaneEvents() {
        navigationView.paneClosed.addHandler { [weak self] _, _ in
            self?.splitterBorder.visibility = .collapsed
        }
        navigationView.paneOpened.addHandler { [weak self] _, _ in
            self?.splitterBorder.visibility = .visible
        }
    }

    private func makeNavigationWrapper() -> Grid {
        let navWrapper = Grid()
        navWrapper.children.append(navigationView)
        splitterBorder = makeSplitterBorder()
        navWrapper.children.append(splitterBorder)
        try? Canvas.setZIndex(splitterBorder, 10)
        return navWrapper
    }
}
