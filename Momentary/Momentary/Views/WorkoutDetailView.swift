import SwiftUI

struct WorkoutDetailView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(AIProcessingPipeline.self) private var aiPipeline
    let workoutID: UUID

    @State private var session: WorkoutSession?
    @State private var copyFeedbackTrigger = false

    private var isProcessing: Bool {
        if case .processing = aiPipeline.state { return true }
        return false
    }

    private var canAnalyze: Bool {
        guard let session else { return false }
        return !session.moments.isEmpty && session.structuredLog == nil && !isProcessing
    }

    var body: some View {
        Group {
            if let session {
                detailContent(session)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            session = workoutManager.workoutStore.loadSession(id: workoutID)
        }
        .onChange(of: aiPipeline.state) {
            if aiPipeline.state == .completed {
                session = workoutManager.workoutStore.loadSession(id: workoutID)
            }
        }
        .toolbar {
            if canAnalyze {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await analyzeWorkout() }
                    } label: {
                        Label("Analyze", systemImage: "sparkles")
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: copyFeedbackTrigger)
    }

    // MARK: - Detail Content

    private func detailContent(_ session: WorkoutSession) -> some View {
        List {
            summarySection(session)

            if isProcessing, case .processing(let stage) = aiPipeline.state {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(stage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !session.moments.isEmpty {
                momentsSection(session)
            }

            if let log = session.structuredLog {
                structuredLogSection(log)
            }

            if let pack = session.contentPack {
                contentPackSection(pack)
            }

            if !session.stories.isEmpty {
                insightsSection(session.stories)
            }
        }
    }

    // MARK: - Summary

    private func summarySection(_ session: WorkoutSession) -> some View {
        Section("Summary") {
            LabeledContent("Date", value: session.startedAt, format: .dateTime.month().day().year())
            if let duration = session.duration {
                LabeledContent("Duration", value: formatDuration(duration))
            }
            LabeledContent("Moments", value: "\(session.moments.count)")
        }
    }

    // MARK: - Moments

    private func momentsSection(_ session: WorkoutSession) -> some View {
        Section("Moments") {
            ForEach(session.moments) { moment in
                VStack(alignment: .leading, spacing: 4) {
                    Text(moment.transcript)
                        .font(.body)
                    HStack {
                        Text(moment.timestamp, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if moment.source == .watch {
                            Image(systemName: "applewatch")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
                .textSelection(.enabled)
            }
        }
    }

    // MARK: - Structured Log

    private func structuredLogSection(_ log: StructuredLog) -> some View {
        Section("Workout Log") {
            if !log.summary.isEmpty {
                Text(log.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(log.exercises) { exercise in
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.exerciseName)
                        .font(.headline)

                    ForEach(exercise.sets) { set in
                        HStack(spacing: 8) {
                            Text("Set \(set.setNumber)")
                                .font(.caption.bold())
                                .frame(width: 50, alignment: .leading)
                            if let reps = set.reps {
                                Text("\(reps) reps")
                                    .font(.caption)
                            }
                            if let weight = set.weight {
                                Text("\(weight, specifier: "%.0f") \(set.weightUnit.rawValue)")
                                    .font(.caption)
                            }
                            if let notes = set.notes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let notes = exercise.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if !log.ambiguities.isEmpty {
                DisclosureGroup("Ambiguities") {
                    ForEach(log.ambiguities) { ambiguity in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ambiguity.field)
                                .font(.caption.bold())
                            Text("Heard: \"\(ambiguity.rawTranscript)\"")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Best guess: \(ambiguity.bestGuess)")
                                .font(.caption)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    // MARK: - Content Pack

    private func contentPackSection(_ pack: ContentPack) -> some View {
        Section("Content") {
            if !pack.igCaptions.isEmpty {
                DisclosureGroup("Instagram Captions") {
                    ForEach(pack.igCaptions, id: \.self) { caption in
                        copyableText(caption)
                    }
                }
            }

            if !pack.tweetThread.isEmpty {
                DisclosureGroup("Tweet Thread") {
                    ForEach(Array(pack.tweetThread.enumerated()), id: \.offset) { index, tweet in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(index + 1)/\(pack.tweetThread.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            copyableText(tweet)
                        }
                    }
                }
            }

            if !pack.reelScript.isEmpty {
                DisclosureGroup("Reel Script") {
                    copyableText(pack.reelScript)
                }
            }

            if !pack.storyCards.isEmpty {
                DisclosureGroup("Story Cards") {
                    ForEach(pack.storyCards) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.subheadline.bold())
                            Text(card.body)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !pack.hooks.isEmpty {
                DisclosureGroup("Hooks") {
                    ForEach(pack.hooks, id: \.self) { hook in
                        copyableText(hook)
                    }
                }
            }

            if !pack.takeaways.isEmpty {
                DisclosureGroup("Takeaways") {
                    ForEach(pack.takeaways, id: \.self) { takeaway in
                        copyableText(takeaway)
                    }
                }
            }
        }
    }

    // MARK: - Insights

    private func insightsSection(_ stories: [InsightStory]) -> some View {
        Section("Insights") {
            ForEach(stories) { story in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(story.title)
                            .font(.subheadline.bold())
                        Spacer()
                        Text(story.type.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15), in: Capsule())
                    }
                    Text(story.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Actions

    private func analyzeWorkout() async {
        guard let session = workoutManager.workoutStore.loadSession(id: workoutID) else { return }
        await aiPipeline.processWorkout(session)
    }

    // MARK: - Helpers

    private func copyableText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .textSelection(.enabled)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = text
                    copyFeedbackTrigger.toggle()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                ShareLink(item: text)
            }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        if hrs > 0 {
            return "\(hrs)h \(mins)m"
        }
        return "\(mins)m"
    }
}
