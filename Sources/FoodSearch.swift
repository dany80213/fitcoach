import Foundation

/// Astrazione sul database alimentare: oggi Open Food Facts,
/// domani un `FatSecretProvider` con le stesse due righe.
protocol FoodSearchProvider {
    func search(_ query: String) async throws -> [FoodItem]
}

struct OpenFoodFactsProvider: FoodSearchProvider {
    private struct Response: Decodable { let hits: [Product] }
    private struct Product: Decodable {
        let product_name: String?
        let brands: [String]?
        let nutriments: [String: LenientDouble]?
    }
    private struct LenientDouble: Decodable {
        let value: Double?
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let d = try? c.decode(Double.self) { value = d }
            else if let s = try? c.decode(String.self) { value = Double(s) }
            else { value = nil }
        }
    }

    func search(_ query: String) async throws -> [FoodItem] {
        var comps = URLComponents(string: "https://search.openfoodfacts.org/search")!
        comps.queryItems = [
            .init(name: "q", value: query),
            .init(name: "page_size", value: "25"),
            .init(name: "fields", value: "product_name,brands,nutriments"),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("FitCoach/0.1 (personal app)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let code = (resp as? HTTPURLResponse)?.statusCode, code != 200 {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Il servizio alimenti non risponde (HTTP \(code)). Riprova tra poco."])
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.hits.compactMap { p in
            guard let name = p.product_name, !name.isEmpty,
                  let n = p.nutriments,
                  let kcal = n["energy-kcal_100g"]?.value else { return nil }
            return FoodItem(
                name: name,
                brand: p.brands?.first?.trimmingCharacters(in: .whitespaces),
                kcal100: kcal,
                protein100: n["proteins_100g"]?.value ?? 0,
                carbs100: n["carbohydrates_100g"]?.value ?? 0,
                fat100: n["fat_100g"]?.value ?? 0)
        }
    }
}
