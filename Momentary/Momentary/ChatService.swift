import Foundation
import os

@Observable
@MainActor
final class ChatService {
    private static let logger = Logger(subsystem: "com.whussey.momentary", category: "ChatService")

    var messages: [ChatMessage] = []
    var isResponding = false
    var lastError: String?
    var sessionTokenUsage = TokenUsage()

    private let workoutStore: WorkoutStore
    private let insightsService: InsightsService

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o"
    private let maxHistoryMessages = 20

    init(workoutStore: WorkoutStore, insightsService: InsightsService) {
        self.workoutStore = workoutStore
        self.insightsService = insightsService
        loadChatHistory()
    }

    // MARK: - Send Message

    func send(_ userText: String) async {
        let userMessage = ChatMessage(
            role: .user,
            blocks: [ChatBlock(type: .text, payload: ChatBlockPayload(text: userText))]
        )
        messages.append(userMessage)

        let streamingMessage = ChatMessage(role: .assistant, isStreaming: true)
        messages.append(streamingMessage)
        let streamingID = streamingMessage.id

        isResponding = true
        lastError = nil

        do {
            let systemPrompt = ChatPromptBuilder.buildSystemPrompt(
                workoutStore: workoutStore,
                insightsService: insightsService
            )

            let conversationMessages = buildConversationMessages(systemPrompt: systemPrompt)
            let (fullContent, usage) = try await callStreamingAPI(
                messages: conversationMessages,
                streamingMessageID: streamingID
            )

            if let usage {
                sessionTokenUsage.accumulate(usage)
            }

            let (blocks, followups) = parseResponse(fullContent)
            let assistantMessage = ChatMessage(
                role: .assistant,
                blocks: blocks,
                suggestedFollowups: followups
            )
            if let idx = messages.firstIndex(where: { $0.id == streamingID }) {
                messages[idx] = assistantMessage
            }

            HapticService.success()
        } catch is CancellationError {
            if let idx = messages.firstIndex(where: { $0.id == streamingID }) {
                messages.remove(at: idx)
            }
        } catch {
            Self.logger.error("Chat error: \(error.localizedDescription)")
            lastError = error.localizedDescription

            let (errorType, errorMessage, retryAfter) = classifyError(error)
            let errorBlock = ChatBlock(
                type: .error,
                payload: ChatBlockPayload(
                    errorType: errorType,
                    errorMessage: errorMessage,
                    retryAfterSeconds: retryAfter
                )
            )
            let errorMsg = ChatMessage(role: .assistant, blocks: [errorBlock])
            if let idx = messages.firstIndex(where: { $0.id == streamingID }) {
                messages[idx] = errorMsg
            }

            HapticService.error()
        }

        isResponding = false
        saveChatHistory()
    }

    func retryLastMessage() {
        // Find the last user message before the error
        guard let lastErrorIdx = messages.lastIndex(where: {
            $0.role == .assistant && $0.blocks.contains(where: { $0.type == .error })
        }) else { return }

        let userIdx = lastErrorIdx - 1
        guard userIdx >= 0, messages[userIdx].role == .user,
              let userText = messages[userIdx].blocks.first?.payload.text else { return }

        // Remove error and user messages
        messages.remove(at: lastErrorIdx)
        messages.remove(at: userIdx)

        Task { await send(userText) }
    }

    func clearConversation() {
        messages = []
        lastError = nil
        sessionTokenUsage = TokenUsage()
        saveChatHistory()
    }

    func newChat() {
        guard !messages.isEmpty else { return }
        archiveCurrentChat()
        messages = []
        lastError = nil
        sessionTokenUsage = TokenUsage()
        saveChatHistory()
    }

    // MARK: - Streaming API Call

