import AVFoundation
import SwiftUI

struct HomeView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @StateObject private var recorder = PhoneAudioRecorderService()
    @State private var editMode: EditMode = .inactive
    @State private var showDeleteConfirmation = false
    @State private var selectedWorkouts = Set<UUID>()
    @State private var showMicPermissionDenied = false

    private var startGradient: [Color] {
        [Color(red: 0.3, green: 0.85, blue: 0.2), Color(red: 0.1, green: 0.65, blue: 0.25)]
    }

    var body: some View {
        NavigationStack {
            Group {
                mainContent
            }
            .navigationTitle("Momentary")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !workoutManager.workoutStore.index.isEmpty {
                        Button {
                            withAnimation {
                                editMode = editMode.isEditing ? .inactive : .active
                            }
                        } label: {
                            Text(editMode.isEditing ? "Done" : "Select")
                        }
                    }
                }
            }
            .toolbar {
                if editMode.isEditing && !selectedWorkouts.isEmpty {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Spacer()
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .onChange(of: editMode) {
                if !editMode.isEditing {
                    selectedWorkouts.removeAll()
                }
            }
            .alert("Delete Workouts", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteSelected()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(selectedWorkouts.count) workout\(selectedWorkouts.count == 1 ? "" : "s")?")
            }
            .alert("Microphone Access Required", isPresented: $showMicPermissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable microphone access in Settings to record voice moments.")
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        List(selection: $selectedWorkouts) {
            if workoutManager.activeSession != nil {
                activeWorkoutBanner
            } else {
                startWorkoutCard
            }

            if workoutManager.workoutStore.index.isEmpty {
                ContentUnavailableView {
                    Label("No Workouts", systemImage: "figure.strengthtraining.traditional")
                } description: {
                    Text("Start a workout to begin logging moments.")
                }
            } else {
                Section("Workout History") {
                    ForEach(workoutManager.workoutStore.index) { entry in
                        NavigationLink(value: entry.id) {
                            workoutRow(entry)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { workoutManager.workoutStore.index[$0].id }
                        for id in ids {
                            workoutManager.workoutStore.deleteSession(id: id)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: UUID.self) { workoutID in
            WorkoutDetailView(workoutID: workoutID)
        }
    }

    // MARK: - Start Workout Card

    private var startWorkoutCard: some View {
        Section {
            Button {
                workoutManager.startWorkout()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)

                    Text("Start Workout")
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    Text("Use Apple Watch for best experience")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    LinearGradient(
                        colors: startGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    // MARK: - Active Workout Banner

    private var activeWorkoutBanner: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Workout Active")
                            .font(.headline)
                    }
                    Text("\(workoutManager.activeSession?.moments.count ?? 0) moments")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("View")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Workout Row

    private func workoutRow(_ entry: WorkoutSessionIndex) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.startedAt, style: .date)
                .font(.headline)
            HStack(spacing: 12) {
                if let duration = entry.duration {
                    Label(formatDuration(duration), systemImage: "clock")
                }
                Label("\(entry.momentCount) moment\(entry.momentCount == 1 ? "" : "s")", systemImage: "waveform")
                if entry.hasStructuredLog {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !entry.exerciseNames.isEmpty {
                Text(entry.exerciseNames.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func deleteSelected() {
        for id in selectedWorkouts {
            workoutManager.workoutStore.deleteSession(id: id)
        }
        selectedWorkouts.removeAll()
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
