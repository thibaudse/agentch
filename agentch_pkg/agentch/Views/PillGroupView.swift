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
    @State private var pageOffset: Int = 0
    private var scale: CGFloat { CGFloat(pillScale) }
    private var mascotSize: CGFloat { 16 * scale }
    private var hPadding: CGFloat { 14 * scale }
    private var vPadding: CGFloat { 10 * scale }

    private var isExpanded: Bool { (isHovering || isPeeking) && !pillPosition.isDragging }


    private var sessionsSnapshot: String {
        sessionManager.sessions.map { "\($0.id):\($0.status.rawValue):\($0.pendingPermission != nil):\($0.pendingQuestion != nil)" }.joined(separator: ",")
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

    private let maxVisibleRows = 5

    private var sortedSessions: [Session] {
        // Pending permissions first, then by status
        sessionManager.sessions.sorted { a, b in
            if a.pendingPermission != nil && b.pendingPermission == nil { return true }
            if a.pendingPermission == nil && b.pendingPermission != nil { return false }
            return a.status.sortOrder < b.status.sortOrder
        }
    }

    private var waitingCount: Int {
        sessionManager.sessions.filter { $0.status == .waiting }.count
    }

    @ViewBuilder
    private var pillBody: some View {
        let sessions = expandsDown ? sortedSessions : sortedSessions.reversed()

        VStack(alignment: .leading, spacing: 5 * scale) {
            let clampedOffset = min(pageOffset, max(0, sessions.count - maxVisibleRows))
            let pageEnd = min(clampedOffset + maxVisibleRows, sessions.count)
            let visibleSessions = isExpanded ? Array(sessions[clampedOffset..<pageEnd]) : sessions
            let beforeCount = isExpanded ? clampedOffset : 0
            let afterCount = isExpanded ? max(0, sessions.count - pageEnd) : 0

            // "N more" at top to go back
            if isExpanded && beforeCount > 0 {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        pageOffset = max(0, pageOffset - maxVisibleRows)
                    }
                } label: {
                    HStack(spacing: 4 * scale) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 7 * scale, weight: .bold))
                        Text("\(beforeCount) more")
                            .font(.system(size: 9 * scale, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10 * scale)
                    .padding(.vertical, 4 * scale)
                    .background(
                        Capsule()
                            .fill(.primary.opacity(0.06))
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 2 * scale)
                .transition(.blurReplace)
            }

            ForEach(Array(visibleSessions.enumerated()), id: \.element.id) { index, session in
                let isFirst = expandsDown ? index == 0 : index == visibleSessions.count - 1

                if isFirst || isExpanded {
                    sessionRow(session: session, isFirst: isFirst)
                        .transition(.blurReplace)
                }
            }

            // "N more" at bottom to see next page
            if isExpanded && afterCount > 0 {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        pageOffset = min(pageOffset + maxVisibleRows, sessions.count - maxVisibleRows)
                    }
                } label: {
                    HStack(spacing: 4 * scale) {
                        Text("\(afterCount) more")
                            .font(.system(size: 9 * scale, weight: .medium, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7 * scale, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10 * scale)
                    .padding(.vertical, 4 * scale)
                    .background(
                        Capsule()
                            .fill(.primary.opacity(0.06))
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                .padding(.top, 2 * scale)
                .transition(.blurReplace)
            }
        }
        .padding(.horizontal, hPadding)
        .padding(.vertical, vPadding)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hoveredRowId)
        .background(pillBackground)
        .clipShape(.rect(cornerRadius: 20 * scale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20 * scale, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 0.5)
        )
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
                pageOffset = 0
            }
        }
        .padding(-20)
    }

    private var maxPermissionWidth: CGFloat {
        (NSScreen.main?.frame.width ?? 1920) / 3
    }

    @ViewBuilder
    private func sessionRow(session: Session, isFirst: Bool) -> some View {
        let isRowHovered = hoveredRowId == session.id
        let isRowExpanded = isExpanded && isRowHovered
        let hasAction = session.pendingPermission != nil || session.pendingQuestion != nil

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

                    // Acknowledge button for non-permission waiting
                    if session.status == .waiting && session.pendingPermission == nil {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                sessionManager.sessions[sessionManager.sessions.firstIndex(where: { $0.id == session.id })!].status = .idle
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7 * scale, weight: .bold))
                                .foregroundStyle(.orange.opacity(0.6))
                                .frame(width: 18 * scale, height: 18 * scale)
                                .background(Circle().fill(.orange.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
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
                .padding(.leading, 2 * scale)
                .padding(.top, 6 * scale)
                .padding(.bottom, 4 * scale)
                .transition(.blurReplace)
            }

            // Question prompt
            if isRowExpanded, let question = session.pendingQuestion {
                QuestionPromptView(
                    question: question,
                    scale: scale,
                    onSubmit: { answer in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            sessionManager.resolveQuestion(sessionId: session.id, answer: answer)
                        }
                    },
                    onSkip: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            sessionManager.resolveQuestion(sessionId: session.id, answer: nil)
                        }
                    }
                )
                .frame(maxWidth: maxPermissionWidth)
                .padding(.leading, 2 * scale)
                .padding(.top, 6 * scale)
                .padding(.bottom, 4 * scale)
                .transition(.blurReplace)
            }
        }
        .padding(.vertical, isExpanded ? 6 * scale : 3 * scale)
        .padding(.horizontal, isExpanded ? 8 * scale : 6 * scale)
        .background {
            if isExpanded {
                RoundedRectangle(
                    cornerRadius: 14 * scale,
                    style: .continuous
                )
                .fill(.primary.opacity(hasAction && isRowHovered ? 0.1 : 0.07))
            }
        }
        .onHover { hovering in
            if hasAction {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    hoveredRowId = hovering ? session.id : nil
                }
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
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(statusTint)
        }
        .shadow(color: .black.opacity(0.2), radius: 12 * scale, y: 4 * scale)
    }
}

