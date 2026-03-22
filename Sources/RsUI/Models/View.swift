import Foundation
import WinUI

public protocol View: AnyObject {
    var header: Any? { get }
    var content: WinUI.UIElement { get }
}

public extension View {
    var header: Any? { nil }
}
