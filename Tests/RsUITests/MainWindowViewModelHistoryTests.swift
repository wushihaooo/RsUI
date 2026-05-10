import Testing
@testable import RsUI

@Suite
struct MainWindowViewModelHistoryTests {
    // Requirement: a fresh view model has no active tab and exposes empty legacy history arrays.
    @Test
    func initialStateHasNoSelectedPageOrHistory() {
        let viewModel = MainWindowViewModel()

        #expect(viewModel.tabs.isEmpty)
        #expect(viewModel.selectedTab == nil)
        #expect(viewModel.currentPage == nil)
        #expect(viewModel.backwardPages.isEmpty)
        #expect(viewModel.forwardPages.isEmpty)
    }

    // Requirement: the first navigation creates the selected tab and records the last page URL.
    @Test
    func firstNavigationCreatesSelectedTab() {
        let viewModel = MainWindowViewModel()
        let page = MockPage()

        viewModel.navigate(to: page)

        #expect(viewModel.tabs.count == 1)
        #expect(viewModel.selectedTab === viewModel.tabs.first)
        #expect(viewModel.currentPage === page)
        #expect(viewModel.backwardPages.isEmpty)
        #expect(viewModel.forwardPages.isEmpty)
        #expect(viewModel.routePreferences.lastPageURL == page.url)
    }

    // Requirement: normal in-tab navigation pushes the previous page onto that tab's back stack.
    @Test
    func navigateToDifferentPageAddsToBackHistory() {
        let viewModel = MainWindowViewModel()
        let page1 = MockPage()
        let page2 = MockPage()

        viewModel.navigate(to: page1)
        viewModel.navigate(to: page2)

        #expect(viewModel.currentPage === page2)
        #expect(viewModel.backwardPages.count == 1)
        #expect(viewModel.backwardPages[0] === page1)
        #expect(viewModel.forwardPages.isEmpty)
        #expect(viewModel.routePreferences.lastPageURL == page2.url)
    }

    // Requirement: navigating to the same page instance refreshes the selected tab without duplicating history.
    @Test
    func navigateToSamePageInstanceDoesNotDuplicateHistory() {
        let viewModel = MainWindowViewModel()
        let page = MockPage()

        viewModel.navigate(to: page)
        viewModel.navigate(to: page)

        #expect(viewModel.currentPage === page)
        #expect(viewModel.backwardPages.isEmpty)
        #expect(viewModel.forwardPages.isEmpty)
        #expect(viewModel.routePreferences.lastPageURL == page.url)
    }

    // Requirement: each tab's back stack honors the configured maximum history size.
    @Test
    func historyLimitIsEnforcedPerSelectedTab() {
        let viewModel = MainWindowViewModel()
        viewModel.routePreferences.maxHistoryPages = 2

        let page1 = MockPage()
        let page2 = MockPage()
        let page3 = MockPage()
        let page4 = MockPage()

        viewModel.navigate(to: page1)
        viewModel.navigate(to: page2)
        viewModel.navigate(to: page3)
        viewModel.navigate(to: page4)

        #expect(viewModel.backwardPages.count == 2)
        #expect(viewModel.backwardPages[0] === page2)
        #expect(viewModel.backwardPages[1] === page3)
        #expect(viewModel.currentPage === page4)
        #expect(viewModel.routePreferences.lastPageURL == page4.url)
    }

    // Requirement: back navigation moves the current page to the selected tab's forward stack.
    @Test
    func goBackMovesCurrentPageToForwardHistory() {
        let viewModel = MainWindowViewModel()
        let page1 = MockPage()
        let page2 = MockPage()

        viewModel.navigate(to: page1)
        viewModel.navigate(to: page2)
        viewModel.goBack()

        #expect(viewModel.currentPage === page1)
        #expect(viewModel.backwardPages.isEmpty)
        #expect(viewModel.forwardPages.count == 1)
        #expect(viewModel.forwardPages[0] === page2)
        #expect(viewModel.routePreferences.lastPageURL == page1.url)
    }

    // Requirement: back navigation is a no-op when the selected tab has no back history.
    @Test
    func goBackWithEmptyHistoryDoesNothing() {
        let viewModel = MainWindowViewModel()

        viewModel.goBack()

        #expect(viewModel.currentPage == nil)
        #expect(viewModel.backwardPages.isEmpty)
        #expect(viewModel.forwardPages.isEmpty)
    }

    // Requirement: forward navigation restores the most recent forward page and returns the current page to back history.
    @Test
    func goForwardRestoresForwardHistory() {
        let viewModel = MainWindowViewModel()
        let page1 = MockPage()
        let page2 = MockPage()
        let page3 = MockPage()
        let page4 = MockPage()

        viewModel.navigate(to: page1)
        viewModel.navigate(to: page2)
        viewModel.navigate(to: page3)
        viewModel.navigate(to: page4)
        viewModel.goBack()
        viewModel.goBack()
        viewModel.goForward()

        #expect(viewModel.currentPage === page3)
        #expect(viewModel.forwardPages.count == 1)
        #expect(viewModel.backwardPages.count == 2)
        #expect(viewModel.routePreferences.lastPageURL == page3.url)
    }

    // Requirement: forward navigation is a no-op when the selected tab has no forward history.
    @Test
    func goForwardWithEmptyHistoryDoesNothing() {
        let viewModel = MainWindowViewModel()
        let page = MockPage()

        viewModel.navigate(to: page)
        viewModel.goForward()

        #expect(viewModel.currentPage === page)
        #expect(viewModel.forwardPages.isEmpty)
        #expect(viewModel.routePreferences.lastPageURL == page.url)
    }

    // Requirement: a new in-tab navigation after going back clears stale forward history.
    @Test
    func navigationClearsForwardHistory() {
        let viewModel = MainWindowViewModel()
        let page1 = MockPage()
        let page2 = MockPage()
        let page3 = MockPage()

        viewModel.navigate(to: page1)
        viewModel.navigate(to: page2)
        viewModel.goBack()
        #expect(viewModel.forwardPages.count == 1)

        viewModel.navigate(to: page3)

        #expect(viewModel.forwardPages.isEmpty)
        #expect(viewModel.backwardPages.count == 1)
        #expect(viewModel.routePreferences.lastPageURL == page3.url)
    }
}
