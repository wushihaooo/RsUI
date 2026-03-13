import Foundation
import UWP
import WinUI
import RsUI

final class ClockPage: AppPage {
    private let root = WinUI.Grid()
    private let timeLabel = TextBlock()
    private let dateLabel = TextBlock()
    private var timer: DispatchSourceTimer?
    private var timeOffset: TimeInterval = 0

    var rootView: WinUI.UIElement { root }

    func adjustTime(by seconds: TimeInterval) {
        timeOffset += seconds
        updateTime()
    }

    func resetTime() {
        timeOffset = 0
        updateTime()
    }

    init() {
        setupUI()
        startTimer()
    }

    deinit {
        timer?.cancel()
    }

    func onAppearanceChanged() {
        updateColors()
    }

    private func setupUI() {
        root.horizontalAlignment = .stretch
        root.verticalAlignment = .stretch

        let container = StackPanel()
        container.horizontalAlignment = .center
        container.verticalAlignment = .center
        container.spacing = 16

        timeLabel.fontSize = 72
        timeLabel.fontWeight = FontWeights.bold
        timeLabel.horizontalAlignment = .center
        container.children.append(timeLabel)

        dateLabel.fontSize = 24
        dateLabel.horizontalAlignment = .center
        container.children.append(dateLabel)

        root.children.append(container)
        updateColors()
        updateTime()
    }

    private func updateColors() {
        let color = App.context.theme.isDark ?
            UWP.Color(a: 255, r: 255, g: 255, b: 255) :
            UWP.Color(a: 255, r: 0, g: 0, b: 0)
        timeLabel.foreground = SolidColorBrush(color)
        dateLabel.foreground = SolidColorBrush(color)
    }

    private func startTimer() {
        timer = DispatchSource.makeTimerSource(queue: .main)
        timer?.schedule(deadline: .now(), repeating: 1.0)
        timer?.setEventHandler { [weak self] in
            self?.updateTime()
        }
        timer?.resume()
    }

    private func updateTime() {
        let adjustedDate = Date().addingTimeInterval(timeOffset)

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        timeLabel.text = formatter.string(from: adjustedDate)

        formatter.dateFormat = "yyyy-MM-dd EEEE"
        dateLabel.text = formatter.string(from: adjustedDate)
    }
}
