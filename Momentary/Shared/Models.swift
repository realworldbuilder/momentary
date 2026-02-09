import Foundation

// MARK: - Workout Session

struct WorkoutSession: Codable, Identifiable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var healthWorkoutUUID: UUID?
    var moments: [Moment]
    var structuredLog: StructuredLog?
    var contentPack: ContentPack?
    var stories: [InsightStory]

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        healthWorkoutUUID: UUID? = nil,
        moments: [Moment] = [],
        structuredLog: StructuredLog? = nil,
        contentPack: ContentPack? = nil,
        stories: [InsightStory] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.healthWorkoutUUID = healthWorkoutUUID
        self.moments = moments
        self.structuredLog = structuredLog
        self.contentPack = contentPack
        self.stories = stories
    }

    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
}

// MARK: - Moment

struct Moment: Codable, Identifiable {
    let id: UUID
    var timestamp: Date
    var transcript: String
    var source: MomentSource
    var tags: [String]
    var confidence: Double

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        transcript: String = "",
        source: MomentSource = .watch,
        tags: [String] = [],
        confidence: Double = 1.0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.transcript = transcript
        self.source = source
        self.tags = tags
        self.confidence = confidence
    }
}

enum MomentSource: String, Codable {
    case watch
    case phone
}

// MARK: - Structured Log

struct StructuredLog: Codable {
    var exercises: [ExerciseGroup]
    var summary: String
    var highlights: [String]
    var ambiguities: [Ambiguity]

    private enum CodingKeys: String, CodingKey {
        case exercises, summary, highlights, ambiguities
    }

    init(
        exercises: [ExerciseGroup] = [],
        summary: String = "",
        highlights: [String] = [],
        ambiguities: [Ambiguity] = []
    ) {
        self.exercises = exercises
        self.summary = summary
        self.highlights = highlights
        self.ambiguities = ambiguities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.exercises = (try? container.decode([ExerciseGroup].self, forKey: .exercises)) ?? []
        self.summary = (try? container.decode(String.self, forKey: .summary)) ?? ""
        self.highlights = (try? container.decode([String].self, forKey: .highlights)) ?? []
        self.ambiguities = (try? container.decode([Ambiguity].self, forKey: .ambiguities)) ?? []
    }
}

struct ExerciseGroup: Codable, Identifiable {
    let id: UUID
    var exerciseName: String
    var sets: [ExerciseSet]
    var notes: String?

    private enum CodingKeys: String, CodingKey {
        case id, exerciseName, sets, notes
    }

    init(
        id: UUID = UUID(),
        exerciseName: String,
        sets: [ExerciseSet] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.sets = sets
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.exerciseName = (try? container.decode(String.self, forKey: .exerciseName)) ?? "Unknown Exercise"
        self.sets = (try? container.decode([ExerciseSet].self, forKey: .sets)) ?? []
        self.notes = try? container.decodeIfPresent(String.self, forKey: .notes)
    }
}

struct ExerciseSet: Codable, Identifiable {
    let id: UUID
    var setNumber: Int
    var reps: Int?
    var weight: Double?
    var weightUnit: WeightUnit
    var duration: TimeInterval?
    var notes: String?

    private enum CodingKeys: String, CodingKey {
        case id, setNumber, reps, weight, weightUnit, duration, notes
    }

    init(
        id: UUID = UUID(),
        setNumber: Int,
        reps: Int? = nil,
        weight: Double? = nil,
        weightUnit: WeightUnit = .lbs,
        duration: TimeInterval? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.weightUnit = weightUnit
        self.duration = duration
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()

        // setNumber: try Int, then String→Int, then fallback to 1
        if let intVal = try? container.decode(Int.self, forKey: .setNumber) {
            self.setNumber = intVal
        } else if let strVal = try? container.decode(String.self, forKey: .setNumber), let parsed = Int(strVal) {
            self.setNumber = parsed
        } else {
            self.setNumber = 1
        }

        // reps: try Int, then String→Int
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .reps) {
            self.reps = intVal
        } else if let strVal = try? container.decode(String.self, forKey: .reps), let parsed = Int(strVal) {
            self.reps = parsed
        } else {
            self.reps = nil
        }

        // weight: try Double, then String→Double
        if let dblVal = try? container.decodeIfPresent(Double.self, forKey: .weight) {
            self.weight = dblVal
        } else if let strVal = try? container.decode(String.self, forKey: .weight), let parsed = Double(strVal) {
            self.weight = parsed
        } else {
            self.weight = nil
        }

        self.weightUnit = (try? container.decode(WeightUnit.self, forKey: .weightUnit)) ?? .lbs
        self.duration = try? container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        self.notes = try? container.decodeIfPresent(String.self, forKey: .notes)
    }
}

