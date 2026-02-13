import Foundation

@MainActor
enum ChatPromptBuilder {

    static func buildSystemPrompt(workoutStore: WorkoutStore, insightsService: InsightsService) -> String {
        let detailedContext = buildDetailedWorkoutContext(workoutStore: workoutStore)
        let indexSummary = buildIndexSummary(workoutStore: workoutStore, skip: 3)
        let insightsContext = buildInsightsContext(insightsService: insightsService)
        let weeklyStats = buildWeeklyStats(workoutStore: workoutStore)

        return """
        You are a fitness AI assistant inside the Momentary workout app. Users ask you questions about their training data and you respond with rich, structured UI blocks.

        CURRENT WORKOUT DATA:
        \(detailedContext)

        \(indexSummary)

        \(insightsContext)

        THIS WEEK'S STATS:
        \(weeklyStats)

        RESPONSE FORMAT:
        Respond with a JSON object containing a "blocks" array and optionally a "suggestedFollowups" array. Each block has a "type" and a "payload" object.

        AVAILABLE BLOCK TYPES:

        1. "text" — Plain text message
           payload: { "text": "Your message here" }

        2. "workoutSummary" — Summary card for a single workout
           payload: { "workoutId": "uuid", "date": "Jan 15, 2025", "duration": "45 min", "exerciseCount": 4, "totalSets": 16, "totalVolume": 12500.0, "exerciseNames": ["Bench Press", "Squat"] }

        3. "exerciseTable" — Table of sets for one exercise
           payload: { "exerciseName": "Bench Press", "sets": [{"setNumber": 1, "reps": 10, "weight": 135.0, "unit": "lbs"}] }

        4. "metricGrid" — Grid of metric cards
           payload: { "metrics": [{"icon": "figure.strengthtraining.traditional", "value": "3", "title": "Workouts", "subtitle": "this week"}] }

        5. "chart" — Chart visualization
           payload: { "chartType": "volumeOverTime"|"progressTrend"|"prComparison"|"generic", "dataPoints": [{"label": "Mon", "value": 5000, "date": "2025-01-13", "isPR": false}] }
           For chartType "generic", you may also include:
           - "xAxisLabel": label for X axis (e.g. "Week")
           - "yAxisLabel": label for Y axis (e.g. "Volume (lbs)")
           - "chartStyle": "bar" (default) or "line"

        6. "insight" — Insight card with type badge
           payload: { "insightType": "progressNote"|"formReminder"|"motivational"|"recovery"|"weeklyReview"|"newPRs"|"trendingUp"|"nextGoals", "title": "Title", "body": "Body text" }

        7. "actionButtons" — Row of action buttons
           payload: { "actions": [{"label": "Start Workout", "actionType": "startWorkout"}] }
           Action types: "startWorkout", "viewWorkout" (requires "workoutId"), "analyzeWorkout" (requires "workoutId"), "exportData"

        8. "workoutList" — List of clickable workout rows
           payload: { "workouts": [{"workoutId": "uuid", "date": "Jan 15", "summary": "Chest & Back", "volume": 12500.0}] }

        SUGGESTED FOLLOWUPS:
        Include a "suggestedFollowups" array at the top level of your JSON response with 2-3 short follow-up questions the user might ask next. Keep each under 40 characters.
        Example: "suggestedFollowups": ["Show my bench progress", "Compare to last week", "Any new PRs?"]

        RULES:
        - Always start with a "text" block as your greeting/explanation
        - Use rich blocks (workoutSummary, exerciseTable, chart, metricGrid) when the data supports it
        - End with "actionButtons" to suggest next steps when appropriate
        - Use workout IDs from the data provided — never invent IDs
        - Keep text blocks concise and conversational
        - For volume values, use raw numbers (not formatted strings)
        - For dates in data points, use "yyyy-MM-dd" format
        - Use the "generic" chart type with "chartStyle" when the user asks for a custom chart
        - Respond ONLY with valid JSON. No markdown, no explanation outside JSON.
        """
    }

    // MARK: - Detailed Workout Context

