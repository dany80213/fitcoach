import SwiftUI
import SwiftData

// MARK: - Sezione Allenamenti (routine)

struct TrainingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            routineList
                .background(AppBackground())
                .navigationTitle("Allenamenti")
                .navigationDestination(for: Routine.self) { RoutineEditorView(routine: $0) }
                .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
                .toolbar {
                    Menu {
                        Button { newRoutine() } label: { Label("Nuova routine", systemImage: "list.clipboard") }
                        Button { emptyWorkout() } label: { Label("Allenamento vuoto", systemImage: "plus.circle") }
                    } label: { Label("Aggiungi", systemImage: "plus") }
                }
        }
    }

    private func newRoutine() {
        let r = Routine(name: "Nuova routine")
        context.insert(r)
        path.append(r)
    }

    private func emptyWorkout() {
        let w = Workout(name: "Allenamento del \(Date.now.formatted(date: .abbreviated, time: .omitted))")
        context.insert(w)
        path.append(w)
    }

    private var routineList: some View {
        List {
            ForEach(routines) { r in
                NavigationLink(value: r) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.headline)
                            Text(summary(r)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Avvia") {
                            path.append(r.makeWorkout(in: context))
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.small)
                        .disabled(r.items.isEmpty)
                    }
                }
            }
            .onDelete { idx in idx.map { routines[$0] }.forEach(context.delete) }
        }
        .transparentList()
        .overlay {
            if routines.isEmpty {
                ContentUnavailableView("Nessuna routine", systemImage: "list.clipboard",
                                       description: Text("Tocca + per crearne una con i tuoi esercizi."))
            }
        }
    }

    private func summary(_ r: Routine) -> String {
        let sets = r.items.reduce(0) { $0 + $1.sets.count }
        let names = r.sortedItems.prefix(3).map(\.exerciseName).joined(separator: ", ")
        return "\(r.items.count) esercizi · \(sets) serie" + (names.isEmpty ? "" : " — \(names)")
    }
}

// MARK: - Editor routine

struct RoutineEditorView: View {
    @Bindable var routine: Routine
    @Environment(\.modelContext) private var context
    @State private var showPicker = false

    var body: some View {
        List {
            Section {
                TextField("Nome routine", text: $routine.name)
                TextField("Note", text: $routine.notes, axis: .vertical)
            }
            ForEach(routine.sortedItems) { item in
                RoutineItemSection(item: item, siblings: routine.sortedItems)
            }
            Section {
                Button { showPicker = true } label: { Label("Aggiungi esercizio", systemImage: "plus.circle") }
            }
        }
        .navigationTitle(routine.name)
        .glassList()
        .sheet(isPresented: $showPicker) {
            ExercisePickerView { name in
                let item = RoutineExercise(exerciseName: name, order: routine.nextItemOrder)
                context.insert(item)
                routine.items.append(item)
                let set = RoutineSet(order: 0)
                context.insert(set)
                item.sets.append(set)
            }
        }
    }
}

private struct RoutineItemSection: View {
    @Bindable var item: RoutineExercise
    let siblings: [RoutineExercise]
    @Environment(\.modelContext) private var context

    var body: some View {
        let sets = item.sortedSets
        let labels = setLabels(sets.map(\.setType))
        let index = siblings.firstIndex { $0 === item } ?? 0
        let letters = Superset.letters(siblings)
        Section {
            ForEach(Array(sets.enumerated()), id: \.element.persistentModelID) { i, s in
                RoutineSetRow(set: s, label: labels[i])
            }
            .onDelete { idx in idx.map { sets[$0] }.forEach(context.delete) }
            Button("Aggiungi serie") {
                let last = sets.last
                let s = RoutineSet(order: item.nextSetOrder, type: last?.setType == .warmup ? .normal : (last?.setType ?? .normal),
                                   reps: last?.reps ?? 10, weight: last?.weight ?? 0)
                context.insert(s)
                item.sets.append(s)
            }
        } header: {
            ExerciseHeader(
                name: item.exerciseName,
                supersetLetter: letters[item.supersetID],
                restSeconds: $item.restSeconds,
                canJoin: index > 0 && (siblings[index - 1].supersetID != item.supersetID || item.supersetID == 0),
                onJoin: { Superset.join(item, with: siblings[index - 1], in: siblings) },
                onLeave: { Superset.leave(item, in: siblings) },
                onRemove: {
                    let gid = item.supersetID
                    context.delete(item)
                    Superset.cleanup(gid, in: siblings.filter { $0 !== item })
                })
        }
    }
}

private struct RoutineSetRow: View {
    @Bindable var set: RoutineSet
    let label: String

