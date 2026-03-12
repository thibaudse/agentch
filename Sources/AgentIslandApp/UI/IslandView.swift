import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct IslandShellShape: InsettableShape {
    let geometry: NotchGeometry
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard !r.isEmpty else { return Path() }

        let w = r.width
        let h = r.height
        let notchBase = geometry.hasNotch ? geometry.notchHeight : min(h, 32)

        let topInset = min(w, notchBase * 0.5)
        let topDrop = min(h, notchBase * 0.5)
        let sideXLeft = r.minX + topInset
        let sideXRight = r.maxX - topInset

        let cornerRadius = min(notchBase, h, sideXRight - sideXLeft)
        let sideBottomY = max(topDrop, r.maxY - cornerRadius)

        let leftTop = CGPoint(x: sideXLeft, y: r.minY + topDrop)
        let rightTop = CGPoint(x: sideXRight, y: r.minY + topDrop)

        var path = Path()
        path.move(to: leftTop)
        path.addCurve(
            to: CGPoint(x: r.minX, y: r.minY),
            control1: CGPoint(x: leftTop.x, y: r.minY + topDrop * 0.5),
            control2: CGPoint(x: r.minX + topInset * 0.5, y: r.minY)
        )
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addCurve(
            to: rightTop,
            control1: CGPoint(x: r.maxX - topInset * 0.5, y: r.minY),
            control2: CGPoint(x: rightTop.x, y: r.minY + topDrop * 0.5)
        )
        path.addLine(to: CGPoint(x: sideXRight, y: sideBottomY))
        path.addArc(
            tangent1End: CGPoint(x: sideXRight, y: r.maxY),
            tangent2End: CGPoint(x: sideXRight - cornerRadius, y: r.maxY),
            radius: cornerRadius
        )
        path.addLine(to: CGPoint(x: sideXLeft + cornerRadius, y: r.maxY))
        path.addArc(
            tangent1End: CGPoint(x: sideXLeft, y: r.maxY),
            tangent2End: CGPoint(x: sideXLeft, y: sideBottomY),
            radius: cornerRadius
        )
        path.addLine(to: leftTop)
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

struct IslandView: View {
    @ObservedObject var model: IslandViewModel
    let onClose: () -> Void

    @FocusState private var isInputFocused: Bool
    @State private var contentHeight: CGFloat = 0
    @State private var contentAppeared = false
    @State private var contentAppearTask: Task<Void, Never>?

    private var displayText: String {
        model.isFullExpanded && !model.conversation.isEmpty
            ? model.conversation
            : model.message
    }

    private var messageMaxHeight: CGFloat {
        model.isFullExpanded ? 380 : 80
    }

    private var islandWidth: CGFloat {
        let geometry = model.geometry
        let needsWide = model.isFullExpanded || model.isElicitation || model.isPermission
        return geometry.effectiveWidth(interactive: model.interactive, fullExpanded: needsWide)
    }

    private var islandHeight: CGFloat {
        let geometry = model.geometry
        let minH = geometry.notchHeight
        let maxH = geometry.maxPanelHeight
        return max(minH, min(contentHeight, maxH))
    }

    private var statusColor: Color {
        if model.isElicitation { return DS.accent }
        if model.isPermission { return DS.warning }
        return DS.success
    }

    var body: some View {
        let geometry = model.geometry

        ZStack(alignment: .top) {
            Color.black

            VStack(spacing: 0) {
                // ── Notch zone: visual controls only (dot + buttons) ──
                // These sit in the physical notch area; buttons at the
                // edges are visible past the notch sides.
                notchControls
                    .padding(.horizontal, DS.sp24)
                    .frame(height: geometry.notchHeight, alignment: .center)
                    .padding(.bottom, model.interactive ? 0 : DS.sp6)
                    .compositingGroup()
                    .opacity(contentAppeared && model.contentVisible ? 1 : 0)
                    .scaleEffect(contentAppeared && model.contentVisible ? 1 : 0.98, anchor: .top)
                    .offset(y: contentAppeared && model.contentVisible ? 0 : -2)
                    .animation(DS.Anim.expand, value: model.isFullExpanded)

                // ── Below notch: interactive content ──
                VStack(spacing: DS.sp6) {
                    Group {
                        if model.isElicitation {
                            elicitationView
                                .transition(.blurReplace)
                        } else if model.isPermission {
                            permissionView
                                .transition(.blurReplace)
                        } else {
                            if !model.interactive && !model.message.isEmpty {
                                notificationMessageView
                                    .transition(.blurReplace)
                            }
                            if model.interactive && !displayText.isEmpty {
                                messageScrollView
                                    .transition(.blurReplace)
                            }
                            if model.interactive {
                                inputFieldView
                                    .transition(.blurReplace)
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.sp24)
                .padding(.top, DS.sp6)
                .padding(.bottom, DS.sp14)
                .opacity(contentAppeared && model.contentVisible ? 1 : 0)
                .scaleEffect(contentAppeared && model.contentVisible ? 1 : 0.96, anchor: .top)
                .offset(y: contentAppeared && model.contentVisible ? 0 : -4)
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(ContentHeightKey.self) { h in
                if abs(contentHeight - h) > 1 {
                    contentHeight = h
                    model.onContentHeightChange?(h)
                }
            }
        }
        .frame(
            width: model.expanded ? islandWidth : geometry.notchWidth,
            height: model.expanded ? islandHeight : geometry.notchHeight
        )
        .clipShape(islandShape(geometry))
        .overlay(
            islandShape(geometry)
                .strokeBorder(DS.borderGradient(top: 0.12, bottom: 0.03), lineWidth: 0.5)
        )
        .frame(
            maxWidth: geometry.fullExpandedWidth,
            maxHeight: geometry.notchHeight + AppConfig.maxIslandExtraHeight,
            alignment: .top
        )
        .animation(model.expanded ? DS.Anim.notchOpen : DS.Anim.notchClose, value: model.expanded)
        .animation(DS.Anim.content, value: contentHeight)
        .animation(DS.Anim.expand, value: model.isPermission)
        .animation(DS.Anim.expand, value: model.isElicitation)
        .onAppear {
            if model.expanded && model.contentVisible {
                contentAppeared = true
            }
        }
        .onDisappear { contentAppearTask?.cancel() }
        .onExitCommand { onClose() }
        .onChange(of: model.expanded) { _, expanded in
            if expanded {
                scheduleContentAppearanceAfterOpen()
            } else {
                contentAppearTask?.cancel()
                withAnimation(DS.Anim.contentOut) { contentAppeared = false }
            }
        }
        .onChange(of: model.contentVisible) { _, visible in
            if !visible {
                contentAppearTask?.cancel()
                withAnimation(DS.Anim.contentOut) { contentAppeared = false }
            } else if model.expanded {
                scheduleContentAppearanceAfterOpen()
            }
        }
    }

    private func scheduleContentAppearanceAfterOpen() {
        contentAppearTask?.cancel()
        contentAppeared = false
        guard model.contentVisible else { return }

        contentAppearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            guard model.expanded && model.contentVisible else { return }
            withAnimation(DS.Anim.contentIn) {
                contentAppeared = true
            }
        }
    }

    private func islandShape(_ geo: NotchGeometry) -> IslandShellShape {
        IslandShellShape(geometry: geo)
    }

    // MARK: - Notch Controls + Header Pills (single row aligned to the notch)

    private var notchControls: some View {
        HStack(spacing: DS.sp8) {
            PulsingDot(color: statusColor)

            if !model.agentName.isEmpty {
                Text(model.agentName)
                    .font(DS.Font.label)
                    .foregroundColor(DS.text3)
                    .tracking(0.3)
                    .padding(.horizontal, DS.sp6)
                    .padding(.vertical, DS.sp2)
                    .fadedCapsuleSurface()
            }

            if model.isElicitation {
                Text("asks")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundColor(DS.text3)
                    .padding(.horizontal, DS.sp6)
                    .padding(.vertical, DS.sp2)
                    .fadedCapsuleSurface()
            } else if model.isPermission {
                Text("wants to use")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundColor(DS.text3)
                    .padding(.horizontal, DS.sp6)
                    .padding(.vertical, DS.sp2)
                    .fadedCapsuleSurface()
                Text(model.permissionTool)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(DS.warning.opacity(0.85))
                    .padding(.horizontal, DS.sp6)
                    .padding(.vertical, DS.sp2)
                    .fadedCapsuleSurface()
            }

            Spacer(minLength: 4)

            if model.interactive && !model.conversation.isEmpty && !model.isPermission {
                DSHeaderButton(
                    icon: model.isFullExpanded
                        ? "arrow.down.right.and.arrow.up.left"
                        : "arrow.up.left.and.arrow.down.right"
                ) {
                    withAnimation(DS.Anim.expand) {
                        model.toggleExpand()
                    }
                }
            }

            DSHeaderButton(icon: "xmark") { onClose() }
        }
    }

    // MARK: - Elicitation View

    private var elicitationView: some View {
        VStack(spacing: DS.sp8) {
            Text(model.elicitationQuestion)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(DS.text1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, DS.sp2)

            ForEach(Array(model.elicitationOptions.enumerated()), id: \.element.id) { index, option in
                elicitationOptionButton(option, index: index)
            }

            elicitationInputField
        }
    }

    private func elicitationOptionButton(_ option: ElicitationOption, index: Int) -> some View {
        Button(action: { model.answerElicitation(option.label) }) {
            HStack(spacing: DS.sp8) {
                Text(option.label)
                    .font(DS.Font.subheadline)
                    .foregroundColor(.white.opacity(0.95))
                if let desc = option.description, !desc.isEmpty {
                    Text(desc)
                        .font(DS.Font.caption)
                        .foregroundColor(DS.text2)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.18))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DS.sp14)
            .padding(.vertical, DS.sp8 + 1)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusM, style: .continuous)
                    .fill(DS.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusM, style: .continuous)
                    .strokeBorder(DS.tintedBorder(DS.accent, top: 0.30, bottom: 0.10), lineWidth: 0.8)
            )
        }
        .buttonStyle(DSButtonStyle())
    }

    private var elicitationInputField: some View {
        HStack(spacing: DS.sp8) {
            ZStack(alignment: .leading) {
                if model.inputText.isEmpty {
                    Text("Type a custom answer...")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(DS.text3)
                }
                TextField("", text: $model.inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white)
                    .tint(DS.accent)
                    .focused($isInputFocused)
                    .onSubmit { model.answerElicitation(model.inputText) }
            }

            DSSendButton(
                small: true,
                isEmpty: model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                let text = model.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { model.answerElicitation(text) }
            }
        }
        .padding(.horizontal, DS.sp12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: DS.radiusM, style: .continuous)
                .fill(DS.surface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusM, style: .continuous)
                .strokeBorder(DS.border1, lineWidth: 0.8)
        )
    }

    // MARK: - Permission View

    private var permissionView: some View {
        VStack(spacing: DS.sp10) {
            // Command display
            if !model.permissionCommand.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(model.permissionCommand)
                        .font(DS.Font.mono)
                        .foregroundColor(DS.text1.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.sp12)
                        .padding(.vertical, DS.sp10)
                }
                .frame(maxHeight: 60)
                .background(
                    RoundedRectangle(cornerRadius: DS.radiusS + 2, style: .continuous)
                        .fill(DS.surface1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radiusS + 2, style: .continuous)
                        .strokeBorder(DS.tintedBorder(DS.warning, top: 0.28, bottom: 0.08), lineWidth: 0.8)
                )
            }

            // Yes / No
            HStack(spacing: DS.sp10) {
                // No (deny)
                DSPillButton(
                    action: { model.denyPermission() },
                    fill: DS.surface2,
                    border: DS.border2
                ) {
                    Text("No")
                        .font(DS.Font.bodyMedium)
                        .foregroundColor(DS.text2)
                }

                // Yes (allow) — accent blue/purple
                DSPillButton(
                    action: { model.approvePermission() },
                    fill: DS.accentFill,
                    border: DS.accentBorder,
                    glowColor: DS.accent
                ) {
                    Text("Yes")
                        .font(DS.Font.subheadline)
                        .foregroundColor(.white)
                }
            }

            // "Always allow" suggestions
            if !model.permissionSuggestions.isEmpty {
                ForEach(Array(model.permissionSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                    DSPillButton(
                        action: { model.selectSuggestion(suggestion) },
                        fill: DS.accent.opacity(0.06),
                        border: DS.accent.opacity(0.16)
                    ) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 10))
                            Text(suggestion.label)
                                .font(DS.Font.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(DS.accent.opacity(0.75))
                    }
                }
            }
        }
    }

    // MARK: - Message Scroll

    private var notificationMessageView: some View {
        Text(model.message)
            .font(DS.Font.bodyMedium)
            .foregroundColor(DS.text1)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, DS.sp10)
            .padding(.vertical, DS.sp6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                Group {
                    if model.isFullExpanded && !model.conversation.isEmpty {
                        ConversationView(text: model.conversation)
                    } else {
                        MarkdownText(model.message)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, model.isFullExpanded ? DS.sp2 : DS.sp10)
                .id("msg-\(model.isFullExpanded)")
                .transition(.blurReplace)
                .animation(DS.Anim.expand, value: model.isFullExpanded)
                .id("msg-end")
            }
            .frame(maxHeight: messageMaxHeight)
            .mask(
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: model.isFullExpanded ? 0 : 12)
                }
            )
            .onAppear { proxy.scrollTo("msg-end", anchor: .bottom) }
        }
    }

    // MARK: - Input Field

    private var inputFieldView: some View {
        HStack(spacing: DS.sp8) {
            ZStack(alignment: .leading) {
                if model.inputText.isEmpty {
                    Text("Type your response...")
                        .font(DS.Font.body)
                        .foregroundColor(DS.text3)
                }
                TextField("", text: $model.inputText)
                    .textFieldStyle(.plain)
                    .font(DS.Font.body)
                    .foregroundColor(.white)
                    .tint(DS.accent)
                    .focused($isInputFocused)
                    .onSubmit { model.submit() }
            }

            DSSendButton(
                small: false,
                isEmpty: model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                model.submit()
            }
        }
        .padding(.horizontal, DS.sp14)
        .padding(.vertical, DS.sp8 + 1)
        .background(
            Capsule(style: .continuous).fill(DS.surface1)
        )
        .overlay(
            AnimatedGlowBorder(focused: isInputFocused)
        )
    }

}

