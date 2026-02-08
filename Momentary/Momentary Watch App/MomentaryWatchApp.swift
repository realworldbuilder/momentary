import SwiftUI

@main
struct MomentaryWatchApp: App {
    @State private var workoutManager = WatchWorkoutManager()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(workoutManager)
        }
    }
}
