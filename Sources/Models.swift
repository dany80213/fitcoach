import Foundation
import SwiftData

@Model
final class Workout {
    var name: String
    var date: Date
    var notes: String
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise] = []

    init(name: String, date: Date = .now, notes: String = "") {
        self.name = name
        self.date = date
        self.notes = notes
    }

    var sortedExercises: [WorkoutExercise] { exercises.sorted { $0.order < $1.order } }

    /// Volume totale = somma(peso × ripetizioni) sulle serie completate, riscaldamento escluso.
    var totalVolume: Double {
        exercises.flatMap(\.sets).filter { $0.isDone && $0.setType.countsAsWork }
            .reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    /// Serie dell'ultima volta che l'esercizio è stato fatto in un altro allenamento.
    static func previousSets(for name: String, excluding workout: Workout, in context: ModelContext) -> [SetEntry] {
        let d = FetchDescriptor<WorkoutExercise>(predicate: #Predicate { $0.name == name })
        let all = (try? context.fetch(d)) ?? []
        return all.filter { $0.workout != nil && $0.workout !== workout }
            .max { ($0.workout?.date ?? .distantPast) < ($1.workout?.date ?? .distantPast) }?
            .sortedSets ?? []
    }
}

@Model
final class WorkoutExercise {
    var name: String
    var order: Int
    var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.exercise)
    var sets: [SetEntry] = []

    init(name: String, order: Int) {
        self.name = name
        self.order = order
    }

    var sortedSets: [SetEntry] { sets.sorted { $0.order < $1.order } }
    var nextSetOrder: Int { (sets.map(\.order).max() ?? -1) + 1 }
}

@Model
final class SetEntry {
    var order: Int
    var reps: Int
    var weight: Double
    var isDone: Bool
    var type: String = SetType.normal.rawValue
    var exercise: WorkoutExercise?

    var setType: SetType {
        get { SetType(rawValue: type) ?? .normal }
        set { type = newValue.rawValue }
    }

    init(order: Int, reps: Int = 8, weight: Double = 0, isDone: Bool = false, type: SetType = .normal) {
        self.type = type.rawValue
        self.order = order
        self.reps = reps
        self.weight = weight
        self.isDone = isDone
    }
}

enum Meal: String, CaseIterable, Identifiable {
    case breakfast = "Colazione", lunch = "Pranzo", dinner = "Cena", snack = "Spuntino"
    var id: String { rawValue }
}

@Model
final class FoodEntry {
    var name: String
    var meal: String
    var date: Date
    var grams: Double
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    init(name: String, meal: Meal, date: Date = .now, grams: Double,
         calories: Double, protein: Double, carbs: Double, fat: Double) {
        self.name = name
        self.meal = meal.rawValue
        self.date = date
        self.grams = grams
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

/// Alimento per 100 g, restituito da un provider di ricerca.
struct FoodItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var brand: String?
    var kcal100: Double
    var protein100: Double
    var carbs100: Double
    var fat100: Double
}

// MARK: - Tipi di serie

enum SetType: String, CaseIterable, Identifiable {
    case normal, warmup, failure, dropset
    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normale"
        case .warmup: "Riscaldamento"
        case .failure: "Cedimento"
        case .dropset: "Drop set"
        }
    }
    /// Lettera mostrata al posto del numero; `nil` per le serie normali (numerate).
    var badge: String? {
        switch self {
        case .normal: nil
        case .warmup: "W"
        case .failure: "F"
        case .dropset: "D"
        }
    }
    /// Il riscaldamento non conta nel volume.
    var countsAsWork: Bool { self != .warmup }
}

/// Etichette delle serie: numeri progressivi per le normali, lettera per le altre.
func setLabels(_ types: [SetType]) -> [String] {
    var n = 0
    return types.map { t in
        if let b = t.badge { return b }
        n += 1
        return "\(n)"
    }
}

// MARK: - Libreria esercizi e routine

@Model
final class Exercise {
    @Attribute(.unique) var key: String
    var name: String
    var muscle: String
    var secondary: String
    var equipment: String
    var category: String
    var level: String
    var instructions: String
    var isCustom: Bool
    /// Nomi alternativi (italiano, sinonimi) usati solo per la ricerca.
    var aliases: String = ""
    /// Origine dei dati: "free-exercise-db", "wger" o "custom".
    var source: String = "free-exercise-db"

    init(key: String, name: String, muscle: String = "", secondary: String = "", equipment: String = "",
         category: String = "", level: String = "", instructions: String = "", isCustom: Bool = false,
         aliases: String = "", source: String = "free-exercise-db") {
        self.key = key; self.name = name; self.muscle = muscle; self.secondary = secondary
        self.equipment = equipment; self.category = category; self.level = level
        self.instructions = instructions; self.isCustom = isCustom
        self.aliases = aliases; self.source = isCustom ? "custom" : source
    }
}

@Model
final class Routine {
    var name: String
    var notes: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var items: [RoutineExercise] = []

    init(name: String, notes: String = "", createdAt: Date = .now) {
        self.name = name; self.notes = notes; self.createdAt = createdAt
    }

    var sortedItems: [RoutineExercise] { items.sorted { $0.order < $1.order } }
    var nextItemOrder: Int { (items.map(\.order).max() ?? -1) + 1 }

    /// Crea un allenamento dalla routine. Se nella routine il peso è 0, usa quello dell'ultima volta.
    func makeWorkout(in context: ModelContext) -> Workout {
        let w = Workout(name: name)
        context.insert(w)
        for (n, item) in sortedItems.enumerated() {
            let ex = WorkoutExercise(name: item.exerciseName, order: n)
            context.insert(ex)
            w.exercises.append(ex)
            let previous = Workout.previousSets(for: item.exerciseName, excluding: w, in: context)
            for (i, s) in item.sortedSets.enumerated() {
                let weight = s.weight > 0 ? s.weight : (previous.indices.contains(i) ? previous[i].weight : 0)
                let set = SetEntry(order: i, reps: s.reps, weight: weight, type: s.setType)
                context.insert(set)
                ex.sets.append(set)
            }
        }
        return w
    }
}

@Model
final class RoutineExercise {
    var exerciseName: String
    var order: Int
    var routine: Routine?
    @Relationship(deleteRule: .cascade, inverse: \RoutineSet.item)
    var sets: [RoutineSet] = []

    init(exerciseName: String, order: Int) {
        self.exerciseName = exerciseName; self.order = order
    }

    var sortedSets: [RoutineSet] { sets.sorted { $0.order < $1.order } }
    var nextSetOrder: Int { (sets.map(\.order).max() ?? -1) + 1 }
}

@Model
final class RoutineSet {
    var order: Int
    var type: String = SetType.normal.rawValue
    var reps: Int
    var weight: Double
    var item: RoutineExercise?

    var setType: SetType {
        get { SetType(rawValue: type) ?? .normal }
        set { type = newValue.rawValue }
    }

    init(order: Int, type: SetType = .normal, reps: Int = 10, weight: Double = 0) {
        self.order = order; self.type = type.rawValue; self.reps = reps; self.weight = weight
    }
}
