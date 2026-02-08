import AVFoundation
import SwiftUI

struct ActiveWorkoutTab: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @StateObject private var recorder = PhoneAudioRecorderService()
    @State private var showMicPermissionDenied = false
    @State private var showEndConfirmation = false

    private var startGradient: [Color] {
        [Color(red: 0.3, green: 0.85, blue: 0.2), Color(red: 0.1, green: 0.65, blue: 0.25)]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                timerHeader

                momentsFeed

                Spacer()

                bottomControls
            }
            .navigationTitle("Active Workout")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Microphone Access Required", isPresented: $showMicPermissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable microphone access to record moments.")
            }
            .alert("End Workout?", isPresented: $showEndConfirmation) {
                Button("End", role: .destructive) {
                    workoutManager.endWorkout()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will end the current workout and begin AI processing.")
            }
        }
    }

    // MARK: - Timer Header

    private var timerHeader: some View {
        VStack(spacing: 8) {
            Text(formattedElapsed)
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                Label(
                    "\(workoutManager.activeSession?.moments.count ?? 0) moments",
                    systemImage: "waveform"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if workoutManager.isProcessingMoment {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Transcribing...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    // MARK: - Moments Feed

    private var momentsFeed: some View {
        Group {
            if let session = workoutManager.activeSession, !session.moments.isEmpty {
                List {
                    ForEach(session.moments.reversed()) { moment in
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
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No Moments Yet", systemImage: "mic.slash")
                } description: {
                    Text("Tap the microphone button to record a moment.")
                }
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            if recorder.isRecording {
                recordingOverlay
            }

            HStack(spacing: 24) {
                Button {
                    showEndConfirmation = true
                } label: {
                    Text("End")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 44)
                        .background(.red, in: RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    if recorder.isRecording {
                        stopAndAddMoment()
                    } else {
                        requestMicAndRecord()
                    }
                } label: {
                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: startGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .shadow(radius: 4)
                }
                .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Record moment")
            }
            .padding(.bottom, 16)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Recording Overlay

    private var recordingOverlay: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
            Text(formattedRecordingDuration)
                .font(.body.monospacedDigit())
        }
    }

    // MARK: - Helpers

    private var formattedElapsed: String {
        guard let session = workoutManager.activeSession else { return "0:00" }
        let elapsed = Date().timeIntervalSince(session.startedAt)
        let total = Int(elapsed)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }

    private var formattedRecordingDuration: String {
        let minutes = Int(recorder.recordingDuration) / 60
        let seconds = Int(recorder.recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func requestMicAndRecord() {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor in
                    if granted {
                        recorder.startRecording()
                    } else {
                        showMicPermissionDenied = true
                    }
                }
            }
        case .denied:
            showMicPermissionDenied = true
        case .granted:
            recorder.startRecording()
        @unknown default:
            break
        }
    }

    private func stopAndAddMoment() {
        guard let url = recorder.stopRecording() else { return }
        Task {
            await workoutManager.addMoment(audioURL: url, source: .phone)
        }
    }
}
