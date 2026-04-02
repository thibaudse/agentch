import SwiftUI

struct JumpButton: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.primary.opacity(isHovered ? 0.15 : 0.06))

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.primary.opacity(isHovered ? 1.0 : 0.5))
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

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
