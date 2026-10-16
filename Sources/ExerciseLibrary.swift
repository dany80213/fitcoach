import Foundation
import SwiftData

/// Importa e tiene aggiornata la libreria esercizi da free-exercise-db
/// (https://github.com/yuhonas/free-exercise-db, pubblico, ~870 esercizi, in inglese).
enum ExerciseLibrary {
    static let url = URL(string: "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json")!
    private static let lastSyncKey = "exerciseSyncDate"
    private static let maxAge: TimeInterval = 7 * 24 * 3600

    private struct Remote: Decodable {
        let id: String
        let name: String
        let level: String?
        let equipment: String?
        let category: String?
        let primaryMuscles: [String]
        let secondaryMuscles: [String]
        let instructions: [String]
    }

    /// Scarica l'elenco e aggiorna/inserisce gli esercizi. Gli esercizi personalizzati non vengono toccati.
    @MainActor @discardableResult
    static func sync(in context: ModelContext) async throws -> Int {
        let (data, resp) = try await URLSession.shared.data(from: url)
        if let code = (resp as? HTTPURLResponse)?.statusCode, code != 200 {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Libreria esercizi non raggiungibile (HTTP \(code))."])
        }
        let remote = try JSONDecoder().decode([Remote].self, from: data)
        var byKey = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Exercise>()).map { ($0.key, $0) })
        for r in remote {
            let muscle = r.primaryMuscles.first ?? ""
            let secondary = r.secondaryMuscles.joined(separator: ", ")
            let steps = r.instructions.joined(separator: "\n")
            if let e = byKey[r.id] {
                e.name = r.name; e.muscle = muscle; e.secondary = secondary
                e.equipment = r.equipment ?? ""; e.category = r.category ?? ""
                e.level = r.level ?? ""; e.instructions = steps
            } else {
                let e = Exercise(key: r.id, name: r.name, muscle: muscle, secondary: secondary,
                                 equipment: r.equipment ?? "", category: r.category ?? "",
                                 level: r.level ?? "", instructions: steps)
                context.insert(e)
                byKey[r.id] = e
            }
        }
        try context.save()
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: lastSyncKey)
        return remote.count
    }

    /// Sincronizza all'avvio se la libreria è vuota o più vecchia di 7 giorni. Gli errori di rete sono ignorati.
    @MainActor
    static func autoSync(in context: ModelContext) async {
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        let last = UserDefaults.standard.double(forKey: lastSyncKey)
        guard count == 0 || Date.now.timeIntervalSince1970 - last > maxAge else { return }
        _ = try? await sync(in: context)
    }
}

/// Nomi dei muscoli in italiano (il dataset è in inglese).
enum Muscle {
    private static let it: [String: String] = [
        "abdominals": "Addominali", "abductors": "Abduttori", "adductors": "Adduttori", "biceps": "Bicipiti",
        "calves": "Polpacci", "chest": "Petto", "forearms": "Avambracci", "glutes": "Glutei",
        "hamstrings": "Femorali", "lats": "Dorsali", "lower back": "Lombari", "middle back": "Schiena",
        "neck": "Collo", "quadriceps": "Quadricipiti", "shoulders": "Spalle", "traps": "Trapezi", "triceps": "Tricipiti",
    ]
    static func label(_ key: String) -> String { it[key] ?? key.capitalized }
}
