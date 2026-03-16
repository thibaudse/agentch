import SwiftUI
import AppKit

private struct ContentHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct IslandShellShape: InsettableShape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat
    var insetAmount: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard !r.isEmpty else { return Path() }

        let maxTop = max(0, min(r.width * 0.5, r.height * 0.5))
        let top = min(max(0, topCornerRadius), maxTop)
        let maxBottom = max(0, min((r.width - 2 * top) * 0.5, r.height - top))
        let bottom = min(max(0, bottomCornerRadius), maxBottom)

        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.minY))

        path.addQuadCurve(
            to: CGPoint(x: r.minX + top, y: r.minY + top),
            control: CGPoint(x: r.minX + top, y: r.minY)
        )

        path.addLine(
            to: CGPoint(x: r.minX + top, y: r.maxY - bottom)
        )

        path.addQuadCurve(
            to: CGPoint(x: r.minX + top + bottom, y: r.maxY),
            control: CGPoint(x: r.minX + top, y: r.maxY)
        )

        path.addLine(
            to: CGPoint(x: r.maxX - top - bottom, y: r.maxY)
        )

        path.addQuadCurve(
            to: CGPoint(x: r.maxX - top, y: r.maxY - bottom),
            control: CGPoint(x: r.maxX - top, y: r.maxY)
        )

        path.addLine(
            to: CGPoint(x: r.maxX - top, y: r.minY + top)
        )

        path.addQuadCurve(
            to: CGPoint(x: r.maxX, y: r.minY),
            control: CGPoint(x: r.maxX - top, y: r.minY)
        )

        path.addLine(to: CGPoint(x: r.minX, y: r.minY))
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
    @State private var isPermissionFileHovering = false

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

    private var collapsedWidth: CGFloat {
        let base = model.geometry.notchWidth
        let count = CGFloat(model.activeSessionCount)
        guard count > 0 else { return base }
        return base + count * 14 + 48
    }

    private var agentPalette: DS.AgentPalette {
        DS.palette(for: model.agentName)
    }

    private var accentColor: Color { agentPalette.accent }
    private var secondaryColor: Color { agentPalette.secondary }

    private var statusColor: Color { accentColor }

    var body: some View {
        let geometry = model.geometry
        let radii = cornerRadii(for: geometry, expanded: model.expanded)
        let shellShape = islandShape(geometry)
        let topSeamInset = radii.top
        // Keep internal layout padding relative to the visible black shell,
        // not the transparent corner cutout area.
        let shellHorizontalPadding = DS.sp24 + radii.top

        ZStack(alignment: .top) {
            Color.black

            VStack(spacing: 0) {
                // ── Notch zone: visual controls only (dot + buttons) ──
                // These sit in the physical notch area; buttons at the
                // edges are visible past the notch sides.
                notchControls
                    .padding(.horizontal, shellHorizontalPadding)
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
                .padding(.horizontal, shellHorizontalPadding)
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
            width: model.expanded ? islandWidth : collapsedWidth,
            height: model.expanded ? islandHeight : geometry.notchHeight
        )
        .clipShape(shellShape)
        .shadow(color: .black.opacity(model.expanded ? 0.5 : 0), radius: 24, y: 8)
        .shadow(color: .black.opacity(model.expanded ? 0.3 : 0), radius: 8, y: 4)
        .overlay(
            shellShape
                .strokeBorder(DS.borderGradient(top: 0.12, bottom: 0.03), lineWidth: 0.5)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 1)
                .padding(.horizontal, topSeamInset)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .leading) {
            sessionDots
                .padding(.leading, 18)
                .opacity(!model.expanded && model.activeSessionCount > 0 ? 1 : 0)
                .allowsHitTesting(false)
        }
        .frame(
            maxWidth: geometry.fullExpandedWidth,
            maxHeight: geometry.notchHeight + AppConfig.maxIslandExtraHeight,
            alignment: .top
        )
        .animation(model.expanded ? DS.Anim.notchOpen : DS.Anim.notchClose, value: model.expanded)
        .animation((model.isPermission || model.isElicitation) ? nil : DS.Anim.content, value: contentHeight)
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

    private func cornerRadii(for geo: NotchGeometry, expanded: Bool) -> (top: CGFloat, bottom: CGFloat) {
        let base = max(geo.notchHeight, 1)
        let closedTop = max(2, base * 0.1875)      // 6 at 32pt notch
        let closedBottom = max(4, base * 0.4375)   // 14 at 32pt notch
        let openTop = max(closedTop, base * 0.59375)       // 19 at 32pt notch
        let openBottom = max(closedBottom, base * 0.75)    // 24 at 32pt notch
        return expanded ? (openTop, openBottom) : (closedTop, closedBottom)
    }

    private func islandShape(_ geo: NotchGeometry) -> IslandShellShape {
        let radii = cornerRadii(for: geo, expanded: model.expanded)
        return IslandShellShape(topCornerRadius: radii.top, bottomCornerRadius: radii.bottom)
    }

    // MARK: - Notch Controls + Header Pills (single row aligned to the notch)

    private var notchCenterGapWidth: CGFloat {
        model.geometry.hasNotch ? model.geometry.notchWidth + DS.sp8 : DS.sp12
    }

    private var displayedSessionLabel: String {
        let raw = model.sessionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return raw }

        var label = raw
        if let lastComponent = raw.split(separator: "/").last,
           raw.contains("/"),
           !lastComponent.isEmpty {
            label = String(lastComponent)
        }

        let maxCharacters = (model.isPermission || model.isElicitation) ? 24 : 30
        return abbreviatedSessionLabel(label, maxCharacters: maxCharacters)
    }

    private func abbreviatedSessionLabel(_ text: String, maxCharacters: Int) -> String {
        guard maxCharacters > 6, text.count > maxCharacters else { return text }
        return String(text.prefix(maxCharacters - 3)) + "..."
    }

    private var sessionDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<model.activeSessionCount, id: \.self) { _ in
                Circle()
                    .fill(DS.claudeAccent)
                    .frame(width: 6, height: 6)
                    .shadow(color: DS.claudeAccent.opacity(0.7), radius: 4)
            }
        }
    }

    private var displayedPermissionTool: String {
        abbreviatedSessionLabel(model.permissionTool.trimmingCharacters(in: .whitespacesAndNewlines), maxCharacters: 28)
    }

    private var notchControls: some View {
        HStack(spacing: DS.sp8) {
            notchLeftControls
                .layoutPriority(2)

            Spacer(minLength: notchCenterGapWidth)

            notchRightControls
                .layoutPriority(1)
        }
    }

    private var notchLeftControls: some View {
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

            if !model.sessionLabel.isEmpty {
                HStack(spacing: DS.sp4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text(displayedSessionLabel)
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .foregroundColor(secondaryColor.opacity(0.88))
                .padding(.horizontal, DS.sp6)
                .padding(.vertical, DS.sp2)
                .fixedSize(horizontal: true, vertical: false)
                .help(model.sessionLabel)
                .fadedCapsuleSurface()
            }
        }
    }

    private var notchRightControls: some View {
        HStack(spacing: DS.sp8) {
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
                Text(displayedPermissionTool)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(accentColor.opacity(0.90))
                    .padding(.horizontal, DS.sp6)
                    .padding(.vertical, DS.sp2)
                    .fixedSize(horizontal: true, vertical: false)
                    .help(model.permissionTool)
                    .fadedCapsuleSurface()
            }

            if model.interactive && !model.conversation.isEmpty && !model.isPermission {
                DSHeaderButton(
                    icon: model.isFullExpanded
                        ? "arrow.down.right.and.arrow.up.left"
                        : "arrow.up.left.and.arrow.down.right",
                    variant: .secondary,
                    accent: accentColor,
                    secondary: secondaryColor
                ) {
                    withAnimation(DS.Anim.expand) {
                        model.toggleExpand()
                    }
                }
            }

            DSHeaderButton(
                icon: "xmark",
                variant: .secondary,
                accent: accentColor,
                secondary: secondaryColor
            ) {
                onClose()
            }
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
        DSPillButton(
            action: { model.answerElicitation(option.label) },
            variant: .secondary,
            accent: accentColor,
            secondary: secondaryColor,
            cornerRadius: DS.radiusM
        ) {
            HStack(spacing: DS.sp8) {
                Text(option.label)
                    .font(DS.Font.subheadline)
                    .foregroundColor(secondaryColor)
                if let desc = option.description, !desc.isEmpty {
                    Text(desc)
                        .font(DS.Font.caption)
                        .foregroundColor(DS.text2)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(secondaryColor.opacity(0.65))
            }
        }
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
                    .tint(accentColor)
                    .focused($isInputFocused)
                    .onSubmit { model.answerElicitation(model.inputText) }
            }

            DSSendButton(
                small: true,
                isEmpty: model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                accent: accentColor,
                secondary: secondaryColor
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
            if isBashPermission,
               let description = permissionCommandDescription,
               !description.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Description")
                        .font(DS.Font.caption)
                        .foregroundColor(DS.text3)
                    Text(description)
                        .font(DS.Font.bodyMedium)
                        .foregroundColor(DS.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.sp8)
            }

            if hasPermissionCodeBlock {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: DS.sp8) {
                        if permissionFilePath != nil || permissionReplaceAllValue != nil {
                            VStack(alignment: .leading, spacing: DS.sp6) {
                                if let filePath = permissionFilePath {
                                    Button(action: { openPermissionFile(filePath) }) {
                                        HStack(spacing: DS.sp8) {
                                            Image(systemName: "doc.text")
                                                .font(.system(size: 10, weight: .semibold))
                                            Text(filePath)
                                                .font(DS.Font.mono)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .underline(isPermissionFileHovering, color: accentColor.opacity(0.55))
                                            Spacer(minLength: 0)
                                            Image(systemName: "arrow.up.right.square")
                                                .font(.system(size: 10, weight: .semibold))
                                        }
                                        .foregroundColor(accentColor)
                                        .padding(.horizontal, DS.sp8)
                                        .padding(.vertical, DS.sp4)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { hovering in
                                        isPermissionFileHovering = hovering
                                        if hovering {
                                            NSCursor.pointingHand.push()
                                        } else {
                                            NSCursor.pop()
                                        }
                                    }
                                }

                                if let replaceAll = permissionReplaceAllValue {
                                    Text("replace_all: \(replaceAll)")
                                        .font(DS.Font.caption)
                                        .foregroundColor(DS.text2)
                                        .padding(.horizontal, DS.sp8)
                                }
                            }
                        }

                        if isBashPermission {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(permissionCommandLines.enumerated()), id: \.offset) { _, line in
                                    Text(verbatim: line)
                                        .font(DS.Font.mono)
                                        .foregroundColor(DS.text1.opacity(0.94))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DS.sp10)
                            .padding(.vertical, DS.sp8)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(permissionPreviewRows) { row in
                                    HStack(alignment: .firstTextBaseline, spacing: DS.sp10) {
                                        Text(row.number.isEmpty ? " " : row.number)
                                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                                            .foregroundColor(DS.text3)
                                            .frame(width: 28, alignment: .trailing)

                                        Text(verbatim: row.text.isEmpty ? " " : row.text)
                                            .font(DS.Font.mono)
                                            .foregroundColor(permissionLineForeground(row.style))
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, DS.sp10)
                                    .padding(.vertical, 3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(permissionLineBackground(row.style))
                                }
                            }
                            .padding(.horizontal, DS.sp2)
                        }
                    }
                    .padding(.vertical, DS.sp6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: isBashPermission ? 180 : 160)
                .background(
                    RoundedRectangle(cornerRadius: DS.radiusS + 2, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radiusS + 2, style: .continuous)
                        .strokeBorder(DS.tintedBorder(secondaryColor, top: 0.28, bottom: 0.08), lineWidth: 0.8)
                )
            }

            // Yes / No
            HStack(spacing: DS.sp10) {
                // No (deny)
                DSPillButton(
                    action: { model.denyPermission() },
                    variant: .secondary,
                    accent: accentColor,
                    secondary: secondaryColor
                ) {
                    Text("No")
                        .font(DS.Font.bodyMedium)
                }

                // Yes (allow)
                DSPillButton(
                    action: { model.approvePermission() },
                    variant: .primary,
                    accent: accentColor,
                    secondary: secondaryColor
                ) {
                    Text("Yes")
                        .font(DS.Font.subheadline)
                }
            }

            // "Always allow" suggestions
            if !model.permissionSuggestions.isEmpty {
                ForEach(Array(model.permissionSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                    DSPillButton(
                        action: { model.selectSuggestion(suggestion) },
                        variant: .secondary,
                        accent: accentColor,
                        secondary: secondaryColor
                    ) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 10))
                            Text(suggestion.label)
                                .font(DS.Font.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(secondaryColor)
                    }
                }
            }
        }
    }

    private enum PermissionLineStyle {
        case file
        case added
        case removed
        case meta
        case normal
    }

    private struct PermissionPreviewRow: Identifiable {
        let id: Int
        let number: String
        let text: String
        let style: PermissionLineStyle
    }

    private var permissionRawLines: [String] {
        model.permissionCommand.components(separatedBy: .newlines)
    }

    private var isBashPermission: Bool {
        model.permissionTool.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "bash"
    }

    private var permissionCommandDescription: String? {
        guard isBashPermission else { return nil }
        for line in permissionBodyLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let value = descriptionValue(from: trimmed) else { continue }
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private var permissionCommandLines: [String] {
        guard isBashPermission else { return [] }

        var lines: [String] = []
        for line in permissionBodyLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed == "Command" { continue }
            if descriptionValue(from: trimmed) != nil { continue }

            if line.hasPrefix("$ ") {
                lines.append(String(line.dropFirst(2)))
            } else if line.hasPrefix("  ") {
                lines.append(String(line.dropFirst(2)))
            } else {
                lines.append(line)
            }
        }
        return lines
    }

    private func descriptionValue(from trimmedLine: String) -> String? {
        guard let colonIndex = trimmedLine.firstIndex(of: ":") else { return nil }
        let key = trimmedLine[..<colonIndex].trimmingCharacters(in: .whitespaces)
        guard key.lowercased() == "description" else { return nil }

        let valueStart = trimmedLine.index(after: colonIndex)
        return String(trimmedLine[valueStart...]).trimmingCharacters(in: .whitespaces)
    }

    private var hasPermissionCodeBlock: Bool {
        if permissionFilePath != nil || permissionReplaceAllValue != nil {
            return true
        }
        if isBashPermission {
            return !permissionCommandLines.isEmpty
        }
        return !permissionPreviewRows.isEmpty
    }

    private var permissionFilePath: String? {
        for line in permissionRawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("File:") else { continue }
            let value = String(trimmed.dropFirst("File:".count)).trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private var permissionReplaceAllValue: String? {
        for line in permissionRawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("replace_all:") else { continue }
            let value = String(trimmed.dropFirst("replace_all:".count)).trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private var permissionBodyLines: [String] {
        let filtered = permissionRawLines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("File:") { return false }
            if trimmed.hasPrefix("replace_all:") { return false }
            return true
        }

        var start = 0
        while start < filtered.count && filtered[start].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            start += 1
        }

        guard start < filtered.count else { return [] }
        return Array(filtered[start...])
    }

    private var permissionPreviewRows: [PermissionPreviewRow] {
        let lines = permissionBodyLines
        var rows: [PermissionPreviewRow] = []

        var oldLine: Int?
        var newLine: Int?
        var plainLine = 1
        var hasDiffNumbering = false

        for (index, line) in lines.enumerated() {
            let style = permissionLineStyle(for: line)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let hunk = parseDiffHunkLineNumbers(from: trimmed) {
                oldLine = hunk.oldStart
                newLine = hunk.newStart
                hasDiffNumbering = true
            }

            var number = ""

            if line.hasPrefix("  ") {
                if let n = newLine { number = "\(n)" }
                oldLine = oldLine.map { $0 + 1 }
                newLine = newLine.map { $0 + 1 }
            } else if line.hasPrefix("+ ") {
                if let n = newLine { number = "\(n)" }
                newLine = newLine.map { $0 + 1 }
            } else if line.hasPrefix("- ") {
                if let n = oldLine { number = "\(n)" }
                oldLine = oldLine.map { $0 + 1 }
            } else if trimmed.hasPrefix("+++ proposed") && oldLine == nil && newLine == nil {
                // Write-style preview without unified diff hunk headers.
                oldLine = 1
                newLine = 1
                hasDiffNumbering = true
            } else if !hasDiffNumbering && !trimmed.isEmpty {
                // Plain command/file preview fallback (ex: Bash command block).
                number = "\(plainLine)"
                plainLine += 1
            }

            rows.append(
                PermissionPreviewRow(
                    id: index,
                    number: number,
                    text: line,
                    style: style
                )
            )
        }

        return rows
    }

    private func openPermissionFile(_ path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else { return }

        let xedPath = "/usr/bin/xed"
        if FileManager.default.isExecutableFile(atPath: xedPath) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: xedPath)
            process.arguments = [expanded]
            try? process.run()
            return
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
    }

    private func parseDiffHunkLineNumbers(from line: String) -> (oldStart: Int, newStart: Int)? {
        let pattern = #"@@\s*-(\d+)(?:,\d+)?\s+\+(\d+)(?:,\d+)?\s*@@"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range), match.numberOfRanges >= 3 else {
            return nil
        }

        guard
            let oldRange = Range(match.range(at: 1), in: line),
            let newRange = Range(match.range(at: 2), in: line),
            let oldStart = Int(line[oldRange]),
            let newStart = Int(line[newRange])
        else {
            return nil
        }

        return (oldStart, newStart)
    }

    private func permissionLineStyle(for line: String) -> PermissionLineStyle {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("File:") || trimmed.hasPrefix("Command") || trimmed.hasPrefix("Edit ") {
            return .file
        }
        if trimmed.hasPrefix("replace_all:") || trimmed.hasPrefix("description:") || trimmed.hasPrefix("...") {
            return .meta
        }
        if line.hasPrefix("+ ") || line == "+" { return .added }
        if line.hasPrefix("- ") || line == "-" { return .removed }
        return .normal
    }

    private func permissionLineForeground(_ style: PermissionLineStyle) -> Color {
        switch style {
        case .file:
            return DS.text1
        case .added:
            return accentColor.opacity(0.95)
        case .removed:
            return secondaryColor.opacity(0.95)
        case .meta:
            return DS.text2
        case .normal:
            return DS.text1.opacity(0.92)
        }
    }

    @ViewBuilder
    private func permissionLineBackground(_ style: PermissionLineStyle) -> some View {
        switch style {
        case .added:
            accentColor.opacity(0.16)
        case .removed:
            secondaryColor.opacity(0.15)
        default:
            Color.clear
        }
    }

    // MARK: - Message Scroll

    private var notificationMessageView: some View {
        Text(model.message)
            .font(DS.Font.bodyMedium)
            .foregroundColor(DS.text1)
            .textSelection(.enabled)
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
                        ConversationView(
                            text: model.conversation,
                            primaryColor: accentColor,
                            secondaryColor: secondaryColor
                        )
                    } else {
                        MarkdownText(model.message)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .textSelection(.enabled)
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
            .onChange(of: model.isFullExpanded) { _, expanded in
                guard expanded else { return }

                withAnimation(DS.Anim.expand) {
                    proxy.scrollTo("msg-end", anchor: .bottom)
                }

                // Run once more after the blurReplace/layout pass settles.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(DS.Anim.expand) {
                        proxy.scrollTo("msg-end", anchor: .bottom)
                    }
                }
            }
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
                    .tint(accentColor)
                    .focused($isInputFocused)
                    .onSubmit { model.submit() }
            }

            DSSendButton(
                small: false,
                isEmpty: model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                accent: accentColor,
                secondary: secondaryColor
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
            AnimatedGlowBorder(focused: isInputFocused, accent: accentColor, secondary: secondaryColor)
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
                DSPillButton(
                    action: {
                        if isShown {
                            hideNotch()
                        } else {
                            showNotch()
                        }
                    },
                    variant: .secondary,
                    accent: DS.accent(for: model.agentName),
                    secondary: DS.secondary(for: model.agentName)
                ) {
                    Text(isShown ? "Hide Notch" : "Show Notch")
                        .font(DS.Font.subheadline)
                }
                .frame(width: 180)
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
        IslandShellShape(topCornerRadius: 19, bottomCornerRadius: 24)
            .fill(Color.black)
            .overlay(
                IslandShellShape(topCornerRadius: 19, bottomCornerRadius: 24)
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
