import Foundation
import SwiftData
import Security

// MARK: - Keychain

enum Keychain {
    private static let account = "anthropic-api-key"
    private static let service = "com.danieleporcaro.fitcoach"

    static func save(_ value: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
        guard !value.isEmpty else { return }
        var add = q
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> String {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service, kSecAttrAccount as String: account,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return "" }
        return String(decoding: d, as: UTF8.self)
    }
}

// MARK: - Contesto

/// Costruisce un riassunto testuale dei dati dell'utente da passare all'agente.
enum ContextBuilder {
    static func build(in context: ModelContext, calorieGoal: Double, proteinGoal: Double, days: Int = 14) -> String {
        let since = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let cal = Calendar.current
        var lines = ["Oggi: \(Date.now.formatted(date: .complete, time: .omitted))",
                     "Obiettivi giornalieri: \(Int(calorieGoal)) kcal, \(Int(proteinGoal)) g proteine"]

        let foods = (try? context.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.date >= since }, sortBy: [SortDescriptor(\.date)]))) ?? []
        lines.append("\n## Alimentazione (ultimi \(days) giorni)")
        for (day, items) in Dictionary(grouping: foods, by: { cal.startOfDay(for: $0.date) }).sorted(by: { $0.key < $1.key }) {
            let k = Int(items.reduce(0) { $0 + $1.calories }), p = Int(items.reduce(0) { $0 + $1.protein })
            let c = Int(items.reduce(0) { $0 + $1.carbs }), f = Int(items.reduce(0) { $0 + $1.fat })
            lines.append("- \(day.formatted(date: .abbreviated, time: .omitted)): \(k) kcal, P\(p) C\(c) G\(f) — " +
                         items.map { "\($0.name) \(Int($0.grams))g" }.joined(separator: ", "))
        }

        let workouts = (try? context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.date >= since }, sortBy: [SortDescriptor(\.date)]))) ?? []
        lines.append("\n## Allenamenti (ultimi \(days) giorni)")
        for w in workouts {
            lines.append("- \(w.date.formatted(date: .abbreviated, time: .omitted)) \(w.name) (volume \(Int(w.totalVolume)) kg)")
            for ex in w.sortedExercises {
                let sets = ex.sortedSets.filter(\.isDone).map { "\($0.setType.badge.map { "[\($0)] " } ?? "")\($0.weight.formatted())kg×\($0.reps)" }.joined(separator: ", ")
                if !sets.isEmpty { lines.append("    \(ex.name): \(sets)") }
            }
        }

        let routines = (try? context.fetch(FetchDescriptor<Routine>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        if !routines.isEmpty {
            lines.append("\n## Routine dell'utente (W=riscaldamento, F=cedimento, D=drop set)")
            for r in routines {
                lines.append("- \(r.name): " + r.sortedItems.map { "\($0.exerciseName) (\($0.sets.count) serie)" }.joined(separator: ", "))
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Client API

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    let role: String   // "user" | "assistant"
    var text: String
}

enum AgentError: LocalizedError {
    case missingKey, api(String)
    var errorDescription: String? {
        switch self {
        case .missingKey: "Inserisci la chiave API Anthropic in Impostazioni."
        case .api(let m): m
        }
    }
}

struct AgentClient {
    static let model = "claude-sonnet-5-5"

    func reply(history: [ChatMessage], dataContext: String) async throws -> String {
        let key = Keychain.load()
        guard !key.isEmpty else { throw AgentError.missingKey }

        let system = """
        Sei il coach personale dell'utente in un'app di allenamento e nutrizione. Rispondi in italiano, \
        in modo breve e concreto. Basati SOLO sui dati qui sotto; se un dato manca, dillo invece di inventarlo. \
        Non dare consigli medici: per questioni di salute suggerisci un professionista.

        <dati_utente>
        \(dataContext)
        </dati_utente>
        """

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": Self.model, "max_tokens": 1024, "system": system,
            "messages": history.map { ["role": $0.role, "content": $0.text] },
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if (resp as? HTTPURLResponse)?.statusCode != 200 {
            let msg = (json["error"] as? [String: Any])?["message"] as? String ?? "Errore API"
            throw AgentError.api(msg)
        }
        let blocks = json["content"] as? [[String: Any]] ?? []
        return blocks.compactMap { $0["text"] as? String }.joined()
    }
}
