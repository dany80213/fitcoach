import SwiftUI
import SwiftData

@main
struct FitCoachApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Workout.self, WorkoutExercise.self, SetEntry.self, FoodEntry.self])
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            WorkoutListView()
                .tabItem { Label("Allenamenti", systemImage: "dumbbell") }
            NutritionView()
                .tabItem { Label("Calorie", systemImage: "fork.knife") }
            AgentView()
                .tabItem { Label("Coach", systemImage: "sparkles") }
            SettingsView()
                .tabItem { Label("Impostazioni", systemImage: "gearshape") }
        }
    }
}
