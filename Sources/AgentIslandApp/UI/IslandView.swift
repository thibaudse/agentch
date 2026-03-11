import SwiftUI

private let islandAccent = Color(red: 0.4, green: 0.7, blue: 1.0)

struct IslandView: View {
    @ObservedObject var model: IslandViewModel
    let onClose: () -> Void

    @FocusState private var isInputFocused: Bool

    private var displayText: String {
        model.isFullExpanded && !model.conversation.isEmpty
            ? model.conversation
            : model.message
    }

    private var messageMaxHeight: CGFloat {
        model.isFullExpanded ? 260 : 52
    }

    var body: some View {
        let geometry = model.geometry
        let width = geometry.effectiveWidth(interactive: model.interactive, fullExpanded: model.isFullExpanded)
        let height = geometry.effectiveHeight(interactive: model.interactive, fullExpanded: model.isFullExpanded)

        // The island shape — animates its own size within the fixed panel
        ZStack(alignment: .bottom) {
            Color.black

            VStack(spacing: 8) {
                // Header: agent name + expand + close
                headerView

                if model.isPermission {
                    permissionView
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
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .frame(width: width, height: height)
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: geometry.hasNotch ? 8 : 12,
                    bottomLeading: 18,
                    bottomTrailing: 18,
                    topTrailing: geometry.hasNotch ? 8 : 12
                ),
                style: .continuous
            )
        )
        // Anchor at top-center so expand grows downward from the notch
        .frame(
            maxWidth: geometry.fullExpandedWidth,
            maxHeight: geometry.fullExpandedHeight,
            alignment: .top
        )
        .scaleEffect(
            x: model.expanded ? 1 : geometry.collapsedScaleX(interactive: model.interactive),
            y: model.expanded ? 1 : geometry.collapsedScaleY(interactive: model.interactive),
            anchor: .top
        )
        .animation(.smooth(duration: 0.3), value: model.isFullExpanded)
        .onExitCommand { onClose() }
        .onChange(of: model.expanded) { _, expanded in
            if expanded && model.interactive && !model.isPermission {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isInputFocused = true
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.isPermission ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
                .shadow(color: (model.isPermission ? Color.orange : Color.green).opacity(0.7), radius: 5)

            if !model.agentName.isEmpty {
                Text(model.agentName)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }

            if model.isPermission {
                Text("wants to use")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                Text(model.permissionTool)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.orange.opacity(0.9))
            }

            // Non-interactive: show message inline
            if !model.interactive && !model.message.isEmpty {
                Text(model.message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Expand/collapse button (only in interactive mode with conversation)
            if model.interactive && !model.conversation.isEmpty && !model.isPermission {
                Button(action: { model.toggleExpand() }) {
                    Image(systemName: model.isFullExpanded ? "arrowtriangle.right.and.line.vertical.and.arrowtriangle.left.fill" : "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Permission View

    private var permissionView: some View {
        VStack(spacing: 10) {
            // Command display
            if !model.permissionCommand.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(model.permissionCommand)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .frame(maxHeight: 60)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
                        )
                )
            }

            // Approve / Deny buttons
            HStack(spacing: 12) {
                Button(action: { model.denyPermission() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                        Text("Deny")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button(action: { model.approvePermission() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                        Text("Allow")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.green.opacity(0.25))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.green.opacity(0.5), lineWidth: 1)
                            .shadow(color: Color.green.opacity(0.4), radius: 8)
                    )
                }
                .buttonStyle(.plain)
            }

            // "Always allow" suggestion buttons
            if !model.permissionSuggestions.isEmpty {
                ForEach(model.permissionSuggestions) { suggestion in
                    Button(action: { model.selectSuggestion(suggestion) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 11))
                            Text(suggestion.label)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundColor(Color.blue.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
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
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(Color(white: 0.55))
                }
                TextField("", text: $model.inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white)
                    .tint(islandAccent)
                    .focused($isInputFocused)
                    .onSubmit { model.submit() }
            }

            Button(action: { model.submit() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(
                        model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .white.opacity(0.15)
                            : islandAccent
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    islandAccent.opacity(0.8),
                    lineWidth: 2
                )
                .shadow(color: islandAccent, radius: 10)
                .shadow(color: islandAccent.opacity(0.8), radius: 20)
                .shadow(color: Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.5), radius: 40)
        )
    }
}
