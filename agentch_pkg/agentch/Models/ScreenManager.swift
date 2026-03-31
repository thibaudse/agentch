import AppKit
import SwiftUI

extension Notification.Name {
    static let agentChScreenChanged = Notification.Name("agentChScreenChanged")
}

@MainActor
final class ScreenManager: ObservableObject {
    @AppStorage("selectedScreenIndex") private var storedIndex: Int = 0

    @Published var selectedScreenIndex: Int = 0 {
        didSet {
            storedIndex = selectedScreenIndex
            NotificationCenter.default.post(name: .agentChScreenChanged, object: nil)
        }
    }

    var selectedScreen: NSScreen {
        let screens = NSScreen.screens
        let index = min(selectedScreenIndex, screens.count - 1)
        return screens.indices.contains(index) ? screens[index] : (NSScreen.main ?? screens[0])
    }

    var screenNames: [(index: Int, name: String)] {
        NSScreen.screens.enumerated().map { index, screen in
            let name = screen.localizedName
            let isMain = screen == NSScreen.main
            return (index, isMain ? "\(name) (Main)" : name)
        }
    }

    @Published var screenCount: Int = NSScreen.screens.count

    init() {
        selectedScreenIndex = storedIndex
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.screenCount = NSScreen.screens.count
                // Clamp index if a screen was removed
                if let self, self.selectedScreenIndex >= NSScreen.screens.count {
                    self.selectedScreenIndex = 0
                }
            }
        }
    }
}
