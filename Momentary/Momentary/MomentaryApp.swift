import SwiftUI

@main
struct MomentaryApp: App {
    @State private var workoutManager: WorkoutManager
    @State private var aiPipeline: AIProcessingPipeline

    init() {
        let manager = WorkoutManager()
        let pipeline = AIProcessingPipeline(workoutStore: manager.workoutStore)
        manager.setAIPipeline(pipeline)
        _workoutManager = State(initialValue: manager)
        _aiPipeline = State(initialValue: pipeline)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(workoutManager)
                .environment(aiPipeline)
                .task {
                    await aiPipeline.processPendingQueue()
                }
        }
    }
}
