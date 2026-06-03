import Foundation
import WindowsFoundation
import UWP
import WinAppSDK
import WinUI
import WinSDK
import RsHelper

// Manual tab tear-out with a browser-like (Edge/Chrome) drag model.
//
// Why not the framework drag: classic OLE drag (canDragTabs) shows the OS
// no-drop cursor the moment a tab leaves the strip, and native CanTearOutTabs
// flickers on every tab switch. Both framework paths are disabled; this owns the
// gesture instead.
//
// Why handlers live on a custom header element (not the TabViewItem): a
// TabViewItem is a ListViewItem and marks PointerPressed/Moved Handled for its
// own press/selection visuals, so a normal handler on the item never fires, and
// AddHandler(..., handledEventsToo: true) is unusable here (the Swift/WinRT
// binding wraps the handler with a generic AnyWrapper, not a real
// IPointerEventHandler delegate, so XAML can't invoke it). A handler on our own
// header element sees the event first during bubbling, before the item marks it
// Handled. That press only seeds the gesture; everything after runs off a timer
// polling GetCursorPos + GetAsyncKeyState, so it survives the strip rebuilding
// (live reorder) and the pointer leaving the window (tear-out).
//
// Drag model (three phases):
//  - pending:    pressed, waiting to pass the move threshold.
//  - reordering: cursor in the source strip band → the dragged tab slides within
//                the strip (the model is reordered live; the tab stays a real
//                strip item; the source window is otherwise untouched).
//  - tearing:    cursor pulled off the strip → the tab leaves the strip and a
//                small preview chip follows the cursor. Re-entering the strip
//                drops back to reordering. On release: over another window's
//                strip → merge; over the source strip → settle back; elsewhere →
//                a new window at the drop point.
//
// The preview chip is a single reused borderless window, shown with
// AppWindow.show(false) so it never steals focus — that focus-steal was the
// flicker at drag start.
//
// Coordinate note: GetCursorPos and AppWindow.position/size/move are physical
// screen pixels; XAML transforms/sizes are DIPs. Slot math multiplies DIPs by
// the XamlRoot rasterization scale to compare against the physical cursor.
final class TabTearGesture {
    static let shared = TabTearGesture()

    private enum Phase { case pending, active }
    private var phase: Phase?
    // The window currently holding the tab during the drag: it lives in whatever
    // window's strip the cursor is over, and is nil while torn out (preview
    // following). The tab always occupies exactly one place — a strip slot or the
    // preview — so reorder / live cross-window merge / tear-out are one model.
    private weak var holder: MainWindow?
    private var tab: MainWindowTab?
    private var tabTitle: String = ""
    private weak var capturedElement: UIElement?
    private var capturedPointer: Pointer?
    private var startX: Int32 = 0
    private var startY: Int32 = 0
    private var timer: WinAppSDK.DispatcherQueueTimer?

    // Reused preview chip (created once, hidden between drags).
    private var previewWindow: Window?
    private var previewLabel: TextBlock?

    // px the pointer must move before the gesture leaves the pending phase.
    private let threshold: Int32 = 8
    private let previewWidth: Int32 = 220
    private let previewHeight: Int32 = 40
    private let grabX: Int32 = 36
    private let grabY: Int32 = 20

    func onPressed(window: MainWindow, tab: MainWindowTab, element: UIElement, args: PointerRoutedEventArgs) {
        guard phase == nil else { return }
        guard (window.viewModel?.tabs.count ?? 0) > 1 else {
            log.info("[Tear] pressed ignored — only one tab")
            return
        }
        var pt = POINT(); _ = GetCursorPos(&pt)
        phase = .pending
        holder = window
        self.tab = tab
        tabTitle = window.tabTitlesByID[ObjectIdentifier(tab)] ?? ""
        startX = pt.x
        startY = pt.y
        capturedElement = element
        capturedPointer = args.pointer
        _ = try? element.capturePointer(args.pointer)
        startTimer(on: window)
        log.info("[Tear] pressed start=(\(pt.x),\(pt.y))")
    }

    // A fast click (press + release without crossing the threshold) ends here so
    // selection isn't delayed; drags end via the timer's button-up check.
    func onReleased(args: PointerRoutedEventArgs) {
        if phase == .pending { stop() }
    }

    private func startTimer(on window: MainWindow) {
        let t = (try? window.dispatcherQueue?.createTimer()) ?? nil
        t?.interval = TimeSpan(duration: 160_000)  // ~16ms
        t?.tick.addHandler { [weak self] _, _ in self?.tick() }
        try? t?.start()
        timer = t
    }

