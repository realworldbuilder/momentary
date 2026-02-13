import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage
    var onAction: ((ChatAction) -> Void)?
    var onWorkoutTap: ((UUID) -> Void)?
    var onRetry: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    var body: some View {
        if message.isLoading {
            HStack {
                TypingIndicator()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Loading response")
                    .accessibilityRemoveTraits(.isStaticText)
                Spacer()
            }
        } else if message.isStreaming {
            StreamingMessage(message: message)
        } else if message.role == .system {
            SystemNotification(message: message)
        } else if message.role == .user {
            UserBubble(message: message)
        } else {
            AssistantMessage(
                message: message,
                onAction: onAction,
                onWorkoutTap: onWorkoutTap,
                onRetry: onRetry,
                onOpenSettings: onOpenSettings
            )
        }
    }
}

// MARK: - User Bubble

private struct UserBubble: View {
    let message: ChatMessage
    @State private var appeared = false

    var body: some View {
        HStack {
            Spacer()
            Text(message.blocks.first?.payload.text ?? "")
                .font(.body)
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.radiusMedium))
                .accessibilityLabel("You said: \(message.blocks.first?.payload.text ?? "")")
        }
        .scaleEffect(appeared ? 1.0 : 0.85)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

// MARK: - Assistant Message

private struct AssistantMessage: View {
    let message: ChatMessage
    var onAction: ((ChatAction) -> Void)?
    var onWorkoutTap: ((UUID) -> Void)?
    var onRetry: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    @State private var appeared = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(message.blocks) { block in
                    ChatBlockView(
                        block: block,
                        onAction: onAction,
                        onWorkoutTap: onWorkoutTap,
                        onRetry: onRetry,
                        onOpenSettings: onOpenSettings
                    )
                }
            }
            Spacer(minLength: 40)
        }
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                appeared = true
            }
        }
    }
}

// MARK: - Streaming Message

private struct StreamingMessage: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(message.blocks) { block in
                    if let text = block.payload.text, !text.isEmpty {
                        Text(text)
                            .foregroundColor(Theme.textPrimary)
                            .font(.body)
                    }
                }
                StreamingCursor()
            }
            Spacer(minLength: 40)
        }
    }
}

// MARK: - Streaming Cursor

private struct StreamingCursor: View {
    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Theme.accent)
            .frame(width: 2, height: 16)
            .opacity(visible ? 1.0 : 0.0)
            .animation(
                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                value: visible
            )
            .onAppear { visible = false }
    }
}

// MARK: - System Notification

private struct SystemNotification: View {
    let message: ChatMessage

    var body: some View {
        let text = message.blocks.first?.payload.text ?? ""
        HStack(spacing: 8) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(Theme.accent)
            Text(text)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Theme.accentSubtle, in: Capsule())
        .accessibilityLabel("System notification: \(text)")
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Theme.textSecondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(dotScale(for: index))
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.15),
                        value: phase
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .onAppear { phase = 1.0 }
    }

    private func dotScale(for index: Int) -> CGFloat {
        let offset = Double(index) * 0.15
        let t = (phase + offset).truncatingRemainder(dividingBy: 1.0)
        return 0.5 + 0.5 * sin(t * .pi)
    }
}
