import Testing
@testable import RsUI

@Suite
struct MainWindowViewModelTabTransferTests {
    // Requirement: detaching a background tab removes it without disturbing the selected tab.
    @Test
    func detachUnselectedTabKeepsSelection() {
        let viewModel = MainWindowViewModel()
        let page1 = MockPage()
        let page2 = MockPage()

        viewModel.navigate(to: page1)
        let selectedTab = viewModel.selectedTab!
        let detachedTab = viewModel.navigate(to: page2, inNewTab: true, switchToTab: false)

        viewModel.detachTab(detachedTab)

        #expect(viewModel.tabs.count == 1)
        #expect(viewModel.selectedTab === selectedTab)
        #expect(viewModel.currentPage === page1)
        #expect(viewModel.routePreferences.lastPageURL == page1.url)
    }

    // Requirement: detaching the selected tab is allowed even when it leaves the view model empty.
    @Test
    func detachOnlySelectedTabLeavesNoSelection() {
        let viewModel = MainWindowViewModel()
        let page = MockPage()

        viewModel.navigate(to: page)
        let onlyTab = viewModel.selectedTab!
        viewModel.detachTab(onlyTab)

        #expect(viewModel.tabs.isEmpty)
        #expect(viewModel.selectedTab == nil)
        #expect(viewModel.currentPage == nil)
        #expect(viewModel.backwardPages.isEmpty)
        #expect(viewModel.forwardPages.isEmpty)
        #expect(viewModel.routePreferences.lastPageURL == nil)
    }

    // Requirement: detaching the selected tab falls back to the nearest remaining tab.
    @Test
    func detachSelectedTabSelectsNearestRemainingTab() {
        let viewModel = MainWindowViewModel()
        let page1 = MockPage()
        let page2 = MockPage()
        let page3 = MockPage()

        viewModel.navigate(to: page1)
        viewModel.navigate(to: page2, inNewTab: true)
        let tabToDetach = viewModel.selectedTab!
        viewModel.navigate(to: page3, inNewTab: true)
        let expectedSelectedTab = viewModel.selectedTab!
        viewModel.select(tab: tabToDetach)

        viewModel.detachTab(tabToDetach)

        #expect(viewModel.tabs.count == 2)
        #expect(viewModel.selectedTab === expectedSelectedTab)
        #expect(viewModel.currentPage === page3)
        #expect(viewModel.routePreferences.lastPageURL == page3.url)
    }

    // Requirement: a transferred tab seeds a new view model, becomes selected, and is marked for rendering.
    @Test
    func setTransferredTabSeedsSingleSelectedRenderableTab() {
        let sourceViewModel = MainWindowViewModel()
        let destinationViewModel = MainWindowViewModel()
        let page1 = MockPage()
        let page2 = MockPage()

        sourceViewModel.navigate(to: page1)
        let transferredTab = sourceViewModel.selectedTab!
        transferredTab.needsRender = false
        transferredTab.navigate(to: page2, maxHistoryPages: sourceViewModel.routePreferences.maxHistoryPages)

        destinationViewModel.setTransferredTab(transferredTab)

        #expect(destinationViewModel.tabs.count == 1)
        #expect(destinationViewModel.selectedTab === transferredTab)
        #expect(destinationViewModel.currentPage === page2)
        #expect(destinationViewModel.backwardPages.count == 1)
        #expect(destinationViewModel.backwardPages[0] === page1)
        #expect(destinationViewModel.routePreferences.lastPageURL == page2.url)
        #expect(transferredTab.needsRender == true)
    }
}
