import Foundation
import os

@Observable
@MainActor
final class ChatService {
    private static let logger = Logger(subsystem: "com.whussey.momentary", category: "ChatService")

    var messages: [ChatMessage] = []
    var isResponding = false
    var lastError: String?

    private let workoutStore: WorkoutStore
    private let insightsService: InsightsService

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o"
    private let maxHistoryMessages = 20

    init(workoutStore: WorkoutStore, insightsService: InsightsService) {
        self.workoutStore = workoutStore
        self.insightsService = insightsService
    }

    // MARK: - Send Message

    func send(_ userText: String) async {
        let userMessage = ChatMessage(
            role: .user,
            blocks: [ChatBlock(type: .text, payload: ChatBlockPayload(text: userText))]
        )
        messages.append(userMessage)

        let loadingMessage = ChatMessage(role: .assistant, isLoading: true)
        messages.append(loadingMessage)
        let loadingID = loadingMessage.id

        isResponding = true
        lastError = nil

        do {
            let systemPrompt = ChatPromptBuilder.buildSystemPrompt(
                workoutStore: workoutStore,
                insightsService: insightsService
            )

            let conversationMessages = buildConversationMessages(systemPrompt: systemPrompt)
            let responseJSON = try await callAPI(messages: conversationMessages)
            let blocks = parseResponse(responseJSON)

            let assistantMessage = ChatMessage(role: .assistant, blocks: blocks)
            if let idx = messages.firstIndex(where: { $0.id == loadingID }) {
                messages[idx] = assistantMessage
            }
        } catch {
            Self.logger.error("Chat error: \(error.localizedDescription)")
            lastError = error.localizedDescription

            let errorBlock = ChatBlock(
                type: .text,
                payload: ChatBlockPayload(text: "Sorry, I couldn't process that request. \(error.localizedDescription)")
            )
            let errorMessage = ChatMessage(role: .assistant, blocks: [errorBlock])
            if let idx = messages.firstIndex(where: { $0.id == loadingID }) {
                messages[idx] = errorMessage
            }
        }

        isResponding = false
    }

    func clearConversation() {
        messages = []
        lastError = nil
    }

    // MARK: - API Call

    private func buildConversationMessages(systemPrompt: String) -> [[String: String]] {
        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        let recentMessages = messages.suffix(maxHistoryMessages)
        for msg in recentMessages {
            if msg.isLoading { continue }
            let role = msg.role == .user ? "user" : "assistant"
            let content: String
            if msg.role == .user {
                content = msg.blocks.first?.payload.text ?? ""
            } else {
                // Re-serialize assistant blocks as JSON for context
                let blockDicts = msg.blocks.map { block -> [String: Any] in
                    var dict: [String: Any] = ["type": block.type.rawValue]
                    if let text = block.payload.text { dict["text"] = text }
                    return dict
                }
                if let jsonData = try? JSONSerialization.data(withJSONObject: ["blocks": blockDicts]) {
                    content = String(data: jsonData, encoding: .utf8) ?? ""
                } else {
                    content = ""
                }
            }
            apiMessages.append(["role": role, "content": content])
        }

        return apiMessages
    }

    private func callAPI(messages: [[String: String]]) async throws -> String {
        let apiKey = APIKeyProvider.resolvedKey
        guard !apiKey.isEmpty else {
            throw AIProcessingError.noAPIKey
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "response_format": ["type": "json_object"],
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

    // MARK: - Parse Response

    private func parseResponse(_ json: String) -> [ChatBlock] {
        var cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard let data = cleaned.data(using: .utf8) else {
            return [ChatBlock(type: .text, payload: ChatBlockPayload(text: cleaned))]
        }

        do {
            let response = try JSONDecoder().decode(ChatAPIResponse.self, from: data)
            let blocks = response.blocks?.compactMap { $0.toChatBlock() } ?? []
            return blocks.isEmpty
                ? [ChatBlock(type: .text, payload: ChatBlockPayload(text: cleaned))]
                : blocks
        } catch {
            Self.logger.warning("Failed to parse chat response: \(error.localizedDescription)")
            return [ChatBlock(type: .text, payload: ChatBlockPayload(text: cleaned))]
        }
    }
}
