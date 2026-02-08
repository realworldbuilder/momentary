import Foundation
import Network
import os

enum AIProcessingState: Equatable {
    case idle
    case processing(stage: String)
    case completed
    case failed(String)
    case queued

    static func == (lhs: AIProcessingState, rhs: AIProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.completed, .completed), (.queued, .queued): return true
        case (.processing(let a), .processing(let b)): return a == b
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

@Observable
@MainActor
final class AIProcessingPipeline {
    private static let logger = Logger(subsystem: "com.whussey.momentary", category: "AIProcessingPipeline")

    var state: AIProcessingState = .idle

    private let backend: AIBackend
    private let workoutStore: WorkoutStore
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true
    private let maxRetries = 3

    private static var pendingQueueURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("pending_ai_queue.json")
    }

    init(backend: AIBackend = OpenAIBackend(), workoutStore: WorkoutStore) {
        self.backend = backend
        self.workoutStore = workoutStore
        startNetworkMonitoring()
    }

    // MARK: - Process Workout

    func processWorkout(_ session: WorkoutSession) async {
        guard !session.moments.isEmpty else {
            state = .completed
            return
        }

        guard let duration = session.duration, duration > 0 else {
            state = .failed("Workout has no duration")
            return
        }

        if !isNetworkAvailable {
            queueForLater(session)
            state = .queued
            return
        }

        state = .processing(stage: "Analyzing workout...")

        let systemPrompt = AIPromptBuilder.buildSystemPrompt()
        let userPrompt = AIPromptBuilder.buildUserPrompt(
            moments: session.moments,
            workoutDate: session.startedAt,
            duration: duration
        )

        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                if attempt > 0 {
                    let delay = pow(2.0, Double(attempt))
                    state = .processing(stage: "Retrying in \(Int(delay))s...")
                    try await Task.sleep(for: .seconds(delay))
                }

                state = .processing(stage: "Generating structured log and content...")
                let responseJSON = try await backend.complete(systemPrompt: systemPrompt, userPrompt: userPrompt)

                state = .processing(stage: "Parsing response...")
                let output = try parseResponse(responseJSON)

                var updatedSession = session
                updatedSession.structuredLog = output.structuredLog
                updatedSession.contentPack = output.contentPack
                updatedSession.stories = output.stories
                workoutStore.saveSession(updatedSession)

                state = .completed
                Self.logger.info("AI processing completed for workout \(session.id)")
                return

            } catch let error as AIProcessingError {
                lastError = error
                if case .rateLimited(let retryAfter) = error {
                    state = .processing(stage: "Rate limited, waiting \(Int(retryAfter))s...")
                    try? await Task.sleep(for: .seconds(retryAfter))
                    continue
                }
                if case .noAPIKey = error {
                    state = .failed(error.localizedDescription)
                    return
                }
            } catch {
                lastError = error
            }
        }

        // All retries failed — queue for later
        queueForLater(session)
        state = .failed(lastError?.localizedDescription ?? "Processing failed after \(maxRetries) attempts")
    }

    // MARK: - Parse Response

    private func parseResponse(_ json: String) throws -> AIWorkoutOutput {
        guard let data = json.data(using: .utf8) else {
            throw AIProcessingError.parsingFailed("Invalid UTF-8")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(AIWorkoutOutput.self, from: data)
        } catch {
            throw AIProcessingError.parsingFailed(error.localizedDescription)
        }
    }

    // MARK: - Offline Queue

    private func queueForLater(_ session: WorkoutSession) {
        let request = WorkoutProcessingRequest(
            workoutID: session.id,
            transcripts: session.moments.map {
                MomentTranscript(momentID: $0.id, timestamp: $0.timestamp, transcript: $0.transcript)
            },
            workoutDate: session.startedAt,
            duration: session.duration ?? 0
        )

        var queue = loadPendingQueue()
        queue.removeAll { $0.workoutID == session.id }
        queue.append(request)
        savePendingQueue(queue)
        Self.logger.info("Queued workout \(session.id) for later processing")
    }

    func processPendingQueue() async {
        var queue = loadPendingQueue()
        guard !queue.isEmpty, isNetworkAvailable else { return }

        var remaining: [WorkoutProcessingRequest] = []

        for request in queue {
            guard let session = workoutStore.loadSession(id: request.workoutID) else { continue }
            if session.structuredLog != nil { continue }

            await processWorkout(session)

            if state != .completed {
                var updated = request
                updated.retryCount += 1
                updated.lastAttempt = Date()
                if updated.retryCount < maxRetries {
                    remaining.append(updated)
                }
            }
        }

        savePendingQueue(remaining)
    }

    private func loadPendingQueue() -> [WorkoutProcessingRequest] {
        let url = Self.pendingQueueURL
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([WorkoutProcessingRequest].self, from: data)
        } catch {
            return []
        }
    }

    private func savePendingQueue(_ queue: [WorkoutProcessingRequest]) {
        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: Self.pendingQueueURL, options: .atomic)
        } catch {
            Self.logger.error("Failed to save pending queue: \(error)")
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let wasUnavailable = !self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied

                if wasUnavailable && self.isNetworkAvailable {
                    await self.processPendingQueue()
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "com.momentary.networkmonitor"))
    }
}