    var body: some View {
        HStack {
            SetTypeMenu(type: $set.type, label: label)
            Spacer()
            TextField("kg", value: $set.weight, format: .number)
                .multilineTextAlignment(.trailing).frame(width: 70)
            Text("kg").foregroundStyle(.secondary)
            TextField("rip", value: $set.reps, format: .number)
                .multilineTextAlignment(.trailing).frame(width: 50)
            Text("rip").foregroundStyle(.secondary)
        }
        .textFieldStyle(.roundedBorder)
        #if os(iOS)
        .keyboardType(.decimalPad)
        #endif
    }
}

// MARK: - Componenti condivisi

/// Pallino con numero/lettera della serie; toccandolo si sceglie il tipo (Normale, Riscaldamento, Cedimento, Drop set).
struct SetTypeMenu: View {
    @Binding var type: String
    let label: String

    private var current: SetType { SetType(rawValue: type) ?? .normal }

    var body: some View {
        Menu {
            ForEach(SetType.allCases) { t in
                Button { type = t.rawValue } label: {
                    if t == current { Label(t.title, systemImage: "checkmark") } else { Text(t.title) }
                }
            }
        } label: {
            Text(label)
                .font(.subheadline.bold())
                .frame(width: 34, height: 34)
                .foregroundStyle(current == .normal ? Color.primary : color)
                .glassEffect(.regular.tint(color.opacity(current == .normal ? 0.0 : 0.35)).interactive(), in: .circle)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var color: Color {
        switch current {
        case .normal: .secondary
        case .warmup: .orange
        case .failure: .red
        case .dropset: .purple
        }
    }
}

/// Scelta di un esercizio dalla libreria (con ricerca e filtro per muscolo) o creazione di uno personalizzato.
struct ExercisePickerView: View {
    let onPick: (String) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var all: [Exercise]
    @State private var query = ""
    @State private var muscle: String?
    @State private var syncing = false
    @State private var error: String?
    @State private var showCustom = false
    @State private var customName = ""

    private var muscles: [String] { Array(Set(all.map(\.muscle).filter { !$0.isEmpty })).sorted() }

    /// Ogni parola cercata deve comparire (anche parziale) in nome, alias, muscolo (EN/IT) o attrezzo:
    /// "chest fly", "pec dec", "petto manubri" trovano gli esercizi giusti.
    private var filtered: [Exercise] {
        let tokens = query.lowercased().split(separator: " ").map(String.init)
        return all.filter { e in
            guard muscle == nil || e.muscle == muscle else { return false }
            if tokens.isEmpty { return true }
            let hay = [e.name, e.aliases, e.muscle, Muscle.label(e.muscle), e.equipment]
                .joined(separator: " ").lowercased().folding(options: .diacriticInsensitive, locale: nil)
            return tokens.allSatisfy { hay.contains($0.folding(options: .diacriticInsensitive, locale: nil)) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
                ForEach(filtered) { e in
                    Button {
                        onPick(e.name); dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.name).foregroundStyle(.primary)
                            Text([Muscle.label(e.muscle), e.equipment.capitalized, e.aliases.split(separator: ",").first.map(String.init)]
                                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay {
                if syncing && all.isEmpty { ProgressView("Scarico gli esercizi…") }
                else if all.isEmpty {
                    ContentUnavailableView {
                        Label("Libreria vuota", systemImage: "icloud.and.arrow.down")
                    } description: {
                        Text("Scarica la libreria o crea un esercizio personalizzato.")
                    } actions: {
                        Button("Scarica esercizi", action: refresh)
                    }
                }
            }
            .glassList()
            .searchable(text: $query, prompt: "Cerca esercizio")
            .navigationTitle("Esercizi")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button("Tutti i muscoli") { muscle = nil }
                        ForEach(muscles, id: \.self) { m in Button(Muscle.label(m)) { muscle = m } }
                    } label: { Label(muscle.map(Muscle.label) ?? "Muscolo", systemImage: "line.3.horizontal.decrease.circle") }
                    Button(action: refresh) { Label("Aggiorna libreria", systemImage: "arrow.clockwise") }.disabled(syncing)
                    Button { showCustom = true } label: { Label("Nuovo", systemImage: "plus") }
                }
            }
            .alert("Esercizio personalizzato", isPresented: $showCustom) {
                TextField("Nome", text: $customName)
                Button("Crea") { createCustom() }
                Button("Annulla", role: .cancel) { customName = "" }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }

    private func refresh() {
        syncing = true; error = nil
        Task {
            do { try await ExerciseLibrary.sync(in: context) }
            catch { self.error = "Aggiornamento non riuscito: \(error.localizedDescription)" }
            syncing = false
        }
    }

    private func createCustom() {
        let name = customName.trimmingCharacters(in: .whitespaces)
        customName = ""
        guard !name.isEmpty else { return }
        context.insert(Exercise(key: "custom-\(UUID().uuidString)", name: name, isCustom: true))
        onPick(name); dismiss()
    }
}
