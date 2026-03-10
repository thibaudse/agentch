import SwiftUI

@MainActor
final class IslandViewModel: ObservableObject {
    @Published var message: String = "Hello World"
    @Published var agentName: String = ""
    @Published var expanded: Bool = false
    @Published var geometry: NotchGeometry = .detect()

    func update(message: String, agentName: String, geometry: NotchGeometry) {
        self.message = message
        self.agentName = agentName
        self.geometry = geometry
    }
}
