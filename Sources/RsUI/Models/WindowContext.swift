import Foundation
import WinAppSDK
import WinSDK

/// 模块所附窗口上下文信息
public struct WindowContext {
    let hwnd: AppWindow

    func pickFolder(_ handler: @escaping (String) -> Void) {
        Task {
            let picker = FolderPicker(hwnd.id)
            guard let asyncResult = try? picker.pickSingleFolderAsync() else { return }
            guard let result = try? await asyncResult.get() else { return }

            await MainActor.run {
                handler(result.path)
            }
        }
    }
}
