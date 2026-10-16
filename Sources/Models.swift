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

    /// Volume totale = somma(peso × ripetizioni) sulle serie completate.
    var totalVolume: Double {
        exercises.flatMap(\.sets).filter(\.isDone).reduce(0) { $0 + $1.weight * Double($1.reps) }
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
}

@Model
final class SetEntry {
    var order: Int
    var reps: Int
    var weight: Double
    var isDone: Bool
    var exercise: WorkoutExercise?

    init(order: Int, reps: Int = 8, weight: Double = 0, isDone: Bool = false) {
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
