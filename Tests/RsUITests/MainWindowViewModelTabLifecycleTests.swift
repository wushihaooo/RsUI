import Testing
@testable import RsUI

@Suite
struct MainWindowViewModelTabLifecycleTests {
    // Requirement: selecting an existing tab updates the current page, legacy history arrays, and last-page URL.
    @Test
    func selectExistingTabRestoresItsNavigationState() {
        let viewModel = MainWindowViewModel()
        let firstTabPage1 = MockPage()
        let firstTabPage2 = MockPage()
        let secondTabPage = MockPage()

        viewModel.navigate(to: firstTabPage1)
        let firstTab = viewModel.selectedTab!
        viewModel.navigate(to: firstTabPage2)
        viewModel.navigate(to: secondTabPage, inNewTab: true)

        viewModel.select(tab: firstTab)

        #expect(viewModel.selectedTab === firstTab)
        #expect(viewModel.currentPage === firstTabPage2)
        #expect(viewModel.backwardPages.count == 1)
        #expect(viewModel.backwardPages[0] === firstTabPage1)
        #expect(viewModel.routePreferences.lastPageURL == firstTabPage2.url)
    }

    // Requirement: selecting a tab that does not belong to this view model is ignored.
    @Test
    func selectUnknownTabDoesNothing() {
        let viewModel = MainWindowViewModel()
        let page = MockPage()
        let outsideTab = MainWindowTab(page: MockPage())

        viewModel.navigate(to: page)
        let selectedBefore = viewModel.selectedTab
        let revisionBefore = viewModel.navigationRevision
        viewModel.select(tab: outsideTab)

        #expect(viewModel.selectedTab === selectedBefore)
        #expect(viewModel.currentPage === page)
        #expect(viewModel.navigationRevision == revisionBefore)
    }

    // Requirement: closing the selected tab chooses the nearest remaining tab and publishes that tab's URL.
    @Test
    func closeSelectedTabSelectsNearestRemainingTab() {
        let viewModel = MainWindowViewModel()
        let page1 = MockPage()
        let page2 = MockPage()
        let page3 = MockPage()

        viewModel.navigate(to: page1)
        viewModel.navigate(to: page2, inNewTab: true)
        let tabToClose = viewModel.selectedTab!
        viewModel.navigate(to: page3, inNewTab: true)
        let expectedSelectedTab = viewModel.selectedTab!
        viewModel.select(tab: tabToClose)

        viewModel.close(tab: tabToClose)

        #expect(viewModel.tabs.count == 2)
        #expect(viewModel.selectedTab === expectedSelectedTab)
        #expect(viewModel.currentPage === page3)
        #expect(viewModel.routePreferences.lastPageURL == page3.url)
    }

    // Requirement: closing a background tab keeps the selected tab and current URL unchanged.
    @Test
    func closeUnselectedTabKeepsCurrentSelection() {
        let viewModel = MainWindowViewModel()
        let page1 = MockPage()
        let page2 = MockPage()

        viewModel.navigate(to: page1)
        let selectedTab = viewModel.selectedTab!
        let backgroundTab = viewModel.navigate(to: page2, inNewTab: true, switchToTab: false)

        viewModel.close(tab: backgroundTab)

        #expect(viewModel.tabs.count == 1)
        #expect(viewModel.selectedTab === selectedTab)
        #expect(viewModel.currentPage === page1)
        #expect(viewModel.routePreferences.lastPageURL == page1.url)
    }

    // Requirement: the view model never closes its last tab through the normal close command.
    @Test
    func closeLastTabIsIgnored() {
        let viewModel = MainWindowViewModel()
        let page = MockPage()

        viewModel.navigate(to: page)
        let onlyTab = viewModel.selectedTab!
        viewModel.close(tab: onlyTab)

        #expect(viewModel.tabs.count == 1)
        #expect(viewModel.selectedTab === onlyTab)
        #expect(viewModel.currentPage === page)
    }

    // Requirement: close-other-tabs keeps the selected tab and removes every sibling tab.
    @Test
    func closeOtherTabsKeepsSelectedTabOnly() {
        let viewModel = MainWindowViewModel()
        let page1 = MockPage()
        let page2 = MockPage()
        let page3 = MockPage()

        viewModel.navigate(to: page1)
        viewModel.navigate(to: page2, inNewTab: true)
        let selectedTab = viewModel.selectedTab!
        viewModel.navigate(to: page3, inNewTab: true, switchToTab: false)

        viewModel.closeOtherTabs()

        #expect(viewModel.tabs.count == 1)
        #expect(viewModel.tabs.first === selectedTab)
        #expect(viewModel.selectedTab === selectedTab)
        #expect(viewModel.currentPage === page2)
        #expect(viewModel.routePreferences.lastPageURL == page2.url)
    }
}
