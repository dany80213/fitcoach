import SwiftUI
import SwiftData

@main
struct FitCoachApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Workout.self, WorkoutExercise.self, SetEntry.self, FoodEntry.self,
                              Exercise.self, Routine.self, RoutineExercise.self, RoutineSet.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            TrainingView()
                .tabItem { Label("Allenamenti", systemImage: "dumbbell") }
            NutritionView()
                .tabItem { Label("Calorie", systemImage: "fork.knife") }
            AgentView()
                .tabItem { Label("Coach", systemImage: "sparkles") }
            SettingsView()
                .tabItem { Label("Impostazioni", systemImage: "gearshape") }
        }
        .task { await ExerciseLibrary.autoSync(in: context) }
    }
}
