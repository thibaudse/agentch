import SwiftUI

struct PillGroupView: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var isHovering = false
    @State private var dragOffset: CGSize = .zero
    @State private var position: CGPoint = .zero
    @State private var hasSetInitialPosition = false

    private let compactMascotSize: CGFloat = 24
    private let expandedMascotSize: CGFloat = 20
    private let padding: CGFloat = 8
    private let spacing: CGFloat = 6

    var body: some View {
        if !sessionManager.sessions.isEmpty {
            pillContent
                .background(pillBackground)
                .onHover { hovering in
                    withAnimation(.spring(duration: 0.3)) {
                        isHovering = hovering
                    }
                }
                .gesture(dragGesture)
                .position(currentPosition)
                .onAppear {
                    if !hasSetInitialPosition {
                        loadOrDefaultPosition()
                        hasSetInitialPosition = true
                    }
                }
                .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var pillContent: some View {
        HStack(spacing: spacing) {
            ForEach(sessionManager.sessions) { session in
                if isHovering {
                    expandedPill(for: session)
                } else {
                    MascotView(
                        agentType: session.agentType,
                        status: session.status,
                        size: compactMascotSize
                    )
                }
            }
        }
        .padding(.horizontal, padding)
        .padding(.vertical, padding / 2)
    }

    @ViewBuilder
    private func expandedPill(for session: Session) -> some View {
        HStack(spacing: 4) {
            MascotView(
                agentType: session.agentType,
                status: session.status,
                size: expandedMascotSize
            )
            Text(session.label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var pillBackground: some View {
        if #available(macOS 26.0, *) {
            Capsule()
                .fill(.ultraThinMaterial)
                .glassEffect(.regular.interactive(), in: .capsule)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                position.x += value.translation.width
                position.y += value.translation.height
                dragOffset = .zero
                savePosition()
            }
    }

    private var currentPosition: CGPoint {
        CGPoint(
            x: position.x + dragOffset.width,
            y: position.y + dragOffset.height
        )
    }

    private func loadOrDefaultPosition() {
        if let savedX = UserDefaults.standard.object(forKey: "pillPositionX") as? CGFloat,
           let savedY = UserDefaults.standard.object(forKey: "pillPositionY") as? CGFloat {
            position = CGPoint(x: savedX, y: savedY)
        } else {
            if let screen = NSScreen.main {
                position = CGPoint(
                    x: screen.frame.midX,
                    y: screen.frame.maxY - screen.safeAreaInsets.top - 30
                )
            }
        }
    }

    private func savePosition() {
        UserDefaults.standard.set(position.x, forKey: "pillPositionX")
        UserDefaults.standard.set(position.y, forKey: "pillPositionY")
    }
}
