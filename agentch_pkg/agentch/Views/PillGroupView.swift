import SwiftUI

struct PillGroupView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var pillPosition: PillPosition
    @AppStorage("pillScale") var pillScale: Double = 1.0
    @AppStorage("peekDuration") var peekDurationSetting: Double = 2.5
    @State private var isHovering = false
    @State private var isPeeking = false
    @State private var peekTask: Task<Void, Never>?
    @State private var squish: CGFloat = 1.0
    @State private var badgePop: CGFloat = 1.0
    @State private var hoveredRowId: String?
    private var scale: CGFloat { CGFloat(pillScale) }
    private var mascotSize: CGFloat { 16 * scale }
    private var hPadding: CGFloat { 14 * scale }
    private var vPadding: CGFloat { 10 * scale }

    private var isExpanded: Bool { (isHovering || isPeeking) && !pillPosition.isDragging }


    private var sessionsSnapshot: String {
        sessionManager.sessions.map { "\($0.id):\($0.status.rawValue)" }.joined(separator: ",")
    }

    /// Vertical expansion direction: expand down if pill is in top half, up if bottom half.
    /// Keep natural list order except when in bottom zone (reverse to grow upward)
    private var expandsDown: Bool {
        verticalZone != 1
    }

    /// Split screen into 3 horizontal zones: left, center, right
    private var horizontalZone: Int {
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        let pillX = screenWidth / 2 + pillPosition.offset.width
        let third = screenWidth / 3
        if pillX < third { return -1 }       // left
        if pillX > third * 2 { return 1 }    // right
        return 0                               // center
    }

    /// Split screen into 3 vertical zones: top, center, bottom
    private var verticalZone: Int {
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        let pillY = pillPosition.topPadding + pillPosition.offset.height
        let third = screenHeight / 3
        if pillY < third { return -1 }        // top
        if pillY > third * 2 { return 1 }     // bottom
        return 0                               // center
    }

    private var expandAlignment: Alignment {
        let h: HorizontalAlignment = switch horizontalZone {
        case -1: .leading     // pill is left → expand right
        case 1:  .trailing    // pill is right → expand left
        default: .center      // pill is center → expand from center
        }
        let v: VerticalAlignment = switch verticalZone {
        case -1: .top         // pill is top → expand down
        case 1:  .bottom      // pill is bottom → expand up
        default: .center      // pill is center → expand from center
        }
        return Alignment(horizontal: h, vertical: v)
    }

    var body: some View {
        ZStack(alignment: .top) {
            if !sessionManager.sessions.isEmpty {
                pillBody
                    .fixedSize()
                    .padding(20)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        pillPosition.isMouseOverPill = hovering
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                            isHovering = hovering
                        }
                        if hovering {
                            cancelPeek()
                            NSCursor.openHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .padding(-20)
                    .modifier(ExpansionAnchor(
                        alignment: expandAlignment,
                        active: !pillPosition.isDragging
                    ))
                    .offset(pillPosition.offset)
                    .padding(.top, pillPosition.topPadding)
                    .scaleEffect(squish)
                    .transition(.blurReplace)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ParticleTrailView(pillPosition: pillPosition))
        .background(Color.white.opacity(0.0001))
        .onChange(of: sessionsSnapshot) { _, _ in
            peek()
            triggerSquish()
        }
        .onChange(of: sessionManager.sessions.count) { _, _ in
            triggerSquish()
            triggerBadgePop()
        }
        .onAppear {
            if !sessionManager.sessions.isEmpty {
                peek()
            }
        }
    }

    // MARK: - Badge pop

    private func triggerBadgePop() {
        withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
            badgePop = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                badgePop = 1.0
            }
        }
    }

    // MARK: - Squish

    private func triggerSquish() {
        withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
            squish = 0.92
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                squish = 1.0
            }
        }
    }

    // MARK: - Peek

    private func peek() {
        cancelPeek()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
            isPeeking = true
        }
        peekTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(peekDurationSetting))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                isPeeking = false
            }
        }
    }

    private func cancelPeek() {
        peekTask?.cancel()
        peekTask = nil
        if isPeeking {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
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

        VStack(alignment: .leading, spacing: 5 * scale) {
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
        .clipShape(.rect(cornerRadius: 20 * scale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20 * scale, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var maxPermissionWidth: CGFloat {
        (NSScreen.main?.frame.width ?? 1920) / 3
    }

    @ViewBuilder
    private func sessionRow(session: Session, isFirst: Bool) -> some View {
        let isRowHovered = hoveredRowId == session.id
        let isRowExpanded = isExpanded && isRowHovered
        let hasAction = session.pendingPermission != nil

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6 * scale) {
                StatusDot(status: session.status, scale: scale)

                MascotView(
                    agentType: session.agentType,
                    status: session.status,
                    size: mascotSize
                )

                if isExpanded {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.label)
                            .font(.system(size: 11 * scale, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(statusLabel(session.status))
                            .font(.system(size: 9 * scale, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4 * scale)

                    // Action indicator when row is collapsed but has pending permission
                    if hasAction && !isRowExpanded {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10 * scale))
                            .foregroundStyle(.orange)
                            .transition(.blurReplace)
                    }

                    JumpButton {
                        TerminalFocuser.focus(session: session)
                    }
                    .transition(.blurReplace)
                }

                if isFirst && !isExpanded && sessionManager.sessions.count > 1 {
                    Text("\(waitingCount > 0 ? waitingCount : sessionManager.sessions.count)")
                        .font(.system(size: 8 * scale, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 14 * scale, height: 14 * scale)
                        .background(
                            Circle().fill(waitingCount > 0 ? .orange : .primary.opacity(0.5))
                        )
                        .contentTransition(.numericText())
                        .scaleEffect(badgePop)
                        .transition(.blurReplace)
                }
            }

            // Permission prompt only shown when this specific row is hovered
            if isRowExpanded, let permission = session.pendingPermission {
                PermissionPromptView(
                    permission: permission,
                    scale: scale,
                    onAllow: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            sessionManager.resolvePermission(sessionId: session.id, allow: true)
                        }
                    },
                    onDeny: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            sessionManager.resolvePermission(sessionId: session.id, allow: false)
                        }
                    }
                )
                .frame(maxWidth: maxPermissionWidth)
                .padding(.top, 6 * scale)
                .transition(.blurReplace)
            }
        }
        .padding(.vertical, isExpanded ? 6 * scale : 3 * scale)
        .padding(.horizontal, isExpanded ? 8 * scale : 6 * scale)
        .background(
            RoundedRectangle(
                cornerRadius: isRowExpanded ? 12 * scale : 20 * scale,
                style: .continuous
            )
            .fill(.primary.opacity(hasAction && isRowHovered ? 0.1 : 0.07))
        )
        .onHover { hovering in
            guard hasAction else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                hoveredRowId = hovering ? session.id : nil
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

    private var statusTint: Color {
        if sessionManager.sessions.contains(where: { $0.status == .waiting }) {
            return .orange.opacity(0.15)
        }
        if sessionManager.sessions.contains(where: { $0.status == .thinking }) {
            return .green.opacity(0.1)
        }
        return .clear
    }

    @ViewBuilder
    private var pillBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 20 * scale, style: .continuous)
        if #available(macOS 26.0, *) {
            ZStack {
                shape
                    .fill(.clear)
                    .glassEffect(.clear.interactive(), in: shape)
                shape
                    .fill(statusTint)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.2), radius: 12 * scale, y: 4 * scale)
        } else {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(statusTint)
            }
            .shadow(color: .black.opacity(0.2), radius: 12 * scale, y: 4 * scale)
        }
    }
}

struct PermissionPromptView: View {
    let permission: PermissionRequest
    let scale: CGFloat
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * scale) {
            Text(permission.toolName)
                .font(.system(size: 10 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)

            if !permission.toolInput.isEmpty {
                ScrollView {
                    Text(permission.toolInput)
                        .font(.system(size: 9 * scale, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6 * scale)
                }
                .frame(maxHeight: 60 * scale)
                .background(
                    RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                        .fill(.primary.opacity(0.06))
                )
            }

            HStack(spacing: 6 * scale) {
                Button("Allow") { onAllow() }
                    .font(.system(size: 9 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.green)
                    .buttonStyle(.plain)
                    .cursor(.pointingHand)

                Button("Deny") { onDeny() }
                    .font(.system(size: 9 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .cursor(.pointingHand)
            }
        }
    }
}

/// Applies a 0x0 frame with alignment when active, passthrough when not.
struct ExpansionAnchor: ViewModifier {
    let alignment: Alignment
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.frame(maxWidth: 0, maxHeight: 0, alignment: alignment)
        } else {
            content
        }
    }
}
