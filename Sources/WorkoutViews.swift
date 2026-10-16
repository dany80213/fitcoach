import SwiftUI
import SwiftData

struct WorkoutListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            List {
                ForEach(workouts) { w in
                    NavigationLink(value: w) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.name).font(.headline)
                            Text("\(w.date.formatted(date: .abbreviated, time: .omitted)) · \(w.exercises.count) esercizi · \(Int(w.totalVolume)) kg volume")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idx in idx.map { workouts[$0] }.forEach(context.delete) }
            }
            .overlay { if workouts.isEmpty { ContentUnavailableView("Nessun allenamento", systemImage: "dumbbell", description: Text("Tocca + per iniziare.")) } }
            .navigationTitle("Allenamenti")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .toolbar {
                Button {
                    context.insert(Workout(name: "Allenamento del \(Date.now.formatted(date: .abbreviated, time: .omitted))"))
                } label: { Label("Nuovo", systemImage: "plus") }
            }
        }
    }
}

struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var context
    @State private var newExercise = ""
    @State private var showAdd = false

    private static let suggestions = ["Panca piana", "Squat", "Stacco da terra", "Military press", "Trazioni", "Rematore", "Curl bicipiti", "Push down"]

    var body: some View {
        List {
            Section { TextField("Nome", text: $workout.name) }
            ForEach(workout.sortedExercises) { ex in
                ExerciseSection(exercise: ex, previous: previousSets(for: ex.name))
            }
            Section {
                Button { showAdd = true } label: { Label("Aggiungi esercizio", systemImage: "plus.circle") }
            }
        }
        .navigationTitle(workout.name)
        .alert("Nuovo esercizio", isPresented: $showAdd) {
            TextField("Nome esercizio", text: $newExercise)
            Button("Aggiungi") { addExercise(newExercise) }
            Button("Annulla", role: .cancel) { newExercise = "" }
        }
        .toolbar {
            Menu {
                ForEach(Self.suggestions, id: \.self) { s in Button(s) { addExercise(s) } }
            } label: { Label("Esercizi comuni", systemImage: "list.bullet") }
        }
    }

    private func addExercise(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespaces)
        newExercise = ""
        guard !n.isEmpty else { return }
        let ex = WorkoutExercise(name: n, order: workout.exercises.count)
        ex.workout = workout
        context.insert(ex)
        // Precompila dalle serie dell'ultima volta (come fa Hevy).
        let prev = previousSets(for: n)
        if prev.isEmpty { addSet(to: ex) }
        else { prev.enumerated().forEach { i, s in
            let set = SetEntry(order: i, reps: s.reps, weight: s.weight); set.exercise = ex; context.insert(set) } }
    }

    private func addSet(to ex: WorkoutExercise) {
        let last = ex.sortedSets.last
        let s = SetEntry(order: ex.sets.count, reps: last?.reps ?? 8, weight: last?.weight ?? 0)
        s.exercise = ex
        context.insert(s)
    }

    private func previousSets(for name: String) -> [SetEntry] {
        let d = FetchDescriptor<WorkoutExercise>(predicate: #Predicate { $0.name == name })
        let all = (try? context.fetch(d)) ?? []
        return all.filter { $0.workout != nil && $0.workout !== workout }
            .max { ($0.workout?.date ?? .distantPast) < ($1.workout?.date ?? .distantPast) }?
            .sortedSets ?? []
    }
}

private struct ExerciseSection: View {
    @Bindable var exercise: WorkoutExercise
    let previous: [SetEntry]
    @Environment(\.modelContext) private var context

    var body: some View {
        Section(exercise.name) {
            ForEach(exercise.sortedSets) { s in
                SetRow(set: s, previous: previous.indices.contains(s.order) ? previous[s.order] : nil)
            }
            .onDelete { idx in idx.map { exercise.sortedSets[$0] }.forEach(context.delete) }
            Button("Aggiungi serie") {
                let last = exercise.sortedSets.last
                let s = SetEntry(order: exercise.sets.count, reps: last?.reps ?? 8, weight: last?.weight ?? 0)
                s.exercise = exercise
                context.insert(s)
            }
        }
    }
}

private struct SetRow: View {
    @Bindable var set: SetEntry
    let previous: SetEntry?

    var body: some View {
        HStack {
            Text("\(set.order + 1)").frame(width: 24).foregroundStyle(.secondary)
            if let p = previous {
                Text("\(p.weight.formatted()) × \(p.reps)").font(.caption).foregroundStyle(.secondary).frame(width: 70)
            }
            TextField("kg", value: $set.weight, format: .number).multilineTextAlignment(.trailing).frame(width: 60)
            Text("kg")
            TextField("rip", value: $set.reps, format: .number).multilineTextAlignment(.trailing).frame(width: 40)
            Text("rip")
            Spacer()
            Toggle("Fatta", isOn: $set.isDone).labelsHidden()
        }
        .textFieldStyle(.roundedBorder)
        #if os(iOS)
        .keyboardType(.decimalPad)
        #endif
    }
}
