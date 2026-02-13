import SwiftUI
import Charts

struct ChatBlockView: View {
    let block: ChatBlock
    var onAction: ((ChatAction) -> Void)?
    var onWorkoutTap: ((UUID) -> Void)?
    var onRetry: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    var body: some View {
        switch block.type {
        case .text:
            TextBlockView(payload: block.payload)
        case .workoutSummary:
            WorkoutSummaryBlockView(payload: block.payload, onWorkoutTap: onWorkoutTap)
        case .exerciseTable:
            ExerciseTableBlockView(payload: block.payload)
        case .metricGrid:
            MetricGridBlockView(payload: block.payload)
        case .chart:
            ChartBlockView_Inner(payload: block.payload)
        case .insight:
            InsightBlockView(payload: block.payload)
        case .actionButtons:
            ActionButtonsBlockView(payload: block.payload, onAction: onAction)
        case .workoutList:
            WorkoutListBlockView(payload: block.payload, onWorkoutTap: onWorkoutTap)
        case .error:
            ErrorBlockView(payload: block.payload, onRetry: onRetry, onOpenSettings: onOpenSettings)
        }
    }
}

// MARK: - Text Block

private struct TextBlockView: View {
    let payload: ChatBlockPayload

    var body: some View {
        Text(payload.text ?? "")
            .foregroundColor(Theme.textPrimary)
            .font(.body)
    }
}

// MARK: - Error Block

private struct ErrorBlockView: View {
    let payload: ChatBlockPayload
    var onRetry: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    @State private var countdown: Double = 0

    private var errorType: String { payload.errorType ?? "unknown" }
    private var errorMessage: String { payload.errorMessage ?? "Something went wrong." }

    private var accentColor: Color {
        switch errorType {
        case "noAPIKey": return .orange
        case "rateLimited": return .yellow
        default: return .red
        }
    }

    private var iconName: String {
        switch errorType {
        case "noAPIKey": return "key.slash"
        case "networkError": return "wifi.slash"
        case "rateLimited": return "clock.badge.exclamationmark"
        case "timeout": return "clock.badge.exclamationmark"
        default: return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .foregroundColor(accentColor)
                    .font(.title3)
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
            }

            HStack(spacing: 10) {
                if errorType == "noAPIKey" {
                    Button {
                        onOpenSettings?()
                    } label: {
                        Text("Open Settings")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                    }
                    .accessibilityLabel("Open Settings")
                }

                if errorType == "rateLimited", countdown > 0 {
                    Text("Retry in \(Int(countdown))s")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                } else {
                    Button {
                        onRetry?()
                    } label: {
                        Text("Retry")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(accentColor.opacity(0.15), in: Capsule())
                    }
                    .accessibilityLabel("Retry sending message")
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .fill(accentColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityLabel(errorMessage)
        .onAppear {
            if errorType == "rateLimited", let retryAfter = payload.retryAfterSeconds {
                countdown = retryAfter
                startCountdown()
            }
        }
    }

    private func startCountdown() {
        guard countdown > 0 else { return }
        Task { @MainActor in
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                countdown -= 1
            }
        }
    }
}

// MARK: - Workout Summary Block

private struct WorkoutSummaryBlockView: View {
    let payload: ChatBlockPayload
    var onWorkoutTap: ((UUID) -> Void)?

    private var accessibilityDescription: String {
        var parts: [String] = []
        if let date = payload.date { parts.append(date) }
        if let duration = payload.duration { parts.append(duration) }
        if let count = payload.exerciseCount { parts.append("\(count) exercises") }
        if let volume = payload.totalVolume, volume > 0 { parts.append(formatVolume(volume)) }
        return "Workout: " + parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let date = payload.date {
                Text(date)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }

            HStack(spacing: 12) {
                if let duration = payload.duration {
                    statPill(icon: "clock", value: duration)
                }
                if let count = payload.exerciseCount {
                    statPill(icon: "dumbbell.fill", value: "\(count)")
                }
                if let sets = payload.totalSets {
                    statPill(icon: "repeat", value: "\(sets)")
                }
            }

            if let volume = payload.totalVolume, volume > 0 {
                Text(formatVolume(volume))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.accent)
            }

            if let names = payload.exerciseNames, !names.isEmpty {
                Text(names.joined(separator: " \u{2022} "))
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .themeCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to view")
        .onTapGesture {
            if let idStr = payload.workoutId, let uuid = UUID(uuidString: idStr) {
                onWorkoutTap?(uuid)
            }
        }
    }

    private func statPill(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.caption)
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05), in: Capsule())
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fK lbs", volume / 1000)
        }
        return String(format: "%.0f lbs", volume)
    }
}

// MARK: - Exercise Table Block

private struct ExerciseTableBlockView: View {
    let payload: ChatBlockPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let name = payload.exerciseName {
                Text(name)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }

            // Header
            HStack {
                Text("Set")
                    .frame(width: 36, alignment: .leading)
                Text("Reps")
                    .frame(width: 44, alignment: .center)
                Text("Weight")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(Theme.textSecondary)

            Divider().overlay(Theme.divider)

            if let sets = payload.sets {
                ForEach(Array(sets.enumerated()), id: \.offset) { _, set in
                    HStack {
                        Text("\(set.setNumber ?? 0)")
                            .frame(width: 36, alignment: .leading)
                        Text(set.reps.map { "\($0)" } ?? "-")
                            .frame(width: 44, alignment: .center)
                        Text(formatWeight(set.weight, unit: set.unit))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.callout)
                    .foregroundColor(Theme.textPrimary)
                    .accessibilityLabel("Set \(set.setNumber ?? 0): \(set.reps.map { "\($0) reps" } ?? "no reps") at \(formatWeight(set.weight, unit: set.unit))")
                }
            }
        }
        .themeCard()
        .accessibilityLabel("Exercise table for \(payload.exerciseName ?? "exercise")")
    }

    private func formatWeight(_ weight: Double?, unit: String?) -> String {
        guard let w = weight else { return "-" }
        return "\(Int(w)) \(unit ?? "lbs")"
    }
}

