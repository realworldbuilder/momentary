import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("AI Features Active")
                }

                Text("Transcription and workout analysis powered by OpenAI")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("OpenAI")
            }

            Section("About") {
                LabeledContent("Version", value: "1.0")
                LabeledContent("AI Model", value: "GPT-4o")
                LabeledContent("Transcription", value: "Whisper")
            }
        }
        .navigationTitle("Settings")
    }
}
