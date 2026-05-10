import Foundation
import WinUI
@testable import RsUI

final class MockPage: RsUI.Page {
    let id: String

    init(id: String = UUID().uuidString) {
        self.id = id
    }

    var url: URL {
        URL(string: "rs://ui/mainwindow/test/\(id)")!
    }

    var content: WinUI.UIElement {
        WinUI.Grid()
    }
}
