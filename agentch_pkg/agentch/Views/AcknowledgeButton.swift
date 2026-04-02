import SwiftUI

struct AcknowledgeButton: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(isHovered ? 0.2 : 0.1))

                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.orange.opacity(isHovered ? 1.0 : 0.6))
            }
            .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.15 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .cursor(.pointingHand)
    }
}
