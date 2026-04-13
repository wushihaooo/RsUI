import Foundation
import RsHelper

struct WindowPosition: Preferable {
    var windowWidth: Int = 1440
    var windowHeight: Int = 800
    var windowX: Int = 100
    var windowY: Int = 100
    var isMaximized: Bool = true
}

struct WindowLayout: Preferable {
    var navigationViewPaneOpen: Bool = true
    var navigationViewOpenPaneLength: Int = 320
}

struct RoutePreferences: Preferable {
    var maxHistoryPages: Int = 32
    var lastPageURL: URL? = nil
}
