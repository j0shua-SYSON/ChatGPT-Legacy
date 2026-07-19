import Foundation
import SwiftUI
import UIKit

struct MessageRow: View {
    let message: ChatMessage
    let isLast: Bool
    let isGenerating: Bool
    let onEdit: () -> Void
    let onRegenerate: () -> Void
    let onShare: (String) -> Void

    var body: some View {
        Group {
            if message.role == .assistant {
                assistantRow
            } else {
                userRow
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            message.role == .assistant ? "message.assistant" : "message.user"
        )
        .contextMenu { contextMenu }
    }

    private var assistantRow: some View {
        HStack(alignment: .top, spacing: 11) {
            conversationRail
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Text("CHATGPT")
                        .font(LegacyTheme.utility)
                        .tracking(1.2)
                    if isLast && isGenerating {
                        Text("STREAMING")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundColor(LegacyTheme.signal)
                    }
                }
                .foregroundColor(LegacyTheme.muted)

                if message.text.isEmpty && isLast && isGenerating {
                    TypingIndicator()
                        .accessibilityLabel("ChatGPT is responding")
                } else {
                    MessageText(text: message.text)
                        .foregroundColor(LegacyTheme.ink)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .padding(.trailing, 10)
    }

    private var userRow: some View {
        HStack {
            Spacer(minLength: 42)
            VStack(alignment: .trailing, spacing: 7) {
                if !message.attachments.isEmpty {
                    AttachmentGrid(attachments: message.attachments)
                        .frame(maxWidth: 286, alignment: .trailing)
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(LegacyTheme.body)
                        .lineSpacing(4)
                        .foregroundColor(LegacyTheme.userText)
                        .textSelection(.enabled)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(LegacyTheme.userBubble)
                        )
                }
                Text("YOU")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(LegacyTheme.faint)
                    .padding(.trailing, 4)
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 22)
    }

    private var conversationRail: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .stroke(LegacyTheme.signal, lineWidth: 1.5)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(LegacyTheme.signal)
                    .frame(width: 4, height: 4)
            }
            Rectangle()
                .fill(LegacyTheme.hairline)
                .frame(width: 1, height: 34)
        }
        .frame(width: 16)
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var contextMenu: some View {
        if !message.text.isEmpty {
            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button {
                onShare(message.text)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        if message.role == .user {
            Button(action: onEdit) {
                Label("Edit and resend", systemImage: "pencil")
            }
        }
        if message.role == .assistant && isLast && !isGenerating {
            Button(action: onRegenerate) {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }
        }
    }
}

private struct MessageText: View {
    let text: String

    var body: some View {
        Group {
            if let attributed = try? AttributedString(
                markdown: text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attributed)
            } else {
                Text(text)
            }
        }
        .font(LegacyTheme.body)
        .lineSpacing(5)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct AttachmentGrid: View {
    let attachments: [ChatAttachment]

    var body: some View {
        let columns = attachments.count == 1
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(attachments) { attachment in
                if let image = UIImage(data: attachment.data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: attachments.count == 1 ? 178 : 112)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .accessibilityLabel("Attached image")
                }
            }
        }
    }
}

private struct TypingIndicator: View {
    var body: some View {
        HStack(spacing: 9) {
            ProgressView()
                .scaleEffect(0.78)
                .tint(LegacyTheme.signal)
            Text("Thinking through it")
                .font(.subheadline)
                .foregroundColor(LegacyTheme.muted)
        }
        .padding(.vertical, 5)
    }
}
