import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct IslandView: View {
    @ObservedObject var model: IslandViewModel
    let onClose: () -> Void

    @FocusState private var isInputFocused: Bool
    @State private var contentHeight: CGFloat = 0
    @State private var appeared = false

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
                    .padding(.horizontal, DS.sp18)
                    .frame(height: geometry.notchHeight, alignment: .center)

                // ── Below notch: interactive content ──
                VStack(spacing: DS.sp6) {
                    Group {
                        if model.isElicitation {
                            elicitationView
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)).combined(with: .offset(y: -4)),
                                    removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                                ))
                        } else if model.isPermission {
                            permissionView
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)).combined(with: .offset(y: -4)),
                                    removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                                ))
                        } else {
                            if model.interactive && !displayText.isEmpty {
                                messageScrollView
                                    .transition(.opacity)
                            }
                            if model.interactive {
                                inputFieldView
                                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)))
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.sp18)
                .padding(.bottom, DS.sp12)
                .opacity(model.contentVisible ? 1 : 0)
                .scaleEffect(model.contentVisible ? 1 : 0.97, anchor: .top)
                .animation(DS.Anim.dismiss, value: model.contentVisible)
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(ContentHeightKey.self) { h in
                if abs(contentHeight - h) > 1 { contentHeight = h }
            }
        }
        .frame(width: islandWidth, height: islandHeight)
        .clipShape(islandShape(geometry))
        .overlay(
            islandShape(geometry)
                .strokeBorder(DS.borderGradient(top: 0.12, bottom: 0.03), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 30, y: 10)
        .shadow(color: DS.accent.opacity(0.05), radius: 50, y: 12)
        .frame(
            maxWidth: geometry.fullExpandedWidth,
            maxHeight: geometry.notchHeight + AppConfig.maxIslandExtraHeight,
            alignment: .top
        )
        .scaleEffect(
            x: model.expanded ? 1 : geometry.notchWidth / max(islandWidth, 1),
            y: model.expanded ? 1 : geometry.notchHeight / max(islandHeight, 1),
            anchor: .top
        )
        .animation(DS.Anim.expand, value: model.isFullExpanded)
        .animation(DS.Anim.content, value: contentHeight)
        .onExitCommand { onClose() }
        .onAppear {
            withAnimation(DS.Anim.appear) { appeared = true }
        }
    }

    private func islandShape(_ geo: NotchGeometry) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: geo.hasNotch ? 8 : DS.radiusL,
                bottomLeading: DS.radiusXL,
                bottomTrailing: DS.radiusXL,
                topTrailing: geo.hasNotch ? 8 : DS.radiusL
            ),
            style: .continuous
        )
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
                    .background(agentNameFallbackBg)
                    .liquidGlassCapsule()
            }

            if model.isElicitation {
                Text("asks")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundColor(DS.text3)
                    .padding(.horizontal, DS.sp6)
                    .padding(.vertical, DS.sp2)
                    .background(asksBadgeFallbackBg)
                    .liquidGlassCapsule()
            } else if model.isPermission {
                Text("wants to use")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundColor(DS.text3)
                    .padding(.horizontal, DS.sp6)
                    .padding(.vertical, DS.sp2)
                    .background(wantsToUseFallbackBg)
                    .liquidGlassCapsule()
                Text(model.permissionTool)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(DS.warning.opacity(0.85))
                    .padding(.horizontal, DS.sp6)
                    .padding(.vertical, DS.sp2)
                    .background(toolBadgeFallbackBg)
                    .liquidGlassCapsule()
            }

            if !model.interactive && !model.message.isEmpty {
                Text(model.message)
                    .font(DS.Font.bodyMedium)
                    .foregroundColor(DS.text1)
                    .lineLimit(1)
                    .padding(.horizontal, DS.sp6)
                    .padding(.vertical, DS.sp2)
                    .background(compactMsgFallbackBg)
                    .liquidGlassCapsule()
            }

            Spacer(minLength: 4)

            if model.interactive && !model.conversation.isEmpty && !model.isPermission {
                DSHeaderButton(
                    icon: model.isFullExpanded
                        ? "arrowtriangle.right.and.line.vertical.and.arrowtriangle.left.fill"
                        : "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right.fill"
                ) {
                    model.toggleExpand()
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
                            .padding(.bottom, DS.sp2)
                    }
                }
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
                    .frame(height: model.isFullExpanded ? 0 : 8)
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

    @ViewBuilder
    private var wantsToUseFallbackBg: some View {
        if #unavailable(macOS 26.0) {
            Capsule(style: .continuous).fill(DS.surface1)
        }
    }

    @ViewBuilder
    private var asksBadgeFallbackBg: some View {
        if #unavailable(macOS 26.0) {
            Capsule(style: .continuous).fill(DS.accent.opacity(0.08))
        }
    }

    @ViewBuilder
    private var compactMsgFallbackBg: some View {
        if #unavailable(macOS 26.0) {
            Capsule(style: .continuous).fill(DS.surface1)
        }
    }

    @ViewBuilder
    private var agentNameFallbackBg: some View {
        if #unavailable(macOS 26.0) {
            Capsule(style: .continuous).fill(DS.surface1)
        }
    }

    @ViewBuilder
    private var toolBadgeFallbackBg: some View {
        if #unavailable(macOS 26.0) {
            Capsule(style: .continuous).fill(DS.warning.opacity(0.08))
        }
    }


}