#if DEBUG
private extension NotchGeometry {
    static var previewNotch: NotchGeometry {
        NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchWidth: 185,
            notchHeight: 32,
            hasNotch: true
        )
    }
}

private enum PreviewIslandType: String {
    case waiting = "Claude Waiting"
    case permission = "Permission"
    case elicitation = "Elicitation"
    case notification = "Notification"
}

@MainActor
private func makePreviewModel(for type: PreviewIslandType) -> IslandViewModel {
    let model = IslandViewModel()

    switch type {
    case .waiting:
        model.update(
            message: "Ready when you are.",
            agentName: "claude",
            geometry: .previewNotch,
            interactive: true,
            conversation: """
            **Claude:** I implemented the shape changes and rebuilt the daemon.

            **Claude:** Tell me if you want sharper top reverse curves or a larger bottom radius.
            """
        )
        model.inputText = "Looks good"

    case .permission:
        model.updatePermission(
            tool: "Bash",
            command: "rm -rf .build/cache",
            agentName: "claude",
            geometry: .previewNotch,
            suggestions: [
                PermissionSuggestion(raw: ["type": "toolAlwaysAllow", "tool": "Bash"]),
                PermissionSuggestion(raw: [
                    "type": "addDirectories",
                    "directories": ["/Users/thibaud/Projects/Personal/agent-island"],
                    "destination": "project"
                ])
            ]
        )

    case .elicitation:
        model.updateElicitation(
            question: Elicitation(
                question: "Which notch style should I keep?",
                options: [
                    ElicitationOption(label: "Current (balanced)", description: "Keep current curves"),
                    ElicitationOption(label: "More curvy", description: "Increase reverse-curve depth"),
                    ElicitationOption(label: "Sharper", description: "Reduce corner radius")
                ]
            ),
            agentName: "claude",
            geometry: .previewNotch
        )

    case .notification:
        model.update(
            message: "Build succeeded. Waiting for next instruction.",
            agentName: "claude",
            geometry: .previewNotch,
            interactive: false,
            conversation: ""
        )
    }

    model.expanded = true
    model.contentVisible = true
    return model
}

