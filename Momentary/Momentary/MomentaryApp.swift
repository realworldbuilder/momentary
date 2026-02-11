import SwiftUI

@main
struct MomentaryApp: App {
    @State private var workoutManager: WorkoutManager
    @State private var aiPipeline: AIProcessingPipeline
    @State private var insightsService: InsightsService

    init() {
        let manager = WorkoutManager()
        let pipeline = AIProcessingPipeline(workoutStore: manager.workoutStore)
        let insights = InsightsService(workoutStore: manager.workoutStore)
        manager.setAIPipeline(pipeline)
        pipeline.insightsService = insights
        _workoutManager = State(initialValue: manager)
        _aiPipeline = State(initialValue: pipeline)
        _insightsService = State(initialValue: insights)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(workoutManager)
                .environment(aiPipeline)
                .environment(insightsService)
                .preferredColorScheme(.dark)
                .task {
                    await aiPipeline.processPendingQueue()
                    await insightsService.generateInsights()
                }
        }
    }
}