    private func callStreamingAPI(
        messages: [[String: String]],
        streamingMessageID: UUID
    ) async throws -> (fullContent: String, usage: TokenUsage?) {
        let apiKey = APIKeyProvider.resolvedKey
        guard !apiKey.isEmpty else {
            throw AIProcessingError.noAPIKey
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "response_format": ["type": "json_object"],
            "temperature": 0.7,
            "max_tokens": 4096,
            "stream": true,
            "stream_options": ["include_usage": true]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProcessingError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
            throw AIProcessingError.rateLimited(retryAfter: Double(retryAfter ?? "") ?? 5.0)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Read the full error body
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw AIProcessingError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        var fullContent = ""
        var tokenUsage: TokenUsage?
        var lastUIUpdate = Date()
        let throttleInterval: TimeInterval = 0.05 // 50ms

        for try await line in bytes.lines {
            try Task.checkCancellation()

            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))

            if jsonStr.trimmingCharacters(in: .whitespaces) == "[DONE]" { break }

            guard let chunkData = jsonStr.data(using: .utf8),
                  let chunk = try? JSONSerialization.jsonObject(with: chunkData) as? [String: Any] else {
                continue
            }

            // Extract delta content
            if let choices = chunk["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let delta = firstChoice["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                fullContent += content

                // Throttle UI updates
                let now = Date()
                if now.timeIntervalSince(lastUIUpdate) >= throttleInterval {
                    updateStreamingMessage(id: streamingMessageID, text: fullContent)
                    lastUIUpdate = now
                }
            }

            // Extract usage from final chunk
            if let usage = chunk["usage"] as? [String: Any] {
                tokenUsage = TokenUsage(
                    promptTokens: usage["prompt_tokens"] as? Int ?? 0,
                    completionTokens: usage["completion_tokens"] as? Int ?? 0,
                    totalTokens: usage["total_tokens"] as? Int ?? 0
                )
            }
        }

        // Final UI update with complete content
        updateStreamingMessage(id: streamingMessageID, text: fullContent)