struct PermissionPromptView: View {
    let permission: PermissionRequest
    let scale: CGFloat
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * scale) {
            // Tool name
            Text(permission.toolName)
                .font(.system(size: 10 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.85, green: 0.5, blue: 0.0))

            // File path above code block
            if let filePath = permission.filePath {
                Text(filePath)
                    .font(.system(size: 8 * scale, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Code block — diff view for edits, plain text for others
            if !permission.toolInput.isEmpty {
                let isDiff = permission.toolName == "Edit"
                ScrollView {
                    if isDiff {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(permission.toolInput.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                                DiffLineView(line: line, scale: scale)
                            }
                        }
                        .padding(6 * scale)
                    } else {
                        Text(permission.toolInput)
                            .font(.system(size: 9 * scale, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6 * scale)
                    }
                }
                .frame(maxHeight: 80 * scale)
                .background(
                    RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                        .fill(.primary.opacity(0.06))
                )
            }

            HStack(spacing: 4 * scale) {
                Button { onAllow() } label: {
                    HStack(spacing: 3 * scale) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7 * scale, weight: .bold))
                        Text("Allow")
                            .font(.system(size: 9 * scale, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10 * scale)
                    .padding(.vertical, 5 * scale)
                    .background(
                        RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                            .fill(Color.green.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
                .cursor(.pointingHand)

                Button { onDeny() } label: {
                    HStack(spacing: 3 * scale) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7 * scale, weight: .bold))
                        Text("Deny")
                            .font(.system(size: 9 * scale, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10 * scale)
                    .padding(.vertical, 5 * scale)
                    .background(
                        RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                            .fill(.primary.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .cursor(.pointingHand)
            }
        }
    }
}

struct DiffLineView: View {
    let line: String
    let scale: CGFloat

    // Format: "NNN - content" or "NNN + content"
    private var parsed: (lineNum: String, sign: String, content: String) {
        // Find the " - " or " + " separator after the line number
        if let range = line.range(of: " - ", options: [], range: line.startIndex..<line.endIndex) {
            let num = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let content = String(line[range.upperBound...])
            return (num, "-", content)
        }
        if let range = line.range(of: " + ", options: [], range: line.startIndex..<line.endIndex) {
            let num = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let content = String(line[range.upperBound...])
            return (num, "+", content)
        }
        return ("", " ", line)
    }

    private var isRemoval: Bool { parsed.sign == "-" }
    private var isAddition: Bool { parsed.sign == "+" }

    var body: some View {
        HStack(spacing: 0) {
            // Line number
            Text(parsed.lineNum)
                .font(.system(size: 8 * scale, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.3))
                .frame(width: 24 * scale, alignment: .trailing)
                .padding(.trailing, 4 * scale)

            // +/- indicator
            Text(isRemoval ? "−" : isAddition ? "+" : " ")
                .font(.system(size: 9 * scale, weight: .bold, design: .monospaced))
                .foregroundStyle(isRemoval ? Color.red : isAddition ? Color.green : .clear)
                .frame(width: 10 * scale, alignment: .center)

            // Content
            Text(parsed.content)
                .font(.system(size: 9 * scale, design: .monospaced))
                .foregroundStyle(
                    isRemoval ? Color.red :
                    isAddition ? Color.green :
                    .primary.opacity(0.7)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 1 * scale)
        .background(
            isRemoval ? Color.red.opacity(0.15) :
            isAddition ? Color.green.opacity(0.15) :
            Color.clear
        )
    }
}

/// Applies a 0x0 frame with alignment when active, passthrough when not.
struct QuestionPromptView: View {
    let question: PendingQuestion
    let scale: CGFloat
    let onSubmit: (String) -> Void
    let onSkip: () -> Void
    @State private var answer = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scale) {
            // Header
            Text("Question")
                .font(.system(size: 10 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.85, green: 0.5, blue: 0.0))

            Text(question.question)
                .font(.system(size: 9 * scale, design: .rounded))
                .foregroundStyle(.primary.opacity(0.8))
                .padding(.bottom, 2 * scale)

            // Options
            if !question.options.isEmpty {
                VStack(alignment: .leading, spacing: 2 * scale) {
                    ForEach(question.options, id: \.label) { option in
                        Button { onSubmit(option.label) } label: {
                            Text(option.label)
                                .font(.system(size: 9 * scale, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8 * scale)
                                .padding(.vertical, 5 * scale)
                                .background(
                                    RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                                        .fill(.primary.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                        .cursor(.pointingHand)
                    }
                }
            }

            // Text field + skip
            HStack(spacing: 4 * scale) {
                HStack(spacing: 0) {
                    TextField(question.options.isEmpty ? "Type your answer..." : "Or type custom...", text: $answer)
                        .textFieldStyle(.plain)
                        .font(.system(size: 9 * scale, design: .monospaced))
                        .padding(.horizontal, 8 * scale)
                        .padding(.vertical, 6 * scale)
                        .onSubmit {
                            guard !answer.isEmpty else { return }
                            onSubmit(answer)
                        }

                    Button {
                        guard !answer.isEmpty else { return }
                        onSubmit(answer)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 14 * scale))
                            .foregroundStyle(answer.isEmpty ? Color.primary.opacity(0.15) : Color.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(answer.isEmpty)
                    .padding(.trailing, 6 * scale)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                        .fill(.primary.opacity(0.06))
                )

                Button { onSkip() } label: {
                    HStack(spacing: 3 * scale) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 7 * scale))
                        Text("Skip")
                            .font(.system(size: 9 * scale, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8 * scale)
                    .padding(.vertical, 6 * scale)
                    .background(
                        RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                            .fill(.primary.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .cursor(.pointingHand)
            }
        }
    }
}

/// Simple flow layout for wrapping option chips
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

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
