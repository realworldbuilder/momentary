import Foundation
import os

@MainActor
final class TranscriptionService: ObservableObject {
    private static let logger = Logger(subsystem: "com.whussey.momentary", category: "TranscriptionService")

    @Published var isProcessing = false

    private let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    func transcribe(audioURL: URL) async -> Result<String, Error> {
        isProcessing = true
        defer { isProcessing = false }

        let apiKey = APIKeyProvider.apiKey
        guard !apiKey.isEmpty else {
            return .failure(TranscriptionError.noAPIKey)
        }

        do {
            let audioData = try Data(contentsOf: audioURL)
            let boundary = UUID().uuidString

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 60

            var body = Data()
            // model field
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append("whisper-1\r\n".data(using: .utf8)!)
            // file field
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(TranscriptionError.invalidResponse)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                Self.logger.error("Whisper API error \(httpResponse.statusCode): \(errorBody)")
                return .failure(TranscriptionError.apiError(statusCode: httpResponse.statusCode, message: errorBody))
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String else {
                return .failure(TranscriptionError.invalidResponse)
            }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return .failure(TranscriptionError.emptyResult)
            }

            return .success(trimmed)
        } catch let error as TranscriptionError {
            return .failure(error)
        } catch {
            Self.logger.error("Transcription failed: \(error)")
            return .failure(error)
        }
    }
}

enum TranscriptionError: LocalizedError {
    case noAPIKey
    case emptyResult
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: "No API key available"
        case .emptyResult: "No speech detected"
        case .invalidResponse: "Invalid response from Whisper API"
        case .apiError(let code, let message): "Whisper API error (\(code)): \(message)"
        }
    }
}