        return (fullContent, tokenUsage)
    }

    private func updateStreamingMessage(id: UUID, text: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].blocks = [ChatBlock(type: .text, payload: ChatBlockPayload(text: text))]
        messages[idx].isStreaming = true
    }

    // MARK: - Build Conversation Messages

    private func buildConversationMessages(systemPrompt: String) -> [[String: String]] {
        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        let recentMessages = messages.suffix(maxHistoryMessages)
        for msg in recentMessages {
            if msg.isLoading || msg.isStreaming { continue }
            if msg.role == .system { continue }

            // Skip error blocks
            if msg.blocks.contains(where: { $0.type == .error }) { continue }

            let role = msg.role == .user ? "user" : "assistant"
            let content: String
            if msg.role == .user {
                content = msg.blocks.first?.payload.text ?? ""
            } else {
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

    // MARK: - Parse Response

    private func parseResponse(_ json: String) -> (blocks: [ChatBlock], followups: [String]?) {
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
            return ([ChatBlock(type: .text, payload: ChatBlockPayload(text: cleaned))], nil)
        }

        do {
            let response = try JSONDecoder().decode(ChatAPIResponse.self, from: data)
            let blocks = response.blocks?.compactMap { $0.toChatBlock() } ?? []
            let followups = response.suggestedFollowups
            if blocks.isEmpty {
                return ([ChatBlock(type: .text, payload: ChatBlockPayload(text: cleaned))], followups)
            }
            return (blocks, followups)
        } catch {
            Self.logger.warning("Failed to parse chat response: \(error.localizedDescription)")
            return ([ChatBlock(type: .text, payload: ChatBlockPayload(text: cleaned))], nil)
        }
    }

    // MARK: - Error Classification

    private func classifyError(_ error: Error) -> (type: String, message: String, retryAfter: Double?) {
        if let aiError = error as? AIProcessingError {
            switch aiError {
            case .noAPIKey:
                return ("noAPIKey", "No API key configured. Add your OpenAI key in Settings.", nil)
            case .rateLimited(let retryAfter):
                return ("rateLimited", "Rate limited. Please wait before trying again.", retryAfter)
            case .invalidResponse:
                return ("serverError", "Received an invalid response from the server.", nil)
            case .apiError(let code, _):
                if code == 401 {
                    return ("noAPIKey", "Invalid API key. Check your key in Settings.", nil)
                }
                return ("serverError", "Server error (\(code)). Please try again.", nil)
            case .parsingFailed:
                return ("serverError", "Failed to understand the response. Please try again.", nil)
            case .networkUnavailable:
                return ("networkError", "No internet connection. Check your network and try again.", nil)
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return ("networkError", "No internet connection. Check your network and try again.", nil)
            case .timedOut:
                return ("timeout", "Request timed out. Please try again.", nil)
            default:
                return ("networkError", "Network error. Please try again.", nil)
            }
        }

        return ("unknown", "Something went wrong. Please try again.", nil)
    }

    // MARK: - Persistence

    private var chatHistoryURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chat_history.json")
    }

    private var chatArchivesDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chat_archives", isDirectory: true)
    }

    private func loadChatHistory() {
        guard FileManager.default.fileExists(atPath: chatHistoryURL.path) else { return }
        do {
            let data = try Data(contentsOf: chatHistoryURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let history = try decoder.decode(ChatHistory.self, from: data)
            messages = history.messages
        } catch {
            Self.logger.warning("Failed to load chat history: \(error.localizedDescription)")
        }
    }

    private func saveChatHistory() {
        let persistableMessages = messages.filter { !$0.isLoading && !$0.isStreaming }
        let history = ChatHistory(messages: persistableMessages)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(history)
            try data.write(to: chatHistoryURL, options: .atomic)
        } catch {
            Self.logger.error("Failed to save chat history: \(error.localizedDescription)")
        }
    }

    // MARK: - Chat History Browser

    func listArchivedChats() -> [ChatArchiveEntry] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: chatArchivesDirectory.path) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let dateFormatter = ISO8601DateFormatter()

        guard let files = try? fm.contentsOfDirectory(at: chatArchivesDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        return files.compactMap { url -> ChatArchiveEntry? in
            guard url.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: url),
                  let history = try? decoder.decode(ChatHistory.self, from: data) else {
                return nil
            }

            let filename = url.deletingPathExtension().lastPathComponent
            // Filename format: chat_YYYY-MM-DDTHH-MM-SSZ → need YYYY-MM-DDTHH:MM:SSZ
            let rawTimestamp = filename.replacingOccurrences(of: "chat_", with: "")
            let timestamp: Date
            // The format is like 2025-01-15T10-30-00Z — dashes in time portion
            // We need to convert back to 2025-01-15T10:30:00Z
            if rawTimestamp.count >= 20 {
                let idx10 = rawTimestamp.index(rawTimestamp.startIndex, offsetBy: 13)
                let idx13 = rawTimestamp.index(rawTimestamp.startIndex, offsetBy: 16)
                var fixed = rawTimestamp
                fixed.replaceSubrange(idx10...idx10, with: ":")
                fixed.replaceSubrange(idx13...idx13, with: ":")
                timestamp = dateFormatter.date(from: fixed) ?? Date()
            } else {
                timestamp = history.messages.first?.timestamp ?? Date()
            }

            let firstUserMessage = history.messages.first(where: { $0.role == .user })
            let previewText = firstUserMessage?.blocks.first?.payload.text ?? "No preview"
            let preview = previewText.count > 60 ? String(previewText.prefix(60)) + "…" : previewText

            return ChatArchiveEntry(
                id: filename,
                timestamp: timestamp,
                preview: preview,
                messageCount: history.messages.count,
                fileURL: url
            )
        }
        .sorted { $0.timestamp > $1.timestamp }
    }

    func loadArchivedChat(_ entry: ChatArchiveEntry) {
        // Archive current chat if non-empty
        if !messages.isEmpty {
            archiveCurrentChat()
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = try? Data(contentsOf: entry.fileURL),
              let history = try? decoder.decode(ChatHistory.self, from: data) else {
            Self.logger.warning("Failed to load archived chat: \(entry.id)")
            return
        }

        messages = history.messages
        sessionTokenUsage = TokenUsage()
        lastError = nil
        saveChatHistory()
    }

    private func archiveCurrentChat() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: chatArchivesDirectory.path) {
            try? fm.createDirectory(at: chatArchivesDirectory, withIntermediateDirectories: true)
        }
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let archiveURL = chatArchivesDirectory.appendingPathComponent("chat_\(timestamp).json")
        let persistableMessages = messages.filter { !$0.isLoading && !$0.isStreaming }
        let history = ChatHistory(messages: persistableMessages)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)
            try data.write(to: archiveURL, options: .atomic)
        } catch {
            Self.logger.warning("Failed to archive chat: \(error.localizedDescription)")
        }
    }
}