    private func tick() {
        guard let phase, let tab else { stop(); return }
        var pt = POINT(); _ = GetCursorPos(&pt)
        let buttonDown = (UInt16(bitPattern: GetAsyncKeyState(0x01)) & 0x8000) != 0
        if !buttonDown {
            finish(at: pt)
            return
        }

        if phase == .pending {
            if abs(pt.x - startX) + abs(pt.y - startY) < threshold { return }
            self.phase = .active
            releaseCapture()  // from here the timer drives everything
            log.info("[Tear] -> active")
        }

        // The window whose strip band the cursor is over (nil → torn out).
        let target = MainWindow.windowUnderCursor(pt, excluding: nil)
            .flatMap { $0.cursorInTabStripBand(pt) ? $0 : nil }

        if let target {
            if holder == nil {
                // Was torn out → drop the tab back into a strip (the preview ends).
                hidePreview()
                liveInsert(tab, into: target, at: pt)
                log.info("[Tear] adopt from preview -> id=\(target.appWindow?.id.value ?? 0)")
            } else if holder !== target {
                // Dragged from one window's strip straight into another's.
                holder?.viewModel.detachTab(tab)
                holder?.renderSelectedTab()
                liveInsert(tab, into: target, at: pt)
                log.info("[Tear] cross-window -> id=\(target.appWindow?.id.value ?? 0)")
            } else {
                // Reorder within the current window. Only mutate the model and let
                // its change drive an async, coalesced reconcile. Calling
                // renderSelectedTab synchronously every tick rapid-fires
                // syncTabItems (removeAt/insertAt), which hits the "two parents"
                // WinRT path and stalls the strip until the next click.
                target.viewModel.move(tab, to: target.tabInsertIndex(forCursorX: pt.x))
            }
            holder = target
        } else {
            // Over no strip → the tab leaves its window and the preview follows.
            if let from = holder {
                from.viewModel.detachTab(tab)
                from.renderSelectedTab()
                showPreview(title: tabTitle, at: pt)
                holder = nil
                log.info("[Tear] -> torn out (preview)")
            } else {
                movePreview(to: pt)
            }
        }
    }

    // Inserts the tab into a window's strip at the cursor slot. adoptTab no-ops if
    // the tab is already there, so a fresh tabInsertIndex move keeps it tracking.
    private func liveInsert(_ tab: MainWindowTab, into window: MainWindow, at pt: POINT) {
        window.viewModel.adoptTab(tab, at: window.tabInsertIndex(forCursorX: pt.x),
                                  transitionInfoOverride: SuppressNavigationTransitionInfo())
        window.renderSelectedTab()
    }

    private func finish(at pt: POINT) {
        defer { stop() }
        guard phase == .active, let tab else { return }
        // If still over a strip the tab already lives there at the right slot;
        // only a release over empty space needs a window made for it.
        if holder == nil {
            log.info("[Tear] finish -> new window")
            let torn = MainWindow.makeTornWindow(transferring: tab)
            torn.moveFollow(toCursor: pt, offsetX: grabX, offsetY: grabY)
        }
    }

    private func stop() {
        try? timer?.stop()
        timer = nil
        hidePreview()
        releaseCapture()
        phase = nil
        holder = nil
        tab = nil
        tabTitle = ""
    }

    private func releaseCapture() {
        if let element = capturedElement, let pointer = capturedPointer {
            try? element.releasePointerCapture(pointer)
        }
        capturedElement = nil
        capturedPointer = nil
    }

    // MARK: - Preview chip (reused, focus-stealing-free)

    private func showPreview(title: String, at pt: POINT) {
        let window = ensurePreview()
        previewLabel?.text = title.isEmpty ? " " : title
        guard let aw = window.appWindow else { return }
        try? aw.move(PointInt32(x: pt.x - grabX, y: pt.y - grabY))
        try? aw.show(false)  // show without activating — no focus steal, no flicker
    }

    private func movePreview(to pt: POINT) {
        if let aw = previewWindow?.appWindow {
            try? aw.move(PointInt32(x: pt.x - grabX, y: pt.y - grabY))
        }
    }

    private func hidePreview() {
        try? previewWindow?.appWindow?.hide()
    }

