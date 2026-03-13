import SwiftUI

/// Parses and renders a conversation string into visually distinct message bubbles.
///
/// Expects the format: `**You:** text\n\n**Claude:** text\n\n...`
struct ConversationView: View {
    let text: String
    let primaryColor: Color
    let secondaryColor: Color

    init(
        text: String,
        primaryColor: Color = DS.accent,
        secondaryColor: Color = DS.secondary(for: "claude")
    ) {
        self.text = text
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
    }

    private var messages: [ChatMessage] {
        parseChatMessages(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(messages.enumerated()), id: \.offset) { index, msg in
                if index > 0 {
                    Rectangle()
                        .fill(DS.border1)
                        .frame(height: 0.5)
                        .padding(.vertical, DS.sp8)
                }

                VStack(alignment: .leading, spacing: DS.sp4) {
                    // Sender tag
                    HStack(spacing: DS.sp4) {
                        Circle()
                            .fill(msg.isUser ? secondaryColor : primaryColor)
                            .frame(width: 5, height: 5)
                        Text(msg.sender)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(msg.isUser ? secondaryColor : primaryColor)
                            .tracking(0.5)
                            .textCase(.uppercase)
                    }

                    // Message content
                    MarkdownText(msg.content, fontSize: 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, DS.sp2)
    }
}

// MARK: - Parsing

private struct ChatMessage {
    let sender: String
    let content: String
    let isUser: Bool
}

/// Splits conversation text into individual messages.
/// Handles `**You:** ...` and `**Claude:** ...` prefixes.
private func parseChatMessages(_ text: String) -> [ChatMessage] {
    // Split on double-newline boundaries
    let blocks = text.components(separatedBy: "\n\n")
    var messages: [ChatMessage] = []

    for block in blocks {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }

        if trimmed.hasPrefix("**You:**") {
            let content = String(trimmed.dropFirst("**You:**".count)).trimmingCharacters(in: .whitespaces)
            messages.append(ChatMessage(sender: "You", content: content, isUser: true))
        } else if trimmed.hasPrefix("**Claude:**") {
            let content = String(trimmed.dropFirst("**Claude:**".count)).trimmingCharacters(in: .whitespaces)
            messages.append(ChatMessage(sender: "Claude", content: content, isUser: false))
        } else {
            // Continuation of previous message or unattributed text
            if let last = messages.last {
                messages.removeLast()
                let updated = ChatMessage(
                    sender: last.sender,
                    content: last.content + "\n\n" + trimmed,
                    isUser: last.isUser
                )
                messages.append(updated)
            } else {
                messages.append(ChatMessage(sender: "System", content: trimmed, isUser: false))
            }
        }
    }

    return messages
}
