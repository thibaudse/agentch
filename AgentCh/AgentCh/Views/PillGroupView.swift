import SwiftUI

struct PillGroupView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var screenManager: ScreenManager
    @State private var isHovering = false
    @State private var dragOffset: CGSize = .zero
    @State private var pillOffset: CGSize = .zero

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
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                pillOffset.width += value.translation.width
                                pillOffset.height += value.translation.height
                                dragOffset = .zero
                                saveOffset()
                            }
                    )
                    .offset(x: pillOffset.width + dragOffset.width,
                            y: pillOffset.height + dragOffset.height)
                    .padding(.top, topPadding)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            loadOffset()
        }
        .onChange(of: screenManager.selectedScreenIndex) { _, _ in
            withAnimation(.spring(duration: 0.3)) {
                pillOffset = .zero
                saveOffset()
            }
        }
    }

    private var topPadding: CGFloat {
        max(screenManager.selectedScreen.safeAreaInsets.top, 8) + 10
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

    // MARK: - Offset Persistence

    private func loadOffset() {
        if let w = UserDefaults.standard.object(forKey: "pillOffsetW") as? CGFloat,
           let h = UserDefaults.standard.object(forKey: "pillOffsetH") as? CGFloat {
            pillOffset = CGSize(width: w, height: h)
        }
    }

    private func saveOffset() {
        UserDefaults.standard.set(pillOffset.width, forKey: "pillOffsetW")
        UserDefaults.standard.set(pillOffset.height, forKey: "pillOffsetH")
    }
}