enum WeightUnit: String, Codable {
    case lbs
    case kg

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self))?.lowercased().trimmingCharacters(in: .whitespaces) ?? ""
        switch raw {
        case "lbs", "lb", "pounds", "pound":
            self = .lbs
        case "kg", "kgs", "kilograms", "kilogram":
            self = .kg
        default:
            self = .lbs
        }
    }
}

struct Ambiguity: Codable, Identifiable {
    let id: UUID
    var field: String
    var rawTranscript: String
    var bestGuess: String
    var alternatives: [String]

    private enum CodingKeys: String, CodingKey {
        case id, field, rawTranscript, bestGuess, alternatives
    }

    init(
        id: UUID = UUID(),
        field: String,
        rawTranscript: String,
        bestGuess: String,
        alternatives: [String] = []
    ) {
        self.id = id
        self.field = field
        self.rawTranscript = rawTranscript
        self.bestGuess = bestGuess
        self.alternatives = alternatives
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.field = (try? container.decode(String.self, forKey: .field)) ?? ""
        self.rawTranscript = (try? container.decode(String.self, forKey: .rawTranscript)) ?? ""
        self.bestGuess = (try? container.decode(String.self, forKey: .bestGuess)) ?? ""
        self.alternatives = (try? container.decode([String].self, forKey: .alternatives)) ?? []
    }
}

// MARK: - Content Pack

struct ContentPack: Codable {
    var igCaptions: [String]
    var tweetThread: [String]
    var reelScript: String
    var storyCards: [StoryCard]
    var hooks: [String]
    var takeaways: [String]

    private enum CodingKeys: String, CodingKey {
        case igCaptions, tweetThread, reelScript, storyCards, hooks, takeaways
    }

    init(
        igCaptions: [String] = [],
        tweetThread: [String] = [],
        reelScript: String = "",
        storyCards: [StoryCard] = [],
        hooks: [String] = [],
        takeaways: [String] = []
    ) {
        self.igCaptions = igCaptions
        self.tweetThread = tweetThread
        self.reelScript = reelScript
        self.storyCards = storyCards
        self.hooks = hooks
        self.takeaways = takeaways
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.igCaptions = (try? container.decode([String].self, forKey: .igCaptions)) ?? []
        self.tweetThread = (try? container.decode([String].self, forKey: .tweetThread)) ?? []
        self.reelScript = (try? container.decode(String.self, forKey: .reelScript)) ?? ""
        self.storyCards = (try? container.decode([StoryCard].self, forKey: .storyCards)) ?? []
        self.hooks = (try? container.decode([String].self, forKey: .hooks)) ?? []
        self.takeaways = (try? container.decode([String].self, forKey: .takeaways)) ?? []
    }
}

struct StoryCard: Codable, Identifiable {
    let id: UUID
    var title: String
    var body: String

    private enum CodingKeys: String, CodingKey {
        case id, title, body
    }

    init(id: UUID = UUID(), title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.title = (try? container.decode(String.self, forKey: .title)) ?? ""
        self.body = (try? container.decode(String.self, forKey: .body)) ?? ""
    }
}

// MARK: - Insight Story

struct InsightStory: Codable, Identifiable {
    let id: UUID
    var title: String
    var body: String
    var tags: [String]
    var type: InsightType

    private enum CodingKeys: String, CodingKey {
        case id, title, body, tags, type
    }

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        tags: [String] = [],
        type: InsightType
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.title = (try? container.decode(String.self, forKey: .title)) ?? ""
        self.body = (try? container.decode(String.self, forKey: .body)) ?? ""
        self.tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        self.type = (try? container.decode(InsightType.self, forKey: .type)) ?? .progressNote
    }
}

enum InsightType: String, Codable {
    case progressNote
    case formReminder
    case motivational
    case recovery

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? ""
        let normalized = raw.lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        switch normalized {
        case "progressnote", "progress":
            self = .progressNote
        case "formreminder", "form":
            self = .formReminder
        case "motivational", "motivation":
            self = .motivational
        case "recovery":
            self = .recovery
        default:
            self = .progressNote
        }
    }
}

// MARK: - Connectivity

enum WorkoutCommand: String, Codable {
    case start
    case stop
    case momentRecorded
    case momentTranscribed
}

struct WorkoutMessage: Codable {
    var command: WorkoutCommand
    var workoutID: UUID
    var momentID: UUID?
    var transcript: String?
    var confidence: Double?
    var timestamp: Date
    var error: String?

    init(
        command: WorkoutCommand,
        workoutID: UUID,
        momentID: UUID? = nil,
        transcript: String? = nil,
        confidence: Double? = nil,
        timestamp: Date = Date(),
        error: String? = nil
    ) {
        self.command = command
        self.workoutID = workoutID
        self.momentID = momentID
        self.transcript = transcript
        self.confidence = confidence
        self.timestamp = timestamp
        self.error = error
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "command": command.rawValue,
            "workoutID": workoutID.uuidString,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        if let momentID { dict["momentID"] = momentID.uuidString }
        if let transcript { dict["transcript"] = transcript }
        if let confidence { dict["confidence"] = confidence }
        if let error { dict["error"] = error }
        return dict
    }

