import SwiftUI

struct WorkoutSummaryView: View {
    let duration: TimeInterval
    let momentCount: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Workout Complete")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(formattedDuration)
                        .font(.system(.title3, design: .monospaced))
                    Text("Duration")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(momentCount)")
                        .font(.title3)
                    Text("Moments")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
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
