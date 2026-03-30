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
        // Invisible background so SwiftUI allocates the full frame for layout
        .background(Color.white.opacity(0.0001))
    }

    @ViewBuilder
    private var pillContent: some View {
        HStack(spacing: spacing) {
            ForEach(sessionManager.sessions) { session in
                HStack(spacing: 4) {
                    MascotView(
                        agentType: session.agentType,
                        status: session.status,
                        size: isHovering ? expandedMascotSize : compactMascotSize
                    )
                    if isHovering {
                        Text(session.label)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                    }
                }
            }
        }
        .padding(.horizontal, padding)
        .padding(.vertical, padding / 2)
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
