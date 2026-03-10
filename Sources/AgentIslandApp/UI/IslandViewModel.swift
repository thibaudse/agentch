import SwiftUI

@MainActor
final class IslandViewModel: ObservableObject {
    @Published var message: String = ""
    @Published var agentName: String = ""
    @Published var expanded: Bool = false
    @Published var geometry: NotchGeometry = .detect()
    @Published var interactive: Bool = false
    @Published var inputText: String = ""

    var onSubmit: ((String) -> Void)?

    func update(message: String, agentName: String, geometry: NotchGeometry, interactive: Bool) {
        self.message = message
        self.agentName = agentName
        self.geometry = geometry
        self.interactive = interactive
        self.inputText = ""
    }

    func submit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSubmit?(text)
    }
}
