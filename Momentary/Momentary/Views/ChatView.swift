import SwiftUI

struct ChatView: View {
    @Environment(ChatService.self) private var chatService
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(AIProcessingPipeline.self) private var aiPipeline
    @State private var inputText = ""
    @State private var navigationPath = NavigationPath()
    @State private var showExportSheet = false
    @State private var exportData: Data?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                if chatService.messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }

                inputBar
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    tokenTitleView
                }

                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(Theme.textSecondary)
                    }
                    .accessibilityLabel("Settings")
                }

                if !chatService.messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            chatService.newChat()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(Theme.textSecondary)
                        }
                        .accessibilityLabel("New conversation")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { workoutID in
                WorkoutDetailView(workoutID: workoutID)
            }
            .sheet(isPresented: $showExportSheet) {
                if let data = exportData {
                    ShareSheet(data: data)
                }
            }
            .onChange(of: workoutManager.activeSession?.id) { oldValue, newValue in
                if oldValue != nil && newValue == nil {
                    // Workout just ended
                    let notification = ChatMessage(
                        role: .system,
                        blocks: [ChatBlock(type: .text, payload: ChatBlockPayload(text: "Workout completed! Ask me about your latest session."))]
                    )
                    chatService.messages.append(notification)
                }
            }
        }
    }

    // MARK: - Token Title View

    private var tokenTitleView: some View {
        VStack(spacing: 1) {
            Text("Chat")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            if chatService.sessionTokenUsage.totalTokens > 0 {
                Text("\(chatService.sessionTokenUsage.formattedTotal) (\(chatService.sessionTokenUsage.formattedCost))")
                    .font(.caption2)
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(Theme.textTertiary)

            Text("What would you like to know?")
                .font(.title3)
                .foregroundColor(Theme.textSecondary)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                SuggestedChip(text: "Start Workout", icon: "figure.strengthtraining.traditional") {
                    sendMessage("Start a new workout")
                }
                SuggestedChip(text: "Last Workout", icon: "clock.arrow.circlepath") {
                    sendMessage("Show me my last workout")
                }
                SuggestedChip(text: "Weekly Stats", icon: "chart.bar.fill") {
                    sendMessage("How did I do this week?")
                }
                SuggestedChip(text: "New PRs?", icon: "trophy.fill") {
                    sendMessage("Did I hit any new PRs recently?")
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(chatService.messages) { message in
                        ChatMessageView(
                            message: message,
                            onAction: { action in handleAction(action) },
                            onWorkoutTap: { id in navigationPath.append(id) },
                            onRetry: { chatService.retryLastMessage() },
                            onOpenSettings: { navigationPath.append(UUID()) } // Navigate to settings handled below
                        )
                        .id(message.id)
                    }

                    // Follow-up chips
                    if let chips = followupChips {
                        FollowupChipsView(chips: chips) { text in
                            sendMessage(text)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: chatService.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatService.messages.last?.blocks.first?.payload.text) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastID = chatService.messages.last?.id {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    // MARK: - Follow-up Chips

    private var followupChips: [String]? {
        guard !chatService.isResponding,
              let lastMessage = chatService.messages.last,
              lastMessage.role == .assistant,
              let followups = lastMessage.suggestedFollowups,
              !followups.isEmpty else {
            return nil
        }
        return followups
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about your workouts...", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.radiusMedium))
                .foregroundColor(Theme.textPrimary)

            Button {
                sendMessage(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.textTertiary : Theme.accent)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || chatService.isResponding)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.background)
    }

    // MARK: - Actions

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        HapticService.light()
        Task {
            await chatService.send(trimmed)
        }
    }

    private func handleAction(_ action: ChatAction) {
        HapticService.medium()
        switch action.actionType {
        case .startWorkout:
            workoutManager.startWorkout()
        case .viewWorkout:
            if let idStr = action.workoutId, let uuid = UUID(uuidString: idStr) {
                navigationPath.append(uuid)
            }
        case .analyzeWorkout:
            if let idStr = action.workoutId, let uuid = UUID(uuidString: idStr) {
                if let session = workoutManager.workoutStore.loadSession(id: uuid) {
                    Task { await aiPipeline.processWorkout(session) }
                }
            }
        case .exportData:
            if let data = workoutManager.workoutStore.exportAllSessionsAsJSON() {
                exportData = data
                showExportSheet = true
            }
        }
    }
}

// MARK: - Follow-up Chips View

private struct FollowupChipsView: View {
    let chips: [String]
    let onTap: (String) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(chips, id: \.self) { text in
                    Button {
                        onTap(text)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption2)
                            Text(text)
                                .font(.subheadline)
                        }
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.accentSubtle, in: Capsule())
                    }
                    .accessibilityLabel(text)
                    .accessibilityHint("Sends '\(text)' as a question")
                }
            }
            Spacer()
        }
    }
}

// MARK: - Suggested Chip

private struct SuggestedChip: View {
    let text: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.accentSubtle, in: RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let data: Data

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("momentary_export.json")
        try? data.write(to: tempURL)
        return UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