// MARK: - Metric Grid Block

private struct MetricGridBlockView: View {
    let payload: ChatBlockPayload

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        if let metrics = payload.metrics, !metrics.isEmpty {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(metrics) { metric in
                    ChatMetricCard(metric: metric)
                }
            }
        }
    }
}

private struct ChatMetricCard: View {
    let metric: ChatMetric

    var body: some View {
        VStack(spacing: 6) {
            if let icon = metric.icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(Theme.accent)
            }
            if let value = metric.value {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
            }
            if let title = metric.title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            if let subtitle = metric.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .themeCard()
        .accessibilityLabel("\(metric.title ?? ""): \(metric.value ?? "")")
    }
}

// MARK: - Chart Block

private struct ChartBlockView_Inner: View {
    let payload: ChatBlockPayload

    var body: some View {
        let dataPoints = (payload.dataPoints ?? []).map { $0.toChartDataPoint() }
        let chartType = payload.chartType ?? "volumeOverTime"

        switch chartType {
        case "progressTrend":
            ProgressTrendChart(dataPoints: dataPoints)
                .accessibilityLabel("Chart showing progress trend")
        case "prComparison":
            PRComparisonChart(dataPoints: dataPoints)
                .accessibilityLabel("Chart showing personal records comparison")
        case "generic", "custom":
            GenericChartView(
                dataPoints: dataPoints,
                xAxisLabel: payload.xAxisLabel,
                yAxisLabel: payload.yAxisLabel,
                chartStyle: payload.chartStyle
            )
            .accessibilityLabel("Chart showing \(payload.yAxisLabel ?? "data")")
        default:
            VolumeOverTimeChart(dataPoints: dataPoints)
                .accessibilityLabel("Chart showing volume trend")
        }
    }
}

// MARK: - Generic Chart

private struct GenericChartView: View {
    let dataPoints: [ChartDataPoint]
    var xAxisLabel: String?
    var yAxisLabel: String?
    var chartStyle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let yLabel = yAxisLabel {
                Text(yLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.7))
            }

            if dataPoints.isEmpty {
                emptyChartState
            } else if chartStyle == "line" {
                lineChart
            } else {
                barChart
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.cardBackground)
        )
    }

    private var lineChart: some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value(xAxisLabel ?? "X", point.label),
                y: .value(yAxisLabel ?? "Y", point.value)
            )
            .foregroundStyle(.green)
            .lineStyle(StrokeStyle(lineWidth: 2))

            PointMark(
                x: .value(xAxisLabel ?? "X", point.label),
                y: .value(yAxisLabel ?? "Y", point.value)
            )
            .foregroundStyle(.green)
            .symbolSize(30)
        }
        .frame(height: 150)
        .chartXAxisLabel(xAxisLabel ?? "")
        .chartYAxisLabel(yAxisLabel ?? "")
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.1))
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var barChart: some View {
        Chart(dataPoints) { point in
            BarMark(
                x: .value(xAxisLabel ?? "X", point.label),
                y: .value(yAxisLabel ?? "Y", point.value)
            )
            .foregroundStyle(.green)
            .cornerRadius(4)
        }
        .frame(height: 150)
        .chartXAxisLabel(xAxisLabel ?? "")
        .chartYAxisLabel(yAxisLabel ?? "")
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.1))
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var emptyChartState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.title2)
                .foregroundColor(.gray)
            Text("Not enough data yet")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Insight Block

private struct InsightBlockView: View {
    let payload: ChatBlockPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let title = payload.title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }

                Spacer()

                if let typeStr = payload.insightType,
                   let type = InsightType(rawValue: typeStr) {
                    Text(type.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(type.color.opacity(0.2), in: Capsule())
                        .foregroundColor(type.color)
                }
            }

            if let body = payload.body {
                Text(body)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .themeCard()
    }
}

// MARK: - Action Buttons Block

private struct ActionButtonsBlockView: View {
    let payload: ChatBlockPayload
    var onAction: ((ChatAction) -> Void)?

    var body: some View {
        if let actions = payload.actions, !actions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(actions) { action in
                        Button {
                            onAction?(action)
                        } label: {
                            Text(action.label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Theme.accentSubtle, in: Capsule())
                        }
                        .accessibilityLabel(action.label)
                    }
                }
            }
        }
    }
}

// MARK: - Workout List Block

private struct WorkoutListBlockView: View {
    let payload: ChatBlockPayload
    var onWorkoutTap: ((UUID) -> Void)?

    var body: some View {
        if let workouts = payload.workouts, !workouts.isEmpty {
            VStack(spacing: 8) {
                ForEach(workouts) { workout in
                    Button {
                        if let idStr = workout.workoutId, let uuid = UUID(uuidString: idStr) {
                            onWorkoutTap?(uuid)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                if let date = workout.date {
                                    Text(date)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(Theme.textPrimary)
                                }
                                if let summary = workout.summary {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }

                            Spacer()

                            if let volume = workout.volume, volume > 0 {
                                Text(formatVolume(volume))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.accent)
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Theme.textTertiary)
                        }
                        .themeCard()
                    }
                    .accessibilityLabel("\(workout.date ?? "") \(workout.summary ?? "") \(workout.volume.map { formatVolume($0) } ?? "")")
                    .accessibilityHint("Double tap to view")
                }
            }
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fK", volume / 1000)
        }
        return String(format: "%.0f lbs", volume)
    }
}
