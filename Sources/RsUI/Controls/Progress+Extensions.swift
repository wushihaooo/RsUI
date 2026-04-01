import Foundation
import Observation
import WinUI

/// NOTE: Must inherit ProgressRing/Bar, otherwise can't be triggered the second change of the observation
public class ProgressRingEx: ProgressRing {
}

public extension ProgressRingEx {
       func startObserving<Element>(_ emit: @escaping @Sendable () -> Element, onChanged: @escaping @MainActor (ProgressRing, Element) -> Void) {
        let obs = Observations(emit)

        Task { [weak self] in
            for await value in obs {
                /// NOTE: self is nil after the first change of the observation.
                /// Does the ring pointer released?
                /// Why NavigationViewItem works in this case?
                guard let self else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    onChanged(self, value)
                }
            }
        }
    }
}

public class ProgressBarEx: ProgressBar {
}

public extension ProgressBarEx {
       func startObserving<Element>(_ emit: @escaping @Sendable () -> Element, onChanged: @escaping @MainActor (ProgressBar, Element) -> Void) {
        let obs = Observations(emit)

        Task { [weak self] in
            for await value in obs {
                guard let self else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    onChanged(self, value)
                }
            }
        }
    }
}