    private func ensurePreview() -> Window {
        if let window = previewWindow { return window }
        // Tab-shaped chip: a favicon-style glyph + the title, themed so it reads
        // as a real tab lifted out of the strip.
        let dark = App.context.theme.isDark
        let bg = dark ? UWP.Color(a: 252, r: 50, g: 50, b: 54)
                      : UWP.Color(a: 252, r: 251, g: 251, b: 253)
        let fg = dark ? UWP.Color(a: 255, r: 236, g: 236, b: 240)
                      : UWP.Color(a: 255, r: 28, g: 28, b: 30)
        let stroke = dark ? UWP.Color(a: 70, r: 255, g: 255, b: 255)
                          : UWP.Color(a: 28, r: 0, g: 0, b: 0)

        let icon = FontIcon()
        icon.glyph = "\u{E8A5}"  // Document
        icon.fontSize = 14
        icon.foreground = SolidColorBrush(fg)

        let label = TextBlock()
        label.foreground = SolidColorBrush(fg)
        label.fontSize = 13
        label.verticalAlignment = .center

        let row = StackPanel()
        row.orientation = .horizontal
        row.spacing = 8
        row.verticalAlignment = .center
        row.margin = Thickness(left: 12, top: 0, right: 12, bottom: 0)
        row.children.append(icon)
        row.children.append(label)

        let chip = Border()
        chip.background = SolidColorBrush(bg)
        chip.cornerRadius = CornerRadius(topLeft: 7, topRight: 7, bottomRight: 7, bottomLeft: 7)
        chip.borderBrush = SolidColorBrush(stroke)
        chip.borderThickness = Thickness(left: 1, top: 1, right: 1, bottom: 1)
        chip.child = row

        let window = Window()
        window.content = chip
        try? window.activate()  // realize once; hidden immediately below
        if let aw = window.appWindow {
            if let presenter = aw.presenter as? OverlappedPresenter {
                try? presenter.setBorderAndTitleBar(false, false)
                presenter.isResizable = false
            }
            try? aw.resize(SizeInt32(width: previewWidth, height: previewHeight))
            try? aw.hide()
        }
        previewWindow = window
        previewLabel = label
        return window
    }
}

extension MainWindow {
    // MARK: - Tear-out geometry + window registry

    // Live windows, weakly held, so the gesture can hit-test which window the
    // cursor is over on release without leaking closed windows.
    final class WeakWindowRef {
        weak var window: MainWindow?
        init(_ window: MainWindow) { self.window = window }
    }
    static var liveWindows: [WeakWindowRef] = []

    static func register(_ window: MainWindow) {
        liveWindows.removeAll { $0.window == nil }
        liveWindows.append(WeakWindowRef(window))
    }

    static func unregister(_ window: MainWindow) {
        liveWindows.removeAll { $0.window == nil || $0.window === window }
    }

    // Opens a real window seeded with a torn tab (history preserved) and returns
    // it so the gesture can place it at the drop point.
    static func makeTornWindow(transferring tab: MainWindowTab) -> MainWindow {
        let window = MainWindow()
        window.initialTransferredTab = tab
        try? window.activate()
        return window
    }

    func moveFollow(toCursor pt: POINT, offsetX: Int32, offsetY: Int32) {
        try? appWindow?.move(PointInt32(x: pt.x - offsetX, y: pt.y - offsetY))
    }

    // The live window whose screen rect contains the cursor (newest first ≈
    // topmost), excluding the given window.
    static func windowUnderCursor(_ pt: POINT, excluding: MainWindow?) -> MainWindow? {
        for box in liveWindows.reversed() {
            guard let w = box.window, w !== excluding,
                  w.viewModel != nil, let aw = w.appWindow else { continue }
            let pos = aw.position
            let size = aw.size
            if pt.x >= pos.x, pt.x < pos.x + size.width,
               pt.y >= pos.y, pt.y < pos.y + size.height {
                return w
            }
        }
        return nil
    }

    // The cursor is "in the tab strip" when it is within the window horizontally
    // and within the top band (title bar + strip). A physical-pixel band avoids
    // needing the strip's exact rect (which collapses to zero at one tab) and any
    // DPI conversion for the boundary.
    func cursorInTabStripBand(_ pt: POINT) -> Bool {
        guard let aw = appWindow else { return false }
        let pos = aw.position
        let size = aw.size
        let bandHeight: Int32 = 92
        return pt.x >= pos.x && pt.x < pos.x + size.width
            && pt.y >= pos.y && pt.y < pos.y + bandHeight
    }

    // The slot a tab dragged to cursorX should occupy, decided by each tab item's
    // physical-pixel mid-point (item DIP offset/width scaled by the XamlRoot DPI).
    func tabInsertIndex(forCursorX x: Int32) -> Int {
        guard let aw = appWindow else { return 0 }
        let scale = tabView.xamlRoot?.rasterizationScale ?? 1.0
        for (idx, tab) in viewModel.tabs.enumerated() {
            guard let item = tabItemsByID[ObjectIdentifier(tab)],
                  let transform = try? item.transformToVisual(nil) else { continue }
            let origin = (try? transform.transformPoint(Point(x: 0, y: 0))) ?? Point(x: 0, y: 0)
            let left = aw.position.x + Int32(Double(origin.x) * scale)
            let width = Int32(item.actualWidth * scale)
            if x < left + width / 2 { return idx }
        }
        return max(0, viewModel.tabs.count - 1)
    }
}
