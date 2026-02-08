import SwiftUI

struct InsightsTab: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var selectedTag: String?

    var body: some View {
        NavigationStack {
            Group {
                if allStories.isEmpty {
                    ContentUnavailableView {
                        Label("No Insights Yet", systemImage: "lightbulb")
                    } description: {
                        Text("Complete a workout to get AI-generated insights about your training.")
                    }
                } else {
                    insightsList
                }
            }
            .navigationTitle("Insights")
        }
    }

    private var allStories: [InsightStory] {
        var stories: [InsightStory] = []
        for entry in workoutManager.workoutStore.index {
            if let session = workoutManager.workoutStore.loadSession(id: entry.id) {
                stories.append(contentsOf: session.stories)
            }
        }
        return stories
    }

    private var allTags: [String] {
        let tags = Set(allStories.flatMap(\.tags))
        return tags.sorted()
    }

    private var filteredStories: [InsightStory] {
        guard let tag = selectedTag else { return allStories }
        return allStories.filter { $0.tags.contains(tag) }
    }

    private var insightsList: some View {
        VStack(spacing: 0) {
            if !allTags.isEmpty {
                tagFilter
            }

            List {
                ForEach(filteredStories) { story in
                    storyCard(story)
                }
            }
        }
    }

    private var tagFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedTag == nil) {
                    selectedTag = nil
                }
                ForEach(allTags, id: \.self) { tag in
                    FilterChip(title: tag, isSelected: selectedTag == tag) {
                        selectedTag = tag
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func storyCard(_ story: InsightStory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(story.title)
                    .font(.headline)
                Spacer()
                Text(categoryLabel(story.type))
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(categoryColor(story.type).opacity(0.15), in: Capsule())
                    .foregroundStyle(categoryColor(story.type))
            }

            Text(story.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !story.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(story.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func categoryLabel(_ type: InsightType) -> String {
        switch type {
        case .progressNote: return "Progress"
        case .formReminder: return "Form"
        case .motivational: return "Motivation"
        case .recovery: return "Recovery"
        }
    }

    private func categoryColor(_ type: InsightType) -> Color {
        switch type {
        case .progressNote: return .blue
        case .formReminder: return .orange
        case .motivational: return .green
        case .recovery: return .purple
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.green.opacity(0.2) : Color.secondary.opacity(0.1),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .green : .secondary)
        }
        .buttonStyle(.plain)
    }
}
