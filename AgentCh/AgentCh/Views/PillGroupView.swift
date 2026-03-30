import SwiftUI

struct PillGroupView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var pillPosition: PillPosition
    @State private var isHovering = false

    private let compactMascotSize: CGFloat = 24
    private let expandedMascotSize: CGFloat = 20
    private let padding: CGFloat = 8
    private let spacing: CGFloat = 6

    var body: some View {
        ZStack(alignment: .top) {
            if !sessionManager.sessions.isEmpty {
                pillContent
                    .background(pillBackground)
                    .fixedSize()
                    .contentShape(Capsule())
                    .onHover { hovering in
                        withAnimation(.spring(duration: 0.3)) {
                            isHovering = hovering
                        }
                    }
                    .offset(pillPosition.offset)
                    .padding(.top, pillPosition.topPadding)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.opacity(0.0001))
    }

    @ViewBuilder
    private var pillContent: some View {
        if isHovering {
            expandedContent
        } else {
            compactContent
        }
    }

    // MARK: - Compact: single mascot + optional count badge

    @ViewBuilder
    private var compactContent: some View {
        HStack(spacing: 2) {
            // Show the most active session's mascot (thinking > idle > error)
            MascotView(
                agentType: primarySession.agentType,
                status: primarySession.status,
                size: compactMascotSize
            )

            if sessionManager.sessions.count > 1 {
                Text("×\(sessionManager.sessions.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, padding)
        .padding(.vertical, padding / 2)
    }

    // MARK: - Expanded: all sessions listed

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(sessionManager.sessions) { session in
                HStack(spacing: 6) {
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
        }
        .padding(.horizontal, padding)
        .padding(.vertical, padding / 2)
        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
    }

    /// The session to show in compact mode — prefer thinking over idle.
    private var primarySession: Session {
        sessionManager.sessions.first(where: { $0.status == .thinking })
            ?? sessionManager.sessions.first(where: { $0.status == .error })
            ?? sessionManager.sessions.first!
    }

    @ViewBuilder
    private var pillBackground: some View {
        if #available(macOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(.clear.interactive(), in: .capsule)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        }
    }
}
