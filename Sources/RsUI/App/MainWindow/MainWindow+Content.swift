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

        // Native tear-out (CanTearOutTabs). The OS owns the drag visuals and the
        // window-follow animation; these four handlers only move our model (the
        // MainWindowTab + its decoupled content frame) between windows. The tab in
        // flight is tracked in MainWindow.pendingTearOut, and the receiver window
        // is resolved from THERE — args.newWindowId round-trips as 0 in the
        // Swift/WinRT binding (the put_NewWindowId setter doesn't marshal).

        // (1) A tab is being torn out and needs a window to land in. The framework
        // over-fires this within one drag (incl. speculative tears it never
        // commits), so tearOutReceiver() reuses one empty spare instead of
        // leaking a window per call.
        tabView.tabTearOutWindowRequested.addHandler { [weak self] _, args in
            guard let self, let args else { return }
            // WinUI selects the pressed tab before the tear begins, so the
            // selected tab is the one being torn out.
            guard let tab = self.viewModel.selectedTab else { return }
            let receiver = MainWindow.tearOutReceiver()
            MainWindow.pendingTearOut = MainWindow.PendingTearOut(
                tab: tab, holder: self, receiver: receiver
            )
            args.newWindowId = receiver.appWindow.id
            log.info("[TearOut] windowRequested receiver=\(receiver.appWindow.id.value)")
        }

        // (2) Commit the tear: move the torn tab from its holder into the
        // receiver. Once moved, the spare is no longer empty, so release it.
        tabView.tabTearOutRequested.addHandler { _, _ in
            guard var pending = MainWindow.pendingTearOut,
                  pending.holder !== pending.receiver else { return }
            log.info("[TearOut] tearOutRequested -> receiver")
            pending.holder.releaseTab(pending.tab)
            pending.receiver.adoptTornTab(pending.tab)
            pending.holder = pending.receiver
            MainWindow.pendingTearOut = pending
            MainWindow.spareReceiver = nil
        }

        // (3) A torn tab from another window is dragged over this strip — accept.
        tabView.externalTornOutTabsDropping.addHandler { _, args in
            guard let args, MainWindow.pendingTearOut != nil else { return }
            args.allowDrop = true
        }

        // (4) Merge: pull the torn tab from its current holder into this window at
        // dropIndex, then discard the now-empty floating receiver.
        tabView.externalTornOutTabsDropped.addHandler { [weak self] _, args in
            guard let self, let args, let pending = MainWindow.pendingTearOut else { return }
            let index = Int(args.dropIndex)
            log.info("[TearOut] dropped(merge) index=\(index)")
            pending.holder.releaseTab(pending.tab)
            self.adoptTornTab(pending.tab, at: index)
            if pending.receiver !== self {
                pending.receiver.closeIfEmpty()
            }
            MainWindow.pendingTearOut = nil
        }

        // In-window reorder has no per-event hook with native tear-out: the
        // framework moves the strip item directly. Persist the new order to the
        // model when a drag ends (harmless no-op after a tear-off, where the
        // strip and model already match).
        tabView.tabDragCompleted.addHandler { [weak self] _, _ in
            self?.syncTabOrderFromStrip()
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
