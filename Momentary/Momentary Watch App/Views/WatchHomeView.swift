import SwiftUI

struct WatchHomeView: View {
    @Environment(WatchWorkoutManager.self) private var workoutManager

    private var startGradient: [Color] {
        [Color(red: 0.3, green: 0.85, blue: 0.2), Color(red: 0.1, green: 0.65, blue: 0.25)]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                startButton
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Momentary")
    }

    private var startButton: some View {
        Button {
            workoutManager.startWorkout()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)

                Text("Start Workout")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
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
        .accessibilityLabel("Start workout")
    }
}
