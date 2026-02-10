import SwiftUI

struct WorkoutSummaryView: View {
    let duration: TimeInterval
    let momentCount: Int
    let averageHeartRate: Double
    let totalCalories: Double
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)

                Text("Workout Complete")
                    .font(.headline)

                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        Text(formattedDuration)
                            .font(.system(.body, design: .monospaced))
                        Text("Duration")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 2) {
                        Text("\(momentCount)")
                            .font(.body)
                        Text("Moments")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if averageHeartRate > 0 || totalCalories > 0 {
                    HStack(spacing: 20) {
                        if averageHeartRate > 0 {
                            VStack(spacing: 2) {
                                HStack(spacing: 2) {
                                    Image(systemName: "heart.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                    Text("\(Int(averageHeartRate))")
                                        .font(.body)
                                }
                                Text("Avg BPM")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if totalCalories > 0 {
                            VStack(spacing: 2) {
                                HStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                    Text("\(Int(totalCalories))")
                                        .font(.body)
                                }
                                Text("Calories")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.top, 4)
            }
            .padding(.horizontal)
        }
    }

    private var formattedDuration: String {
        let total = Int(duration)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }
}
