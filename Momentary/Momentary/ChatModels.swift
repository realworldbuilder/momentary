import Foundation

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    var role: ChatRole
    var blocks: [ChatBlock]
    var timestamp: Date
    var isLoading: Bool
    var isStreaming: Bool
    var suggestedFollowups: [String]?

    init(
        id: UUID = UUID(),
        role: ChatRole,
        blocks: [ChatBlock] = [],
        timestamp: Date = Date(),
        isLoading: Bool = false,
        isStreaming: Bool = false,
        suggestedFollowups: [String]? = nil
    ) {
        self.id = id
        self.role = role
        self.blocks = blocks
        self.timestamp = timestamp
        self.isLoading = isLoading
        self.isStreaming = isStreaming
        self.suggestedFollowups = suggestedFollowups
    }

    private enum CodingKeys: String, CodingKey {
        case id, role, blocks, timestamp, suggestedFollowups
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(ChatRole.self, forKey: .role)
        blocks = try container.decode([ChatBlock].self, forKey: .blocks)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        suggestedFollowups = try container.decodeIfPresent([String].self, forKey: .suggestedFollowups)
        isLoading = false
        isStreaming = false
    }
}

enum ChatRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - Chat Block

struct ChatBlock: Identifiable, Codable {
    let id: UUID
    var type: ChatBlockType
    var payload: ChatBlockPayload

    init(id: UUID = UUID(), type: ChatBlockType, payload: ChatBlockPayload) {
        self.id = id
        self.type = type
        self.payload = payload
    }
}

enum ChatBlockType: String, Codable {
    case text
    case workoutSummary
    case exerciseTable
    case metricGrid
    case chart
    case insight
    case actionButtons
    case workoutList
    case error
}

// MARK: - Chat Block Payload (all-optional flat struct)

struct ChatBlockPayload: Codable {
    // text
    var text: String?

    // workoutSummary
    var workoutId: String?
    var date: String?
    var duration: String?
    var exerciseCount: Int?
    var totalSets: Int?
    var totalVolume: Double?
    var exerciseNames: [String]?

    // exerciseTable
    var exerciseName: String?
    var sets: [ChatSetRow]?

    // metricGrid
    var metrics: [ChatMetric]?

    // chart
    var chartType: String?
    var dataPoints: [ChatChartPoint]?
    var xAxisLabel: String?
    var yAxisLabel: String?
    var chartStyle: String?

    // insight
    var insightType: String?
    var title: String?
    var body: String?

    // actionButtons
    var actions: [ChatAction]?

    // workoutList
    var workouts: [ChatWorkoutListItem]?

    // error
    var errorType: String?
    var errorMessage: String?
    var retryAfterSeconds: Double?
}

// MARK: - Supporting Types

struct ChatSetRow: Codable {
    var setNumber: Int?
    var reps: Int?
    var weight: Double?
    var unit: String?
}

struct ChatMetric: Codable, Identifiable {
    var id: String { title ?? icon ?? UUID().uuidString }
    var icon: String?
    var value: String?
    var title: String?
    var subtitle: String?
}

struct ChatChartPoint: Codable {
    var label: String?
    var value: Double?
    var secondaryValue: Double?
    var date: String?
    var isPR: Bool?

    func toChartDataPoint() -> ChartDataPoint {
        let parsedDate: Date? = {
            guard let dateStr = date else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            if let d = formatter.date(from: dateStr) { return d }
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            return df.date(from: dateStr)
        }()

        return ChartDataPoint(
            label: label ?? "",
            value: value ?? 0,
            secondaryValue: secondaryValue,
            date: parsedDate,
            isPR: isPR
        )
    }
}

struct ChatAction: Codable, Identifiable {
    var id: String { label }
    var label: String
    var actionType: ChatActionType
    var workoutId: String?
}

enum ChatActionType: String, Codable {
    case startWorkout
    case viewWorkout
    case analyzeWorkout
    case exportData
}

struct ChatWorkoutListItem: Codable, Identifiable {
    var id: String { workoutId ?? UUID().uuidString }
    var workoutId: String?
    var date: String?
    var summary: String?
    var volume: Double?
}

// MARK: - API Response Wrapper

struct ChatAPIResponse: Codable {
    var blocks: [ChatAPIBlock]?
    var suggestedFollowups: [String]?
}

struct ChatAPIBlock: Codable {
    var type: String?
    var payload: ChatBlockPayload?

    func toChatBlock() -> ChatBlock? {
        guard let typeStr = type, let blockType = ChatBlockType(rawValue: typeStr) else { return nil }
        return ChatBlock(type: blockType, payload: payload ?? ChatBlockPayload())
    }
}

// MARK: - Chat History (Persistence)

struct ChatHistory: Codable {
    var version: Int = 1
    var messages: [ChatMessage]
}

// MARK: - Chat Archive Entry

struct ChatArchiveEntry: Identifiable {
    let id: String          // filename
    let timestamp: Date
    let preview: String     // first user message, truncated to 60 chars
    let messageCount: Int
    let fileURL: URL
}

// MARK: - Token Usage

struct TokenUsage: Codable {
    var promptTokens: Int = 0
    var completionTokens: Int = 0
    var totalTokens: Int = 0

    var formattedTotal: String {
        if totalTokens >= 1000 {
            return String(format: "%.1fK tokens", Double(totalTokens) / 1000.0)
        }
        return "\(totalTokens) tokens"
    }

    // GPT-4o pricing: $2.50/1M input, $10.00/1M output
    var formattedCost: String {
        let inputCost = Double(promptTokens) / 1_000_000.0 * 2.50
        let outputCost = Double(completionTokens) / 1_000_000.0 * 10.00
        let total = inputCost + outputCost
        if total < 0.01 {
            return String(format: "$%.4f", total)
        }
        return String(format: "$%.2f", total)
    }

    mutating func accumulate(_ other: TokenUsage) {
        promptTokens += other.promptTokens
        completionTokens += other.completionTokens
        totalTokens += other.totalTokens
    }
}
