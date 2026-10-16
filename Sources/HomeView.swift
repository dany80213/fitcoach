import SwiftUI
import SwiftData

/// Home: saluto, riepilogo degli ultimi 7 giorni e storico di tutti gli allenamenti passati.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]
    @Query private var profiles: [Profile]

    /// Gli allenamenti senza esercizi (creati per sbaglio) non entrano nello storico.
    private var workouts: [Workout] { allWorkouts.filter { !$0.exercises.isEmpty } }

    private var months: [(month: Date, items: [Workout])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: workouts) { cal.date(from: cal.dateComponents([.year, .month], from: $0.date))! }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.date > $1.date }) }
    }

    private var lastWeek: [Workout] {
        let since = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return workouts.filter { $0.date >= since }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    greeting
                    weekSummary
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))

                ForEach(months, id: \.month) { group in
                    Section(group.month.formatted(.dateTime.month(.wide).year())) {
                        ForEach(group.items) { w in
                            NavigationLink(value: w) { WorkoutRow(workout: w) }
                        }
                        .onDelete { idx in idx.map { group.items[$0] }.forEach(context.delete) }
                    }
                }
            }
            .transparentList()
            .background(AppBackground())
            .overlay {
                if workouts.isEmpty {
                    ContentUnavailableView("Ancora nessun allenamento", systemImage: "figure.strengthtraining.traditional",
                                           description: Text("Avvia una routine dalla scheda Allenamenti: comparirà qui."))
                        .padding(.top, 220)
                }
            }
            .navigationTitle("Home")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
        }
    }

    private var greeting: some View {
        HStack(spacing: 14) {
            ProfileAvatar(data: profiles.first?.photoData, name: profiles.first?.name ?? "", size: 56)
            VStack(alignment: .leading, spacing: 2) {
                let name = profiles.first?.name ?? ""
                Text(name.isEmpty ? "Ciao!" : "Ciao, \(name)").font(.title2.bold())
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var weekSummary: some View {
        let volume = lastWeek.reduce(0) { $0 + $1.totalVolume }
        let sets = lastWeek.reduce(0) { $0 + $1.totalSetCount }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Ultimi 7 giorni").font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    stat("\(lastWeek.count)", "allenamenti")
                    stat("\(sets)", "serie")
                    stat(volume >= 1000 ? String(format: "%.1f t", volume / 1000) : "\(Int(volume)) kg", "volume")
                }
            }
        }
        .padding(.top, 8)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold()).minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.name).font(.headline)
                Spacer()
                Text(workout.date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(workout.sortedExercises.prefix(3).map(\.name).joined(separator: ", ")
                 + (workout.exercises.count > 3 ? " +\(workout.exercises.count - 3)" : ""))
                .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            Text("\(workout.exercises.count) esercizi · \(workout.totalSetCount) serie · \(Int(workout.totalVolume)) kg")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
