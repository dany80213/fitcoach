import SwiftUI
import SwiftData

@main
struct FitCoachApp: App {
    @State private var restTimer = RestTimer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(restTimer)
        }
        .modelContainer(for: [Workout.self, WorkoutExercise.self, SetEntry.self, FoodEntry.self,
                              Exercise.self, Routine.self, RoutineExercise.self, RoutineSet.self, Profile.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(RestTimer.self) private var restTimer

    var body: some View {
        TabView {
            HomeView().restTimerInset()
                .tabItem { Label("Home", systemImage: "house") }
            TrainingView().restTimerInset()
                .tabItem { Label("Allenamenti", systemImage: "dumbbell") }
            NutritionView().restTimerInset()
                .tabItem { Label("Calorie", systemImage: "fork.knife") }
            AgentView().restTimerInset()
                .tabItem { Label("Coach", systemImage: "sparkles") }
            ProfileView().restTimerInset()
                .tabItem { Label("Profilo", systemImage: "person.crop.circle") }
        }
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
        .sensoryFeedback(.success, trigger: restTimer.finishedCount)
        .task { await ExerciseLibrary.autoSync(in: context) }
    }
}
