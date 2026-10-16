import SwiftUI
import SwiftData

@main
struct FitCoachApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Workout.self, WorkoutExercise.self, SetEntry.self, FoodEntry.self,
                              Exercise.self, Routine.self, RoutineExercise.self, RoutineSet.self, Profile.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            TrainingView()
                .tabItem { Label("Allenamenti", systemImage: "dumbbell") }
            NutritionView()
                .tabItem { Label("Calorie", systemImage: "fork.knife") }
            AgentView()
                .tabItem { Label("Coach", systemImage: "sparkles") }
            ProfileView()
                .tabItem { Label("Profilo", systemImage: "person.crop.circle") }
        }
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
        .task { await ExerciseLibrary.autoSync(in: context) }
    }
}
