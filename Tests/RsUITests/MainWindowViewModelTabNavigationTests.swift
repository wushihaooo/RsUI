import Testing
@testable import RsUI

@Suite
struct MainWindowViewModelTabNavigationTests {
    // Requirement: normal navigation stays in the current tab and appends the previous page to that tab's back stack.
    @Test
    func navigateInCurrentTabKeepsOneTabAndAddsCurrentTabHistory() {
        let viewModel = MainWindowViewModel()
        let page1 = MockPage()
        let page2 = MockPage()

        viewModel.navigate(to: page1)
        let firstTab = viewModel.selectedTab
        viewModel.navigate(to: page2)

        #expect(viewModel.tabs.count == 1)
        #expect(viewModel.selectedTab === firstTab)
        #expect(viewModel.currentPage === page2)
        #expect(viewModel.backwardPages.count == 1)
        #expect(viewModel.backwardPages[0] === page1)
    }

    // Requirement: foreground new-tab navigation creates and selects a separate tab with an empty history stack.
    @Test
    func navigateInNewTabCreatesIndependentSelectedTab() {
        let viewModel = MainWindowViewModel()
        let page1 = MockPage()
        let page2 = MockPage()

        viewModel.navigate(to: page1)
        let firstTab = viewModel.selectedTab
        viewModel.navigate(to: page2, inNewTab: true)
        let secondTab = viewModel.selectedTab

        #expect(viewModel.tabs.count == 2)
        #expect(firstTab !== secondTab)
        #expect(firstTab?.currentPage === page1)
        #expect(secondTab?.currentPage === page2)
        #expect(secondTab?.backwardPages.isEmpty == true)
        #expect(secondTab?.forwardPages.isEmpty == true)
        #expect(viewModel.routePreferences.lastPageURL == page2.url)
    }

    // Requirement: background new-tab navigation creates a tab without changing the selected tab or last-page preference.
    @Test
    func navigateInBackgroundNewTabDoesNotChangeSelection() {
        let viewModel = MainWindowViewModel()
        let page1 = MockPage()
        let page2 = MockPage()

        viewModel.navigate(to: page1)
        let selectedBeforeBackgroundOpen = viewModel.selectedTab
        let backgroundTab = viewModel.navigate(to: page2, inNewTab: true, switchToTab: false)

        #expect(viewModel.tabs.count == 2)
        #expect(viewModel.selectedTab === selectedBeforeBackgroundOpen)
        #expect(viewModel.currentPage === page1)
        #expect(backgroundTab.currentPage === page2)
        #expect(viewModel.routePreferences.lastPageURL == page1.url)
    }

    // Requirement: the same URL can be opened in multiple independent tabs, matching browser duplicate-tab behavior.
    @Test
    func navigateSameURLInNewTabCreatesDuplicateIndependentTab() {
        let viewModel = MainWindowViewModel()
        let page1 = MockPage(id: "same-url")
        let page2 = MockPage(id: "same-url")

        viewModel.navigate(to: page1)
        let firstTab = viewModel.selectedTab
        viewModel.navigate(to: page2, inNewTab: true)
        let secondTab = viewModel.selectedTab

        #expect(viewModel.tabs.count == 2)
        #expect(firstTab !== secondTab)
        #expect(firstTab?.currentPage === page1)
        #expect(secondTab?.currentPage === page2)
        #expect(firstTab?.currentPage?.url == secondTab?.currentPage?.url)
    }

    // Requirement: switching tabs restores each tab's own back and forward history without sharing state.
    @Test
    func eachTabKeepsItsOwnBackForwardHistory() {
        let viewModel = MainWindowViewModel()
        let tab1Page1 = MockPage()
        let tab1Page2 = MockPage()
        let tab2Page1 = MockPage()
        let tab2Page2 = MockPage()

        viewModel.navigate(to: tab1Page1)
        let firstTab = viewModel.selectedTab!
        viewModel.navigate(to: tab1Page2)

        viewModel.navigate(to: tab2Page1, inNewTab: true)
        let secondTab = viewModel.selectedTab!
        viewModel.navigate(to: tab2Page2)
        viewModel.goBack()

        viewModel.select(tab: firstTab)
        #expect(viewModel.currentPage === tab1Page2)
        #expect(viewModel.backwardPages.count == 1)
        #expect(viewModel.backwardPages[0] === tab1Page1)
        #expect(viewModel.forwardPages.isEmpty)

        viewModel.select(tab: secondTab)
        #expect(viewModel.currentPage === tab2Page1)
        #expect(viewModel.backwardPages.isEmpty)
        #expect(viewModel.forwardPages.count == 1)
        #expect(viewModel.forwardPages[0] === tab2Page2)
    }
}
