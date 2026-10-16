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

    var totalSetCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }

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
    /// 0 = nessun superset; esercizi con lo stesso valore (e adiacenti) formano un superset.
    var supersetID: Int = 0
    /// Riposo dopo ogni serie: 0 = predefinito, -1 = nessuno, altrimenti secondi.
    var restSeconds: Int = 0
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
            ex.supersetID = item.supersetID
            ex.restSeconds = item.restSeconds
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
    var supersetID: Int = 0
    var restSeconds: Int = 0
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

// MARK: - Profilo

enum Sex: String, CaseIterable, Identifiable {
    case male, female, other
    var id: String { rawValue }
    var title: String { switch self { case .male: "Uomo"; case .female: "Donna"; case .other: "Non specificato" } }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary, light, moderate, high
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sedentary: "Sedentario"
        case .light: "Leggero (1-3 allenamenti/sett.)"
        case .moderate: "Moderato (3-5 allenamenti/sett.)"
        case .high: "Intenso (6-7 allenamenti/sett.)"
        }
    }
    var factor: Double {
        switch self { case .sedentary: 1.2; case .light: 1.375; case .moderate: 1.55; case .high: 1.725 }
    }
}

enum FitnessGoal: String, CaseIterable, Identifiable {
    case lose, maintain, gain
    var id: String { rawValue }
    var title: String { switch self { case .lose: "Dimagrire"; case .maintain: "Mantenere"; case .gain: "Aumentare massa" } }
    var calorieDelta: Double { switch self { case .lose: -400; case .maintain: 0; case .gain: 300 } }
}

/// Profilo personale dell'utente (un solo record).
@Model
final class Profile {
    var name: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var birthDate: Date = Calendar.current.date(from: DateComponents(year: 1995, month: 1, day: 1)) ?? .now
    var sex: String = Sex.other.rawValue
    var heightCm: Double = 0
    var weightKg: Double = 0
    var targetWeightKg: Double = 0
    var activity: String = ActivityLevel.moderate.rawValue
    var goal: String = FitnessGoal.maintain.rawValue

    init() {}

    var sexValue: Sex { Sex(rawValue: sex) ?? .other }
    var activityLevel: ActivityLevel { ActivityLevel(rawValue: activity) ?? .moderate }
    var fitnessGoal: FitnessGoal { FitnessGoal(rawValue: goal) ?? .maintain }

    var age: Int { Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0 }

    var bmi: Double? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let m = heightCm / 100
        return weightKg / (m * m)
    }

    /// Metabolismo basale (Mifflin-St Jeor).
    var bmr: Double? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch sexValue { case .male: return base + 5; case .female: return base - 161; case .other: return base - 78 }
    }

    /// Fabbisogno giornaliero stimato (BMR × livello di attività).
    var tdee: Double? { bmr.map { $0 * activityLevel.factor } }
    var suggestedCalories: Double? { tdee.map { ($0 + fitnessGoal.calorieDelta).rounded() } }
    var suggestedProtein: Double? {
        weightKg > 0 ? (weightKg * (fitnessGoal == .gain ? 2.0 : 1.8)).rounded() : nil
    }
}

// MARK: - Superset

/// Esercizio che può far parte di un superset (allenamento o routine).
protocol SupersetMember: AnyObject {
    var supersetID: Int { get set }
    var order: Int { get }
}
extension WorkoutExercise: SupersetMember {}
extension RoutineExercise: SupersetMember {}

enum Superset {
    /// Unisce `item` al superset di `previous` (lo crea se `previous` non ne ha uno).
    static func join<T: SupersetMember>(_ item: T, with previous: T, in all: [T]) {
        if previous.supersetID == 0 { previous.supersetID = (all.map(\.supersetID).max() ?? 0) + 1 }
        item.supersetID = previous.supersetID
    }

    /// Toglie `item` dal suo superset; se resta un solo esercizio, scioglie anche quello.
    static func leave<T: SupersetMember>(_ item: T, in all: [T]) {
        let gid = item.supersetID
        item.supersetID = 0
        cleanup(gid, in: all)
    }

    /// Un superset con un solo membro non ha senso: lo scioglie.
    static func cleanup<T: SupersetMember>(_ gid: Int, in all: [T]) {
        guard gid != 0 else { return }
        let members = all.filter { $0.supersetID == gid }
        if members.count == 1 { members[0].supersetID = 0 }
    }

    /// Lettera di ogni superset (A, B, …) in ordine di comparsa.
    static func letters<T: SupersetMember>(_ sorted: [T]) -> [Int: String] {
        var out: [Int: String] = [:]
        for e in sorted where e.supersetID != 0 && out[e.supersetID] == nil {
            out[e.supersetID] = String(UnicodeScalar(UInt8(65 + out.count % 26)))
        }
        return out
    }
}

extension WorkoutExercise {
    /// Secondi di riposo da avviare dopo una serie completata, o `nil` se non serve:
    /// nei superset si riposa solo dopo l'ultimo esercizio del giro.
    func restToStart(in siblings: [WorkoutExercise]) -> Int? {
        if supersetID != 0,
           let last = siblings.filter({ $0.supersetID == supersetID }).max(by: { $0.order < $1.order }),
           last !== self { return nil }
        let seconds = restSeconds == 0 ? RestTimer.defaultSeconds : restSeconds
        return seconds > 0 ? seconds : nil
    }
}
