import SwiftUI

private let islandAccent = Color(red: 0.35, green: 0.65, blue: 1.0)
private let surfaceColor = Color.white.opacity(0.05)
private let surfaceBorder = Color.white.opacity(0.08)
private let dimText = Color.white.opacity(0.45)
private let bodyText = Color.white.opacity(0.88)

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct IslandView: View {
    @ObservedObject var model: IslandViewModel
    let onClose: () -> Void

    @FocusState private var isInputFocused: Bool
    @State private var contentHeight: CGFloat = 0
    @State private var isHoveringClose = false
    @State private var isHoveringExpand = false

    private var displayText: String {
        model.isFullExpanded && !model.conversation.isEmpty
            ? model.conversation
            : model.message
    }

    private var messageMaxHeight: CGFloat {
        model.isFullExpanded ? 280 : 56
    }

    /// The island width — determined by mode
    private var islandWidth: CGFloat {
        let geometry = model.geometry
        let needsWide = model.isFullExpanded || model.isElicitation || model.isPermission
        return geometry.effectiveWidth(interactive: model.interactive, fullExpanded: needsWide)
    }

    /// The island height — content-driven, clamped between notch height and panel max.
    private var islandHeight: CGFloat {
        let geometry = model.geometry
        let minH = geometry.notchHeight
        let maxH = geometry.maxPanelHeight
        return max(minH, min(contentHeight, maxH))
    }

    var body: some View {
        let geometry = model.geometry

        // The island shape — animates its own size within the fixed panel
        ZStack(alignment: .top) {
            // Pure black background — blends seamlessly with the notch
            Color.black

            // Content VStack — measured for intrinsic height
            VStack(spacing: 6) {
                // Small top padding — header sits inside the notch area
                Spacer()
                    .frame(height: max((geometry.notchHeight - 22) / 2, 4))

                // Header: agent name + expand + close
                headerView

                if model.isElicitation {
                    elicitationView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if model.isPermission {
                    permissionView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    // Scrollable message/conversation area
                    if model.interactive && !displayText.isEmpty {
                        messageScrollView
                    }

                    // Input field
                    if model.interactive {
                        inputFieldView
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(ContentHeightKey.self) { newHeight in
                if abs(contentHeight - newHeight) > 1 {
                    contentHeight = newHeight
                }
            }
        }
        .frame(width: islandWidth, height: islandHeight)
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: geometry.hasNotch ? 8 : 14,
                    bottomLeading: 22,
                    bottomTrailing: 22,
                    topTrailing: geometry.hasNotch ? 8 : 14
                ),
                style: .continuous
            )
        )
        .overlay(
            // Subtle border for the island shape
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: geometry.hasNotch ? 8 : 14,
                    bottomLeading: 22,
                    bottomTrailing: 22,
                    topTrailing: geometry.hasNotch ? 8 : 14
                ),
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.5
            )
        )
        // Soft ambient shadow
        .shadow(color: Color.black.opacity(0.5), radius: 30, y: 10)
        .shadow(color: Color.black.opacity(0.3), radius: 60, y: 20)
        // Anchor at top-center so expand grows downward from the notch
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
        .animation(.smooth(duration: 0.35), value: model.isFullExpanded)
        .animation(.smooth(duration: 0.3), value: contentHeight)
        .onExitCommand { onClose() }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            // Status indicator dot with pulse animation for permission/elicitation
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .shadow(color: statusColor.opacity(0.6), radius: 4)

            if !model.agentName.isEmpty {
                Text(model.agentName)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(0.3)
            }

            if model.isElicitation {
                Text("asks")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
            } else if model.isPermission {
                Text("wants to use")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                Text(model.permissionTool)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.orange.opacity(0.85))
            }

            // Non-interactive: show message inline
            if !model.interactive && !model.message.isEmpty {
                Text(model.message)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Expand/collapse button
            if model.interactive && !model.conversation.isEmpty && !model.isPermission {
                headerButton(
                    icon: model.isFullExpanded
                        ? "arrowtriangle.right.and.line.vertical.and.arrowtriangle.left.fill"
                        : "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right.fill",
                    isHovering: $isHoveringExpand
                ) {
                    model.toggleExpand()
                }
            }

            // Close button
            headerButton(icon: "xmark", isHovering: $isHoveringClose) {
                onClose()
            }
        }
        .padding(.bottom, 2)
    }

    private func headerButton(icon: String, isHovering: Binding<Bool>, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(.white.opacity(isHovering.wrappedValue ? 0.8 : 0.4))
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isHovering.wrappedValue ? 0.15 : 0.07))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering.wrappedValue = hovering
            }
        }
    }

    private var statusColor: Color {
        if model.isElicitation { return islandAccent }
        if model.isPermission { return Color.orange }
        return Color(red: 0.3, green: 0.85, blue: 0.5)
    }

    // MARK: - Elicitation View

    private var elicitationView: some View {
        VStack(spacing: 8) {
            // Question text
            Text(model.elicitationQuestion)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(bodyText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)

            // Option buttons
            ForEach(model.elicitationOptions) { option in
                elicitationOptionButton(option)
            }

            // Text field for custom answer
            elicitationInputField
        }
    }

    private func elicitationOptionButton(_ option: ElicitationOption) -> some View {
        Button(action: { model.answerElicitation(option.label) }) {
            HStack(spacing: 8) {
                Text(option.label)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                if let desc = option.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(dimText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.2))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [islandAccent.opacity(0.35), islandAccent.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var elicitationInputField: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                if model.inputText.isEmpty {
                    Text("Type a custom answer...")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color(white: 0.4))
                }
                TextField("", text: $model.inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white)
                    .tint(islandAccent)
                    .focused($isInputFocused)
                    .onSubmit { model.answerElicitation(model.inputText) }
            }

            sendButton(small: true) {
                let text = model.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { model.answerElicitation(text) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(surfaceBorder, lineWidth: 0.8)
        )
    }

    // MARK: - Permission View

    private var permissionView: some View {
        VStack(spacing: 10) {
            // Command display
            if !model.permissionCommand.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(model.permissionCommand)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .frame(maxHeight: 60)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                )
            }

            // Approve / Deny buttons
            HStack(spacing: 10) {
                // Deny button
                Button(action: { model.denyPermission() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Deny")
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                    )
                }
                .buttonStyle(ScaleButtonStyle())

                // Allow button
                Button(action: { model.approvePermission() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Allow")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.3), Color.green.opacity(0.2)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.green.opacity(0.45), lineWidth: 0.8)
                    )
                    .shadow(color: Color.green.opacity(0.25), radius: 12)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            // "Always allow" suggestion buttons
            if !model.permissionSuggestions.isEmpty {
                ForEach(model.permissionSuggestions) { suggestion in
                    Button(action: { model.selectSuggestion(suggestion) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 10))
                            Text(suggestion.label)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundColor(islandAccent.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(islandAccent.opacity(0.08))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(islandAccent.opacity(0.2), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    // MARK: - Message Scroll

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                MarkdownText(displayText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 2)
                    .id("msg-end")
            }
            .frame(maxHeight: messageMaxHeight)
            .mask(
                // Fade out at bottom edge when content is clipped
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
            .onAppear {
                proxy.scrollTo("msg-end", anchor: .bottom)
            }
        }
        .id(displayText)
    }

    // MARK: - Input Field

    private var inputFieldView: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                if model.inputText.isEmpty {
                    Text("Type your response...")
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundColor(Color(white: 0.42))
                }
                TextField("", text: $model.inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundColor(.white)
                    .tint(islandAccent)
                    .focused($isInputFocused)
                    .onSubmit { model.submit() }
            }

            sendButton(small: false) {
                model.submit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    islandAccent.opacity(isInputFocused ? 0.9 : 0.6),
                    lineWidth: 1.5
                )
                .shadow(color: islandAccent.opacity(isInputFocused ? 0.6 : 0.3), radius: isInputFocused ? 12 : 8)
                .shadow(color: islandAccent.opacity(isInputFocused ? 0.4 : 0.2), radius: isInputFocused ? 24 : 16)
                .shadow(color: Color(red: 0.25, green: 0.55, blue: 1.0).opacity(isInputFocused ? 0.3 : 0.15), radius: isInputFocused ? 40 : 30)
        )
        .animation(.easeOut(duration: 0.25), value: isInputFocused)
    }

    // MARK: - Shared Components

    private func sendButton(small: Bool, action: @escaping () -> Void) -> some View {
        let isEmpty = model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: small ? 10 : 11, weight: .bold))
                .foregroundColor(isEmpty ? .white.opacity(0.15) : .white)
                .frame(width: small ? 20 : 24, height: small ? 20 : 24)
                .background(
                    Circle()
                        .fill(isEmpty ? Color.white.opacity(0.06) : islandAccent)
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isEmpty)
        .animation(.easeOut(duration: 0.2), value: isEmpty)
    }
}

// MARK: - Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