    static func from(dictionary dict: [String: Any]) -> WorkoutMessage? {
        guard
            let commandRaw = dict["command"] as? String,
            let command = WorkoutCommand(rawValue: commandRaw),
            let workoutIDString = dict["workoutID"] as? String,
            let workoutID = UUID(uuidString: workoutIDString),
            let timestampInterval = dict["timestamp"] as? TimeInterval
        else { return nil }

        return WorkoutMessage(
            command: command,
            workoutID: workoutID,
            momentID: (dict["momentID"] as? String).flatMap(UUID.init),
            transcript: dict["transcript"] as? String,
            confidence: dict["confidence"] as? Double,
            timestamp: Date(timeIntervalSince1970: timestampInterval),
            error: dict["error"] as? String
        )
    }
}

// MARK: - Index

struct WorkoutSessionIndex: Codable, Identifiable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var momentCount: Int
    var hasStructuredLog: Bool
    var exerciseNames: [String]
    var exerciseCount: Int
    var totalSets: Int
    var totalVolume: Double
    var hasStories: Bool

    private enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, momentCount, hasStructuredLog, exerciseNames
        case exerciseCount, totalSets, totalVolume, hasStories
    }

    init(from session: WorkoutSession) {
        self.id = session.id
        self.startedAt = session.startedAt
        self.endedAt = session.endedAt
        self.momentCount = session.moments.count
        self.hasStructuredLog = session.structuredLog != nil
        self.exerciseNames = session.structuredLog?.exercises.map(\.exerciseName) ?? []
        let exercises = session.structuredLog?.exercises ?? []
        self.exerciseCount = exercises.count
        self.totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        self.totalVolume = exercises.reduce(0.0) { total, group in
            total + group.sets.reduce(0.0) { setTotal, set in
                setTotal + Double(set.reps ?? 0) * (set.weight ?? 0)
            }
        }
        self.hasStories = !session.stories.isEmpty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.endedAt = try? container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.momentCount = (try? container.decode(Int.self, forKey: .momentCount)) ?? 0
        self.hasStructuredLog = (try? container.decode(Bool.self, forKey: .hasStructuredLog)) ?? false
        self.exerciseNames = (try? container.decode([String].self, forKey: .exerciseNames)) ?? []
        self.exerciseCount = (try? container.decode(Int.self, forKey: .exerciseCount)) ?? 0
        self.totalSets = (try? container.decode(Int.self, forKey: .totalSets)) ?? 0
        self.totalVolume = (try? container.decode(Double.self, forKey: .totalVolume)) ?? 0
        self.hasStories = (try? container.decode(Bool.self, forKey: .hasStories)) ?? false
    }

    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
}

// MARK: - AI Processing

struct AIWorkoutOutput: Codable {
    var structuredLog: StructuredLog
    var contentPack: ContentPack
    var stories: [InsightStory]

    private enum CodingKeys: String, CodingKey {
        case structuredLog, contentPack, stories
    }

    init(
        structuredLog: StructuredLog = StructuredLog(),
        contentPack: ContentPack = ContentPack(),
        stories: [InsightStory] = []
    ) {
        self.structuredLog = structuredLog
        self.contentPack = contentPack
        self.stories = stories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.structuredLog = (try? container.decode(StructuredLog.self, forKey: .structuredLog)) ?? StructuredLog()
        self.contentPack = (try? container.decode(ContentPack.self, forKey: .contentPack)) ?? ContentPack()
        self.stories = (try? container.decode([InsightStory].self, forKey: .stories)) ?? []
    }
}

struct WorkoutProcessingRequest: Codable, Identifiable {
    let id: UUID
    var workoutID: UUID
    var transcripts: [MomentTranscript]
    var workoutDate: Date
    var duration: TimeInterval
    var retryCount: Int
    var lastAttempt: Date?

    init(
        workoutID: UUID,
        transcripts: [MomentTranscript],
        workoutDate: Date,
        duration: TimeInterval,
        retryCount: Int = 0,
        lastAttempt: Date? = nil
    ) {
        self.id = UUID()
        self.workoutID = workoutID
        self.transcripts = transcripts
        self.workoutDate = workoutDate
        self.duration = duration
        self.retryCount = retryCount
        self.lastAttempt = lastAttempt
    }
}

struct MomentTranscript: Codable {
    var momentID: UUID
    var timestamp: Date
    var transcript: String
}

// MARK: - Legacy Support

struct LegacyTranscriptionRecord: Codable, Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date
}
