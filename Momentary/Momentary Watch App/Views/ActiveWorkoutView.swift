import SwiftUI
import WatchKit

struct ActiveWorkoutView: View {
    @Environment(WatchWorkoutManager.self) private var workoutManager

    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State private var isPulsing = false
    @State private var ringRotation: Double = 0
    @State private var dotVisible = true
    @State private var showSnippet = false
    @State private var showSummary = false

    private var idleGradient: [Color] {
        [Color(red: 0.3, green: 0.85, blue: 0.2), Color(red: 0.1, green: 0.65, blue: 0.25)]
    }

    private var recordingGradient: [Color] {
        [Color(red: 0.1, green: 0.9, blue: 0.1), Color(red: 0.0, green: 0.5, blue: 0.15)]
    }

    var body: some View {
        Group {
            if showSummary {
                WorkoutSummaryView(
                    duration: workoutManager.elapsedTime,
                    momentCount: workoutManager.momentCount
                ) {
                    showSummary = false
                    workoutManager.completeWorkoutDismissal()
                }
            } else if isLuminanceReduced {
                alwaysOnView
            } else {
                activeView
            }
        }
        .onChange(of: workoutManager.latestTranscriptSnippet) {
            if workoutManager.latestTranscriptSnippet != nil {
                withAnimation(.easeOut(duration: 0.4)) {
                    showSnippet = true
                }
            }
        }
        .onChange(of: workoutManager.isRecordingMoment) {
            if workoutManager.isRecordingMoment {
                showSnippet = false
                startAnimations()
            } else {
                stopAnimations()
            }
        }
        .onChange(of: workoutManager.didReceiveRemoteStop) {
            if workoutManager.didReceiveRemoteStop {
                showSummary = true
            }
        }
    }

    // MARK: - Active View

    private var activeView: some View {
        VStack(spacing: 8) {
            workoutTimer

            Spacer()

            momentRecordButton

            statusArea

            Spacer()

            snippetCard

            endWorkoutButton
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Always On Display

    private var alwaysOnView: some View {
        VStack(spacing: 10) {
            Spacer()

            Text(formattedElapsed)
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 4) {
                Image(systemName: "waveform")
                    .font(.caption)
                Text("\(workoutManager.momentCount)")
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.4))

            Spacer()
        }
    }

    // MARK: - Workout Timer

    private var workoutTimer: some View {
        Text(formattedElapsed)
            .font(.system(.title3, design: .monospaced))
            .foregroundStyle(.white)
            .accessibilityLabel("Workout time: \(spokenElapsed)")
    }

    // MARK: - Record Button

    private var momentRecordButton: some View {
        Button {
            if workoutManager.isRecordingMoment {
                workoutManager.stopRecordingMoment()
            } else {
                workoutManager.recordMoment()
            }
        } label: {
            ZStack {
                if workoutManager.isRecordingMoment {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.1, green: 0.9, blue: 0.1).opacity(0.4), .clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 55
                            )
                        )
                        .frame(width: 90, height: 90)
                        .opacity(isPulsing ? 0.8 : 0.3)
                        .accessibilityHidden(true)
                }

                if workoutManager.isRecordingMoment {
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: recordingGradient + [recordingGradient[0]],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 82, height: 82)
                        .rotationEffect(.degrees(ringRotation))
                        .accessibilityHidden(true)
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: workoutManager.isRecordingMoment ? recordingGradient : idleGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: workoutManager.isRecordingMoment ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isPulsing ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: workoutManager.isRecordingMoment)
        .accessibilityLabel(workoutManager.isRecordingMoment ? "Stop recording moment" : "Record a moment")
    }

    // MARK: - Status Area

    @ViewBuilder
    private var statusArea: some View {
        if workoutManager.isRecordingMoment {
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .opacity(dotVisible ? 1.0 : 0.0)

                Text(formattedRecordingDuration)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .accessibilityElement(children: .combine)
        } else if workoutManager.connectivity.isSending {
            VStack(spacing: 6) {
                ProgressView()
                    .tint(.green)
                Text("Transcribing")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .fixedSize()
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "waveform")
                    .font(.caption2)
                Text("\(workoutManager.momentCount) moment\(workoutManager.momentCount == 1 ? "" : "s")")
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Snippet Card

    @ViewBuilder
    private var snippetCard: some View {
        if let snippet = workoutManager.latestTranscriptSnippet {
            Text(truncatedSnippet(snippet))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.06))
                )
                .opacity(showSnippet ? 1 : 0)
                .offset(y: showSnippet ? 0 : 12)
        }

        if let error = workoutManager.lastError {
            Label {
                Text(error)
                    .lineLimit(2)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.caption2)
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
        }
    }

    // MARK: - End Workout Button

    private var endWorkoutButton: some View {
        Button {
            workoutManager.endWorkout()
            showSummary = true
        } label: {
            Text("End Workout")
                .font(.caption)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("End workout")
    }

    // MARK: - Helpers

    private var formattedElapsed: String {
        let total = Int(workoutManager.elapsedTime)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }

    private var spokenElapsed: String {
        let total = Int(workoutManager.elapsedTime)
        let mins = total / 60
        let secs = total % 60
        if mins == 0 { return "\(secs) seconds" }
        return "\(mins) minutes \(secs) seconds"
    }

    private var formattedRecordingDuration: String {
        let seconds = Int(workoutManager.recorder.recordingDuration)
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func truncatedSnippet(_ text: String, maxLength: Int = 80) -> String {
        guard text.count > maxLength else { return text }
        let trimmed = text.prefix(maxLength)
        if let lastSpace = trimmed.lastIndex(of: " ") {
            return String(trimmed[trimmed.startIndex..<lastSpace]) + "..."
        }
        return String(trimmed) + "..."
    }

    // MARK: - Animations

    private func startAnimations() {
        if reduceMotion {
            isPulsing = true
            ringRotation = 0
            dotVisible = true
        } else {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                dotVisible = false
            }
        }
    }

    private func stopAnimations() {
        withAnimation(.easeOut(duration: 0.3)) {
            isPulsing = false
            ringRotation = 0
            dotVisible = true
        }
    }
}