@MainActor
private struct IslandTypePreview: View {
    let type: PreviewIslandType
    @StateObject private var model: IslandViewModel
    @State private var isShown = true
    @State private var animationTask: Task<Void, Never>?

    init(type: PreviewIslandType) {
        self.type = type
        _model = StateObject(wrappedValue: makePreviewModel(for: type))
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.11, blue: 0.14), Color(red: 0.05, green: 0.05, blue: 0.06)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: DS.sp12) {
                Button(isShown ? "Hide Notch" : "Show Notch") {
                    if isShown {
                        hideNotch()
                    } else {
                        showNotch()
                    }
                }
                .buttonStyle(DSButtonStyle())
                .font(DS.Font.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, DS.sp14)
                .padding(.vertical, DS.sp8)
                .background(Capsule(style: .continuous).fill(DS.surface2))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(DS.border2, lineWidth: 0.8)
                )
                .zIndex(2)

                IslandView(model: model, onClose: { hideNotch() })
                    .allowsHitTesting(isShown)
                    .transition(.blurReplace)
                    .zIndex(1)
            }
            .padding(.top, 24)
        }
        .frame(width: 980, height: 420)
        .onDisappear { animationTask?.cancel() }
    }

    private func showNotch() {
        animationTask?.cancel()
        isShown = true
        model.expanded = false
        model.contentVisible = true

        animationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 30_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(DS.Anim.notchOpen) {
                model.expanded = true
            }
        }
    }

    private func hideNotch() {
        animationTask?.cancel()
        isShown = false
        withAnimation(DS.Anim.contentOut) {
            model.contentVisible = false
        }

        animationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(DS.Anim.notchClose) {
                model.expanded = false
            }
        }
    }
}

#Preview("Island Shell Shape") {
    ZStack {
        Color(red: 0.14, green: 0.14, blue: 0.16)
        IslandShellShape(geometry: .previewNotch)
            .fill(Color.black)
            .overlay(
                IslandShellShape(geometry: .previewNotch)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .frame(width: 720, height: 170)
    }
    .frame(width: 860, height: 320)
}

#Preview("Type: Claude Waiting") {
    IslandTypePreview(type: .waiting)
}

#Preview("Type: Permission") {
    IslandTypePreview(type: .permission)
}

#Preview("Type: Elicitation") {
    IslandTypePreview(type: .elicitation)
}

#Preview("Type: Notification") {
    IslandTypePreview(type: .notification)
}
#endif