    private static func buildDetailedWorkoutContext(workoutStore: WorkoutStore) -> String {
        let index = workoutStore.index
        guard !index.isEmpty else {
            return "No workouts recorded yet."
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var lines: [String] = []
        lines.append("Recent workouts (\(index.count) total):")

        // Detailed context for top 3 workouts
        let detailedCount = min(3, index.count)
        for i in 0..<detailedCount {
            let entry = index[i]
            let dateStr = dateFormatter.string(from: entry.startedAt)
            let durationMin = entry.duration.map { "\(Int($0 / 60)) min" } ?? "in progress"
            let volume = entry.totalVolume > 0 ? String(format: "%.0f lbs", entry.totalVolume) : "no volume"

            lines.append("- [\(entry.id.uuidString)] \(dateStr) | \(durationMin) | \(entry.exerciseCount) exercises | \(entry.totalSets) sets | \(volume)")

            // Load detailed exercise data if available
            if entry.hasStructuredLog, let session = workoutStore.loadSession(id: entry.id),
               let log = session.structuredLog {
                let exercises = log.exercises.prefix(6)
                for exercise in exercises {
                    let setsDesc = exercise.sets.map { set -> String in
                        let w = set.weight.map { "\(Int($0))" } ?? "BW"
                        let r = set.reps.map { "\($0)" } ?? "?"
                        return "\(w)x\(r)"
                    }.joined(separator: ", ")
                    let unit = exercise.sets.first?.weightUnit.rawValue ?? "lbs"
                    lines.append("  \(exercise.exerciseName): \(setsDesc) \(unit)")
                }
                if log.exercises.count > 6 {
                    lines.append("  and \(log.exercises.count - 6) more exercises")
                }
            } else {
                let exercises = entry.exerciseNames.isEmpty ? "no exercises logged" : entry.exerciseNames.joined(separator: ", ")
                lines.append("  Exercises: \(exercises)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Index Summary (remaining workouts)

    private static func buildIndexSummary(workoutStore: WorkoutStore, skip: Int) -> String {
        let index = workoutStore.index
        guard index.count > skip else { return "" }

        let remaining = index.dropFirst(skip).prefix(5)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        var lines: [String] = ["OLDER WORKOUTS:"]
        for entry in remaining {
            let dateStr = dateFormatter.string(from: entry.startedAt)
            let durationMin = entry.duration.map { "\(Int($0 / 60)) min" } ?? "?"
            let exercises = entry.exerciseNames.isEmpty ? "no exercises" : entry.exerciseNames.joined(separator: ", ")
            let volume = entry.totalVolume > 0 ? String(format: "%.0f lbs", entry.totalVolume) : ""
            lines.append("- [\(entry.id.uuidString)] \(dateStr) | \(durationMin) | \(exercises) | \(volume)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Insights Context

    private static func buildInsightsContext(insightsService: InsightsService) -> String {
        var sections: [String] = []

        // PRs from stories
        let prStories = insightsService.stories.filter { $0.type == .newPRs }
        if !prStories.isEmpty {
            var prLines = ["RECENT PERSONAL RECORDS:"]
            for story in prStories.prefix(3) {
                prLines.append("- \(story.title): \(story.body)")
            }
            sections.append(prLines.joined(separator: "\n"))
        }

        // Trends
        let trendStories = insightsService.stories.filter { $0.type == .trendingUp }
        if !trendStories.isEmpty {
            var trendLines = ["TRENDING UP:"]
            for story in trendStories.prefix(3) {
                trendLines.append("- \(story.title): \(story.body)")
            }
            sections.append(trendLines.joined(separator: "\n"))
        }

        // Dashboard metrics
        if !insightsService.dashboardMetrics.isEmpty {
            var metricLines = ["DASHBOARD METRICS:"]
            for metric in insightsService.dashboardMetrics.prefix(4) {
                let subtitle = metric.subtitle.map { " (\($0))" } ?? ""
                metricLines.append("- \(metric.title): \(metric.value)\(subtitle)")
            }
            sections.append(metricLines.joined(separator: "\n"))
        }

        guard !sections.isEmpty else { return "" }
        return sections.joined(separator: "\n\n")
    }

    // MARK: - Weekly Stats

    private static func buildWeeklyStats(workoutStore: WorkoutStore) -> String {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let thisWeek = workoutStore.index.filter { $0.startedAt >= weekAgo }

        guard !thisWeek.isEmpty else {
            return "No workouts this week."
        }

        let totalWorkouts = thisWeek.count
        let totalVolume = thisWeek.reduce(0.0) { $0 + $1.totalVolume }
        let totalSets = thisWeek.reduce(0) { $0 + $1.totalSets }
        let totalExercises = thisWeek.reduce(0) { $0 + $1.exerciseCount }
        let allExercises = thisWeek.flatMap(\.exerciseNames)
        let uniqueExercises = Set(allExercises)

        return """
        Workouts: \(totalWorkouts)
        Total volume: \(String(format: "%.0f", totalVolume)) lbs
        Total sets: \(totalSets)
        Total exercises: \(totalExercises) (\(uniqueExercises.count) unique: \(uniqueExercises.joined(separator: ", ")))
        """
    }
}
