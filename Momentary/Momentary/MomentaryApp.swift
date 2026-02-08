import SwiftUI

@main
struct MomentaryApp: App {
    @State private var workoutManager = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(workoutManager)
        }
    }
}
