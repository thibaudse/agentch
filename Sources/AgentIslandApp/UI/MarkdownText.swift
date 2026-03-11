import SwiftUI

/// Renders markdown text with styling suited for a dark overlay.
/// Handles bold, italic, inline code, code blocks, lists, and headers.
struct MarkdownText: View {
    let text: String
    let fontSize: CGFloat

    init(_ text: String, fontSize: CGFloat = 12) {
        self.text = text
        self.fontSize = fontSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    // MARK: - Block parsing

    private enum Block {
        case paragraph(String)
        case codeBlock(language: String, code: String)
        case listItem(depth: Int, text: String)
        case header(level: Int, text: String)
        case divider
    }

    private var blocks: [Block] {
        var result: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        var pendingParagraph: [String] = []

        func flushParagraph() {
            let joined = pendingParagraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                result.append(.paragraph(joined))
            }
            pendingParagraph = []
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block
            if trimmed.hasPrefix("```") {
                flushParagraph()
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }
                result.append(.codeBlock(language: lang, code: codeLines.joined(separator: "\n")))
                continue
            }

            // Divider
            if trimmed.allSatisfy({ $0 == "-" || $0 == "=" || $0 == "*" }) && trimmed.count >= 3 {
                flushParagraph()
                result.append(.divider)
                i += 1
                continue
            }

            // Header
            if let match = trimmed.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                flushParagraph()
                let level = trimmed[match].filter({ $0 == "#" }).count
                let text = String(trimmed[match.upperBound...])
                result.append(.header(level: level, text: text))
                i += 1
                continue
            }

            // List item
            if let match = trimmed.range(of: #"^[-*+•]\s+"#, options: .regularExpression) {
                flushParagraph()
                let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count
                let depth = indent / 2
                let text = String(trimmed[match.upperBound...])
                result.append(.listItem(depth: depth, text: text))
                i += 1
                continue
            }

            // Numbered list
            if let match = trimmed.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) {
                flushParagraph()
                let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count
                let depth = indent / 2
                let text = String(trimmed[match.upperBound...])
                result.append(.listItem(depth: depth, text: text))
                i += 1
                continue
            }

            // Empty line
            if trimmed.isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // Regular text
            pendingParagraph.append(trimmed)
            i += 1
        }
        flushParagraph()
        return result
    }

    // MARK: - Block rendering

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .paragraph(let text):
            inlineMarkdown(text)

        case .codeBlock(let lang, let code):
            VStack(alignment: .leading, spacing: 0) {
                if !lang.isEmpty {
                    Text(lang)
                        .font(.system(size: fontSize - 2, weight: .medium, design: .monospaced))
                        .foregroundColor(DS.text3)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                }
                Text(code)
                    .font(.system(size: fontSize - 1, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, lang.isEmpty ? 8 : 4)
                    .padding(.bottom, lang.isEmpty ? 0 : 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusS, style: .continuous)
                    .fill(DS.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusS, style: .continuous)
                    .strokeBorder(DS.border1, lineWidth: 0.5)
            )

        case .listItem(let depth, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                    .font(.system(size: fontSize - 1, design: .rounded))
                    .foregroundColor(DS.text3)
                inlineMarkdown(text)
            }
            .padding(.leading, CGFloat(depth) * 12)

        case .header(let level, let text):
            inlineMarkdown(text)
                .font(.system(size: headerSize(level), weight: .bold, design: .rounded))
                .padding(.top, level <= 2 ? 2 : 0)

        case .divider:
            Rectangle()
                .fill(DS.border1)
                .frame(height: 0.5)
                .padding(.vertical, 3)
        }
    }

    private func headerSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return fontSize + 4
        case 2: return fontSize + 2
        default: return fontSize + 1
        }
    }

    // MARK: - Inline markdown → styled Text

    private func inlineMarkdown(_ string: String) -> Text {
        var result = Text("")
        var remaining = string[...]

        while !remaining.isEmpty {
            // Bold + italic: ***text***
            if let (matched, rest) = extractDelimited(&remaining, delimiter: "***") {
                result = result + Text(matched).bold().italic()
                remaining = rest
                continue
            }
            // Bold: **text**
            if let (matched, rest) = extractDelimited(&remaining, delimiter: "**") {
                result = result + Text(matched).bold()
                remaining = rest
                continue
            }
            // Italic: *text*
            if let (matched, rest) = extractSingleDelimited(&remaining, delimiter: "*") {
                result = result + Text(matched).italic()
                remaining = rest
                continue
            }
            // Inline code: `text`
            if let (matched, rest) = extractSingleDelimited(&remaining, delimiter: "`") {
                result = result + Text(matched)
                    .font(.system(size: fontSize - 1, design: .monospaced))
                    .foregroundColor(DS.accentCyan.opacity(0.85))
                remaining = rest
                continue
            }
            // Link: [text](url) — show just the text
            if remaining.hasPrefix("["),
               let closeBracket = remaining.firstIndex(of: "]"),
               remaining.index(after: closeBracket) < remaining.endIndex,
               remaining[remaining.index(after: closeBracket)] == "(" {
                let linkText = remaining[remaining.index(after: remaining.startIndex)..<closeBracket]
                if let closeParen = remaining[closeBracket...].firstIndex(of: ")") {
                    result = result + Text(linkText).underline().foregroundColor(DS.accent)
                    remaining = remaining[remaining.index(after: closeParen)...]
                    continue
                }
            }
            // Plain character
            result = result + Text(String(remaining.removeFirst()))
        }

        return result
            .font(.system(size: fontSize, design: .rounded))
            .foregroundColor(DS.text1)
    }

    // Extract text between paired delimiters like ** or ***
    private func extractDelimited(_ text: inout Substring, delimiter: String) -> (String, Substring)? {
        guard text.hasPrefix(delimiter) else { return nil }
        let after = text.dropFirst(delimiter.count)
        guard let end = after.range(of: delimiter) else { return nil }
        let matched = String(after[after.startIndex..<end.lowerBound])
        guard !matched.isEmpty else { return nil }
        let rest = after[end.upperBound...]
        text = rest
        return (matched, rest)
    }

    // Extract text between single-char delimiters like * or `
    private func extractSingleDelimited(_ text: inout Substring, delimiter: String) -> (String, Substring)? {
        guard text.hasPrefix(delimiter), !text.hasPrefix(delimiter + delimiter) else { return nil }
        let after = text.dropFirst(delimiter.count)
        guard let end = after.range(of: delimiter) else { return nil }
        let matched = String(after[after.startIndex..<end.lowerBound])
        guard !matched.isEmpty else { return nil }
        let rest = after[end.upperBound...]
        text = rest
        return (matched, rest)
    }
}
