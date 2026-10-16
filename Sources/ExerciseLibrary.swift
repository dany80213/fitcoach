import Foundation
import SwiftData

/// Importa e tiene aggiornata la libreria esercizi unendo due fonti pubbliche:
/// - free-exercise-db (https://github.com/yuhonas/free-exercise-db, pubblico, ~870 esercizi)
/// - wger (https://wger.de, CC-BY-SA 3.0, ~930 esercizi, con alcune traduzioni italiane)
/// Gli esercizi con lo stesso nome (ignorando ordine delle parole, plurali, "fly/flye") vengono uniti.
enum ExerciseLibrary {
    static let freeURL = URL(string: "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json")!
    static let wgerURL = URL(string: "https://wger.de/api/v2/exerciseinfo/?limit=1000")!
    private static let wgerEnglish = 2, wgerItalian = 13
    private static let lastSyncKey = "exerciseSyncDate"
    /// Da incrementare quando cambiano le fonti o la mappatura: forza una risincronizzazione al prossimo avvio.
    private static let libraryVersion = 3
    private static let versionKey = "exerciseLibraryVersion"
    private static let maxAge: TimeInterval = 7 * 24 * 3600

    /// Esercizio normalizzato, indipendente dalla fonte.
    struct Item: Sendable {
        var key: String, name: String, muscle: String, secondary: String
        var equipment: String, category: String, level: String, instructions: String
        var aliases: [String], source: String
    }

    // MARK: Sync

    /// Scarica le fonti e aggiorna/inserisce gli esercizi. Gli esercizi personalizzati non vengono toccati.
    /// Fallisce solo se *nessuna* fonte risponde; restituisce il numero di esercizi in libreria.
    @MainActor @discardableResult
    static func sync(in context: ModelContext) async throws -> Int {
        async let free = Task.detached { try await fetchFree() }.result
        async let wger = Task.detached { try await fetchWger() }.result
        let (freeResult, wgerResult) = await (free, wger)
        var items: [Item] = []
        var firstError: Error?
        for r in [freeResult, wgerResult] {
            switch r {
            case .success(let list): items += list
            case .failure(let e): firstError = firstError ?? e
            }
        }
        if items.isEmpty { throw firstError ?? URLError(.cannotLoadFromNetwork) }

        let existing = try context.fetch(FetchDescriptor<Exercise>())
        var byKey = Dictionary(existing.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        var byName: [String: Exercise] = [:]
        for e in existing where !e.isCustom { byName[normalize(e.name)] = e }

        for item in items {
            let norm = normalize(item.name)
            // Stesso key → aggiorna. Altrimenti, stesso nome di un esercizio di un'altra fonte → unisci gli alias.
            if let e = byKey[item.key] {
                apply(item, to: e)
            } else if let e = byName[norm], !e.isCustom {
                e.aliases = mergeAliases(e.aliases, item.aliases + [item.name], excluding: e.name)
                if e.muscle.isEmpty { e.muscle = item.muscle }
                if e.equipment.isEmpty { e.equipment = item.equipment }
            } else {
                let e = Exercise(key: item.key, name: item.name, muscle: item.muscle, secondary: item.secondary,
                                 equipment: item.equipment, category: item.category, level: item.level,
                                 instructions: item.instructions, aliases: item.aliases.joined(separator: ", "),
                                 source: item.source)
                context.insert(e)
                byKey[item.key] = e
                byName[norm] = e
            }
        }
        try context.save()
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: lastSyncKey)
        UserDefaults.standard.set(libraryVersion, forKey: versionKey)
        return try context.fetchCount(FetchDescriptor<Exercise>())
    }

    /// Sincronizza all'avvio se la libreria è vuota o più vecchia di 7 giorni. Gli errori di rete sono ignorati.
    @MainActor
    static func autoSync(in context: ModelContext) async {
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        let last = UserDefaults.standard.double(forKey: lastSyncKey)
        let outdated = UserDefaults.standard.integer(forKey: versionKey) < libraryVersion
        guard count == 0 || outdated || Date.now.timeIntervalSince1970 - last > maxAge else { return }
        _ = try? await sync(in: context)
    }

    private static func apply(_ i: Item, to e: Exercise) {
        e.name = i.name; e.muscle = i.muscle; e.secondary = i.secondary
        e.equipment = i.equipment; e.category = i.category; e.level = i.level
        e.instructions = i.instructions; e.source = i.source
        e.aliases = mergeAliases(e.aliases, i.aliases, excluding: e.name)
    }

