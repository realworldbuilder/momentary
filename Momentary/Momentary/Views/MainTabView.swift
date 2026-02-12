import SwiftUI

struct MainTabView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var selectedTab = 0

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(0)

            if workoutManager.activeSession != nil {
                ActiveWorkoutTab()
                    .tabItem {
                        Label("Workout", systemImage: "figure.strengthtraining.traditional")
                    }
                    .tag(1)
            }

            InsightsTab()
                .tabItem {
                    Label("Insights", systemImage: "lightbulb.fill")
                }
                .tag(2)
        }
        .tint(Theme.accent)
        .onChange(of: workoutManager.activeSession?.id) { oldVal, newVal in
            if newVal != nil && oldVal == nil {
                selectedTab = 1
            } else if newVal == nil && oldVal != nil {
                selectedTab = 0
            }
        }
    }
}
