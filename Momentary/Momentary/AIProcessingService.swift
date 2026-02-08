import Foundation
import os

protocol AIBackend: Sendable {
    func complete(systemPrompt: String, userPrompt: String) async throws -> String
}

final class OpenAIBackend: AIBackend, Sendable {
    private static let logger = Logger(subsystem: "com.whussey.momentary", category: "OpenAIBackend")

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o"

    func complete(systemPrompt: String, userPrompt: String) async throws -> String {
        let apiKey = APIKeyProvider.apiKey
        guard !apiKey.isEmpty else {
            throw AIProcessingError.noAPIKey
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": [
                "type": "json_object"
            ],
            "temperature": 0.7,
            "max_tokens": 4096
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProcessingError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
            throw AIProcessingError.rateLimited(retryAfter: Double(retryAfter ?? "") ?? 5.0)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIProcessingError.apiError(statusCode: httpResponse.statusCode, message: body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIProcessingError.invalidResponse
        }

        return content
    }
}

enum AIProcessingError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case rateLimited(retryAfter: Double)
    case apiError(statusCode: Int, message: String)
    case parsingFailed(String)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No OpenAI API key configured."
        case .invalidResponse: return "Invalid response from OpenAI"
        case .rateLimited(let retryAfter): return "Rate limited. Retrying in \(Int(retryAfter))s."
        case .apiError(let code, let message): return "API error (\(code)): \(message)"
        case .parsingFailed(let detail): return "Failed to parse AI response: \(detail)"
        case .networkUnavailable: return "No network connection. Processing will resume when online."
        }
    }
}
