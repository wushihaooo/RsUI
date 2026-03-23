import Foundation
import WinUI
import WinSDK
import RsHelper

/// 模块协议，定义了模块的标准接口
public protocol Module : ExpressibleByEmptyLiteral {
    /// 模块的唯一标识符
    var id: String { get }

    func register(in context: WindowContext)

    func registerNavigationViewItems(in context: WindowContext) -> [NavigationViewItemBase]

    func makeNavigationTarget(for selectedItemTag: Any, in context: WindowContext) -> View?
    func makeSettingsCard() -> UIElement?
}

public extension Module {
    func register(in context: WindowContext) {
    }

    func registerNavigationViewItems(in context: WindowContext) -> [NavigationViewItemBase] {
        return []
    }

    func makeNavigationTarget(for selectedItemTag: Any, in context: WindowContext) -> View? {
        return nil
    }

    func makeSettingsCard() -> UIElement? {
        return nil
    }
}
