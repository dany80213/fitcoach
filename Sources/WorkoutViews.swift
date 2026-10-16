import SwiftUI
import SwiftData

/// Allenamento in corso o passato: esercizi e serie con tipo, peso, ripetizioni e spunta.
struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var context
    @State private var showPicker = false

    var body: some View {
        List {
            Section { TextField("Nome", text: $workout.name) }
            ForEach(workout.sortedExercises) { ex in
                ExerciseSection(exercise: ex,
                                previous: Workout.previousSets(for: ex.name, excluding: workout, in: context))
            }
            Section {
                Button { showPicker = true } label: { Label("Aggiungi esercizio", systemImage: "plus.circle") }
            }
        }
        .navigationTitle(workout.name)
        .glassList()
        .sheet(isPresented: $showPicker) { ExercisePickerView { addExercise($0) } }
    }

    private func addExercise(_ name: String) {
        let ex = WorkoutExercise(name: name, order: workout.exercises.count)
        context.insert(ex)
        workout.exercises.append(ex)
        // Precompila dalle serie dell'ultima volta (come fa Hevy).
        let prev = Workout.previousSets(for: name, excluding: workout, in: context)
        if prev.isEmpty {
            let s = SetEntry(order: 0); context.insert(s); ex.sets.append(s)
        } else {
            for (i, p) in prev.enumerated() {
                let s = SetEntry(order: i, reps: p.reps, weight: p.weight, type: p.setType)
                context.insert(s)
                ex.sets.append(s)
            }
        }
    }
}

private struct ExerciseSection: View {
    @Bindable var exercise: WorkoutExercise
    let previous: [SetEntry]
    @Environment(\.modelContext) private var context

    var body: some View {
        let sets = exercise.sortedSets
        let labels = setLabels(sets.map(\.setType))
        Section {
            ForEach(Array(sets.enumerated()), id: \.element.persistentModelID) { i, s in
                SetRow(set: s, label: labels[i], previous: previous.indices.contains(i) ? previous[i] : nil)
            }
            .onDelete { idx in idx.map { sets[$0] }.forEach(context.delete) }
            Button("Aggiungi serie") {
                let last = sets.last
                let s = SetEntry(order: exercise.nextSetOrder, reps: last?.reps ?? 8, weight: last?.weight ?? 0)
                context.insert(s)
                exercise.sets.append(s)
            }
        } header: {
            HStack {
                Text(exercise.name)
                Spacer()
                Menu {
                    Button("Rimuovi esercizio", role: .destructive) { context.delete(exercise) }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }
}

private struct SetRow: View {
    @Bindable var set: SetEntry
    let label: String
    let previous: SetEntry?

    var body: some View {
        HStack {
            SetTypeMenu(type: $set.type, label: label)
            if let p = previous {
                Text("\(p.weight.formatted())×\(p.reps)").font(.caption).foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)
            }
            Spacer(minLength: 0)
            TextField("kg", value: $set.weight, format: .number).multilineTextAlignment(.trailing).frame(width: 56)
            TextField("rip", value: $set.reps, format: .number).multilineTextAlignment(.trailing).frame(width: 40)
            Toggle("Fatta", isOn: $set.isDone).labelsHidden()
        }
        .textFieldStyle(.roundedBorder)
        #if os(iOS)
        .keyboardType(.decimalPad)
        #endif
    }
}
