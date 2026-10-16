import SwiftUI
import SwiftData

struct NutritionView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date) private var all: [FoodEntry]
    @AppStorage("calorieGoal") private var calorieGoal = 2200.0
    @AppStorage("proteinGoal") private var proteinGoal = 150.0
    @State private var day = Date.now
    @State private var showAdd = false

    private var entries: [FoodEntry] { all.filter { Calendar.current.isDate($0.date, inSameDayAs: day) } }
    private var kcal: Double { entries.reduce(0) { $0 + $1.calories } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Giorno", selection: $day, displayedComponents: .date)
                    VStack(alignment: .leading) {
                        ProgressView(value: min(kcal / calorieGoal, 1)) { Text("\(Int(kcal)) / \(Int(calorieGoal)) kcal") }
                        HStack {
                            Text("P \(Int(entries.reduce(0) { $0 + $1.protein })) / \(Int(proteinGoal)) g")
                            Text("C \(Int(entries.reduce(0) { $0 + $1.carbs })) g")
                            Text("G \(Int(entries.reduce(0) { $0 + $1.fat })) g")
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                }
                ForEach(Meal.allCases) { meal in
                    let items = entries.filter { $0.meal == meal.rawValue }
                    if !items.isEmpty {
                        Section("\(meal.rawValue) · \(Int(items.reduce(0) { $0 + $1.calories })) kcal") {
                            ForEach(items) { e in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(e.name)
                                        Text("\(Int(e.grams)) g").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(e.calories)) kcal")
                                }
                            }
                            .onDelete { idx in idx.map { items[$0] }.forEach(context.delete) }
                        }
                    }
                }
            }
            .navigationTitle("Calorie")
            .toolbar { Button { showAdd = true } label: { Label("Aggiungi", systemImage: "plus") } }
            .sheet(isPresented: $showAdd) { AddFoodView(day: day) }
        }
    }
}

struct AddFoodView: View {
    let day: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [FoodItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var selected: FoodItem?
    @State private var manual = false

    private let provider: FoodSearchProvider = OpenFoodFactsProvider()

    var body: some View {
        NavigationStack {
            List {
                if let error { Text(error).foregroundStyle(.red) }
                ForEach(results) { item in
                    Button { selected = item } label: {
                        VStack(alignment: .leading) {
                            Text(item.name).foregroundStyle(.primary)
                            Text("\([item.brand, "\(Int(item.kcal100)) kcal/100g"].compactMap { $0 }.joined(separator: " · "))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay { if loading { ProgressView() } }
            .searchable(text: $query, prompt: "Cerca alimento")
            .onSubmit(of: .search) { Task { await search() } }
            .navigationTitle("Aggiungi alimento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Manuale") { manual = true } }
            }
            .sheet(item: $selected) { item in PortionView(item: item, day: day) { dismiss() } }
            .sheet(isPresented: $manual) { PortionView(item: FoodItem(name: "", brand: nil, kcal100: 0, protein100: 0, carbs100: 0, fat100: 0), day: day, editable: true) { dismiss() } }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
    }

    private func search() async {
        loading = true; error = nil
        defer { loading = false }
        do { results = try await provider.search(query) }
        catch { self.error = "Ricerca non riuscita: \(error.localizedDescription)" }
    }
}

private struct PortionView: View {
    @State var item: FoodItem
    let day: Date
    var editable = false
    let onDone: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var grams = 100.0
    @State private var meal = Meal.lunch

    var body: some View {
        NavigationStack {
            Form {
                if editable {
                    TextField("Nome", text: $item.name)
                    TextField("kcal / 100 g", value: $item.kcal100, format: .number)
                    TextField("Proteine / 100 g", value: $item.protein100, format: .number)
                    TextField("Carboidrati / 100 g", value: $item.carbs100, format: .number)
                    TextField("Grassi / 100 g", value: $item.fat100, format: .number)
                } else {
                    Text(item.name).font(.headline)
                }
                TextField("Grammi", value: $grams, format: .number)
                Picker("Pasto", selection: $meal) { ForEach(Meal.allCases) { Text($0.rawValue).tag($0) } }
                Text("\(Int(item.kcal100 * grams / 100)) kcal").font(.title2)
            }
            .navigationTitle("Porzione")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        let f = grams / 100
                        context.insert(FoodEntry(name: item.name, meal: meal, date: day, grams: grams,
                                                 calories: item.kcal100 * f, protein: item.protein100 * f,
                                                 carbs: item.carbs100 * f, fat: item.fat100 * f))
                        dismiss(); onDone()
                    }.disabled(item.name.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 360)
        #endif
    }
}
