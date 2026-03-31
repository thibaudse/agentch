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

    private var sessionsSnapshot: String {
        sessionManager.sessions.map { "\($0.id):\($0.status.rawValue)" }.joined(separator: ",")
    }

    /// Vertical expansion direction: expand down if pill is in top half, up if bottom half.
    private var expandsDown: Bool {
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        let pillY = pillPosition.topPadding + pillPosition.offset.height
        return pillY < screenHeight / 2
    }

    private var expandsRight: Bool {
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        // Pill starts at center (screenWidth/2), offset moves it
        return pillPosition.offset.width < 0
    }

    private var expandAlignment: Alignment {
        switch (expandsRight, expandsDown) {
        case (true, true): return .topLeading
        case (false, true): return .topTrailing
        case (true, false): return .bottomLeading
        case (false, false): return .bottomTrailing
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            if !sessionManager.sessions.isEmpty {
                pillBody
                    .fixedSize()
                    // Anchor the pill so it grows away from the nearest edge
                    .frame(maxWidth: 0, maxHeight: 0, alignment: expandAlignment)
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

    // MARK: - Peek

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

    private var sortedSessions: [Session] {
        sessionManager.sessions.sorted { a, b in
            a.status.sortOrder < b.status.sortOrder
        }
    }

    private var waitingCount: Int {
        sessionManager.sessions.filter { $0.status == .waiting }.count
    }

    @ViewBuilder
    private var pillBody: some View {
        let sessions = expandsDown ? sortedSessions : sortedSessions.reversed()

        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                let isFirst = expandsDown ? index == 0 : index == sessions.count - 1

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
            StatusDot(status: session.status)

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

                    Text(statusLabel(session.status))
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                JumpButton {
                    TerminalFocuser.focus(session: session)
                }
                .transition(.blurReplace)
            }

            if isFirst && !isExpanded && sessionManager.sessions.count > 1 {
                Text(compactBadge)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(waitingCount > 0 ? .orange : .primary)
                    .transition(.blurReplace)
            }
        }
    }

    private var compactBadge: String {
        if waitingCount > 0 { return "\(waitingCount)!" }
        return "\(sessionManager.sessions.count)"
    }

    private func statusLabel(_ status: SessionStatus) -> String {
        switch status {
        case .thinking: return "working..."
        case .waiting: return "needs input"
        case .idle: return "idle"
        case .error: return "error"
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
