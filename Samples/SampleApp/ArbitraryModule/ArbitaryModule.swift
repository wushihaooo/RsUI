import Foundation
import Observation
import WindowsFoundation
import UWP
import WinUI
import RsUI
import RsHelper

func tr(_ keyAndValue: String) -> String {
    return App.context.language == .zh_CN ? "翻译\(keyAndValue)" : keyAndValue
}

@Observable
final class ArbitaryModule: Module {
    let id = "arbitrary"
    var state = "loading"
    
    init() {
        log.info("ArbitaryModule init")
    }
    deinit {
        log.info("ArbitaryModule deinit")
    }

    func titleBarRightHeaderItemRequired(in context: WindowContext) -> UIElement? {
        let ring = ProgressRingEx()
        ring.startObserving { [weak self] in
            self?.state
        } onChanged: { ring, value in
            ring.isActive = value == "loading"
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            self?.state = ""
        }

        return ring
    }

    func navigationViewMenuItemsRequired(in context: WindowContext) -> [NavigationViewItemBase] {
        let header = NavigationViewItemHeader()
        header.content = tr("Header")
        let navigationViewItem = NavigationViewItem.build(
            iconGlyph: "\u{E7C3}",
            label: tr("Arbitrary"),
            url: "rs://\(id)",
            actionGlyph: "\u{E8F4}",
            actionTooltip: tr("actionTooltip"),
            actionHandler: { _, _ in
                context.pickFolder {
                    print($0)
                }
            }
        )
        let sep = NavigationViewItemSeparator()
        return [header, navigationViewItem, sep]
    }

    func navigationViewFooterMenuItemsRequired(in context: WindowContext) -> [NavigationViewItemBase] {
        let header = NavigationViewItemHeader()
        header.content = tr("Footer")
        let navigationViewItem = NavigationViewItem.build(
            iconGlyph: "\u{E7C3}",
            label: tr("Arbitrary"),
            url: "rs://\(id)",
            actionGlyph: "\u{E8F4}",
            actionTooltip: tr("actionTooltip"),
            actionHandler: { _, _ in
                context.pickFolder {
                    print($0)
                }
            }
        )
        let sep = NavigationViewItemSeparator()
        return [sep, header, navigationViewItem]
    }

    func settingsGroupRequired() -> (title: String, cards: [UIElement])? {
        let toggle = WinUI.ToggleSwitch()
        toggle.isOn = true
        toggle.onContent = tr("toggleOn")
        toggle.offContent = tr("toggleOff")

        let card = SettingsCard("\u{E70A}", tr("metadataTitle"), tr("metadataDescription"), toggle)
        return (tr("Arbitrary Settings"), [card])
    }
    
    func navigationRequested(for url: URL, in context: WindowContext) -> RsUI.Page? {
        guard url.host == self.id else { return nil }
        return ArbitaryPage()
    }
}