    private static func mergeAliases(_ current: String, _ new: [String], excluding name: String) -> String {
        var seen: Set<String> = [name.lowercased()], out: [String] = []
        for a in current.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) + new {
            let t = a.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty, seen.insert(t.lowercased()).inserted { out.append(t) }
        }
        return out.joined(separator: ", ")
    }

    /// Chiave di confronto: minuscolo, senza accenti/punteggiatura, plurali e "flye/flyes" → "fly", parole ordinate.
    static func normalize(_ s: String) -> String {
        let words = s.lowercased().folding(options: .diacriticInsensitive, locale: nil)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { w -> String in
                var w = String(w)
                if w == "flye" || w == "flyes" || w == "flies" { return "fly" }
                if w.count > 3, w.hasSuffix("s") { w.removeLast() }
                return w
            }
            .filter { !["with", "the", "a", "on", "of"].contains($0) }
        return words.sorted().joined(separator: " ")
    }

    // MARK: free-exercise-db

    private struct FreeRemote: Decodable {
        let id: String, name: String
        let level: String?, equipment: String?, category: String?
        let primaryMuscles: [String], secondaryMuscles: [String], instructions: [String]
    }

    private static func fetchFree() async throws -> [Item] {
        let (data, resp) = try await URLSession.shared.data(from: freeURL)
        try check(resp, "free-exercise-db")
        return try JSONDecoder().decode([FreeRemote].self, from: data).map { r in
            Item(key: r.id, name: r.name, muscle: r.primaryMuscles.first ?? "",
                 secondary: r.secondaryMuscles.joined(separator: ", "),
                 equipment: r.equipment ?? "", category: r.category ?? "", level: r.level ?? "",
                 instructions: r.instructions.joined(separator: "\n"), aliases: [], source: "free-exercise-db")
        }
    }

    // MARK: wger

    private struct WgerList: Decodable { let results: [WgerExercise] }
    private struct WgerExercise: Decodable {
        let uuid: String
        let category: Named?
        let muscles: [WgerMuscle]
        let musclesSecondary: [WgerMuscle]
        let equipment: [Named]
        let translations: [Translation]
    }
    private struct Named: Decodable { let name: String }
    private struct WgerMuscle: Decodable { let name: String; let nameEn: String? }
    private struct Translation: Decodable { let name: String; let description: String?; let language: Int }

    private static func fetchWger() async throws -> [Item] {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        let (data, resp) = try await URLSession.shared.data(from: wgerURL)
        try check(resp, "wger")
        return try d.decode(WgerList.self, from: data).results.compactMap { e in
            guard let en = e.translations.first(where: { $0.language == wgerEnglish }) else { return nil }
            var aliases: [String] = []
            if let it = e.translations.first(where: { $0.language == wgerItalian }), it.name != en.name { aliases.append(it.name) }
            let muscle = e.muscles.first.map(muscleKey) ?? categoryMuscle(e.category?.name)
            return Item(key: "wger-\(e.uuid)", name: en.name, muscle: muscle,
                        secondary: e.musclesSecondary.map(muscleKey).joined(separator: ", "),
                        equipment: e.equipment.first.map { equipmentKey($0.name) } ?? guessEquipment(en.name),
                        category: e.category?.name.lowercased() ?? "", level: "",
                        instructions: stripHTML(en.description ?? ""), aliases: aliases, source: "wger")
        }
    }

    private static func check(_ resp: URLResponse, _ source: String) throws {
        if let code = (resp as? HTTPURLResponse)?.statusCode, code != 200 {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "\(source) non raggiungibile (HTTP \(code))."])
        }
    }

    /// Porta i muscoli di wger nel vocabolario di free-exercise-db (così il filtro per muscolo è unico).
    private static func muscleKey(_ m: WgerMuscle) -> String {
        switch (m.nameEn ?? m.name).lowercased() {
        case "chest": "chest"
        case "quads": "quadriceps"
        case "hamstrings": "hamstrings"
        case "glutes": "glutes"
        case "biceps", "brachialis": "biceps"
        case "triceps": "triceps"
        case "shoulders": "shoulders"
        case "lats": "lats"
        case "abs", "obliquus externus abdominis": "abdominals"
        case "calves", "soleus": "calves"
        case "trapezius": "traps"
        case "serratus anterior": "chest"
        default: (m.nameEn ?? m.name).lowercased()
        }
    }

    private static func categoryMuscle(_ c: String?) -> String {
        switch c?.lowercased() {
        case "legs": "quadriceps"
        case "back": "lats"
        case "arms": "biceps"
        case "shoulders": "shoulders"
        case "abs": "abdominals"
        case "chest": "chest"
        case "calves": "calves"
        default: ""
        }
    }

    /// wger non sempre indica l'attrezzo: lo deduciamo dal nome, altrimenti resta vuoto (sconosciuto).
    private static func guessEquipment(_ name: String) -> String {
        let n = name.lowercased()
        if ["machine", "pec deck", "leg press", "hack squat", "smith"].contains(where: n.contains) { return "machine" }
        if n.contains("cable") || n.contains("pulldown") || n.contains("pull down") { return "cable" }
        if n.contains("dumbbell") { return "dumbbell" }
        if n.contains("barbell") { return "barbell" }
        return ""
    }

    private static func equipmentKey(_ n: String) -> String {
        switch n.lowercased() {
        case "none (bodyweight exercise)", "gym mat": "body only"
        case "cable machine": "cable"
        case "sz-bar": "e-z curl bar"
        case "swiss ball": "exercise ball"
        case "resistance band": "bands"
        case "kettlebell": "kettlebells"
        case "bench", "incline bench", "pull-up bar": "other"
        default: n.lowercased()   // barbell, dumbbell
        }
    }

    private static func stripHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
