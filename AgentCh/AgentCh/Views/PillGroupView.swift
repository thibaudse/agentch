import SwiftUI

struct PillGroupView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var pillPosition: PillPosition
    @State private var isHovering = false
    @State private var isPeeking = false
    @State private var peekTask: Task<Void, Never>?

    private let mascotSize: CGFloat = 20
    private let hPadding: CGFloat = 10
    private let vPadding: CGFloat = 6
    private let peekDuration: TimeInterval = 2.5

    private var isExpanded: Bool { isHovering || isPeeking }

    /// Snapshot of sessions state — changes trigger a peek.
    private var sessionsSnapshot: String {
        sessionManager.sessions.map { "\($0.id):\($0.status.rawValue)" }.joined(separator: ",")
    }

    var body: some View {
        ZStack(alignment: .top) {
            if !sessionManager.sessions.isEmpty {
                pillBody
                    .fixedSize()
                    .padding(20)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isHovering = hovering
                        }
                        if hovering { cancelPeek() }
                    }
                    .padding(-20)
                    .offset(pillPosition.offset)
                    .padding(.top, pillPosition.topPadding)
                    .transition(.blurReplace)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.opacity(0.0001))
        .onChange(of: sessionsSnapshot) { _, _ in
            peek()
        }
    }

    // MARK: - Peek (auto-expand then collapse)

    private func peek() {
        cancelPeek()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isPeeking = true
        }
        peekTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(peekDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isPeeking = false
            }
        }
    }

    private func cancelPeek() {
        peekTask?.cancel()
        peekTask = nil
        if isPeeking {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isPeeking = false
            }
        }
    }

    // MARK: - Pill body

    @ViewBuilder
    private var pillBody: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(sessionManager.sessions.enumerated()), id: \.element.id) { index, session in
                let isFirst = index == 0

                if isFirst || isExpanded {
                    sessionRow(session: session, isFirst: isFirst)
                        .transition(.blurReplace)
                }
            }
        }
        .padding(.horizontal, hPadding)
        .padding(.vertical, vPadding)
        .background(pillBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func sessionRow(session: Session, isFirst: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor(session.status))
                .frame(width: 6, height: 6)

            MascotView(
                agentType: session.agentType,
                status: session.status,
                size: mascotSize
            )

            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.label)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(session.status.rawValue)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .transition(.blurReplace)
            }

            if isFirst && !isExpanded && sessionManager.sessions.count > 1 {
                Text("\(sessionManager.sessions.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .transition(.blurReplace)
            }
        }
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .thinking: return .green
        case .idle: return .gray
        case .error: return .red
        }
    }

    @ViewBuilder
    private var pillBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.clear)
                .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        }
    }
}
