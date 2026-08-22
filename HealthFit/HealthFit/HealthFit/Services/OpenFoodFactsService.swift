import Foundation

/// Consulta produtos embalados por código de barras (Open Food Facts — gratuito).
enum OpenFoodFactsService {
    struct ProductNutrition: Equatable {
        var name: String
        var barcode: String
        var proteinPer100g: Double
        var carbsPer100g: Double
        var fatPer100g: Double
        var caloriesPer100g: Int?
        var servingGrams: Int?
        var brand: String?
    }

    enum ServiceError: LocalizedError {
        case invalidBarcode
        case notFound
        case networkFailed

        var errorDescription: String? {
            switch self {
            case .invalidBarcode: return "Código de barras inválido."
            case .notFound: return "Produto não encontrado na base Open Food Facts."
            case .networkFailed: return "Não foi possível consultar o produto. Verifique a conexão."
            }
        }
    }

    static func lookup(barcode raw: String) async throws -> ProductNutrition {
        let barcode = sanitizeBarcode(raw)
        guard barcode.count >= 8 else { throw ServiceError.invalidBarcode }

        var request = URLRequest(
            url: URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json")!
        )
        request.timeoutInterval = 12
        request.setValue("HealthFit/1.0 (iOS meal analysis)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ServiceError.networkFailed
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkFailed
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let status = json["status"] as? Int, status == 1,
            let product = json["product"] as? [String: Any]
        else {
            throw ServiceError.notFound
        }

        let nutriments = product["nutriments"] as? [String: Any] ?? [:]
        let name = (product["product_name"] as? String)
            ?? (product["product_name_pt"] as? String)
            ?? (product["generic_name"] as? String)
            ?? "Produto embalado"
        let brand = product["brands"] as? String

        let protein = doubleValue(nutriments["proteins_100g"]) ?? doubleValue(nutriments["proteins"]) ?? 0
        let carbs = doubleValue(nutriments["carbohydrates_100g"]) ?? doubleValue(nutriments["carbohydrates"]) ?? 0
        let fat = doubleValue(nutriments["fat_100g"]) ?? doubleValue(nutriments["fat"]) ?? 0
        let kcal = intValue(nutriments["energy-kcal_100g"]) ?? intValue(nutriments["energy-kcal_100g_computed"])

        var servingGrams: Int?
        if let qty = product["serving_quantity"] as? Double, qty > 0 {
            servingGrams = Int(qty.rounded())
        } else if let qtyStr = product["serving_quantity"] as? String, let qty = Double(qtyStr) {
            servingGrams = Int(qty.rounded())
        } else if let size = product["serving_size"] as? String {
            servingGrams = parseGrams(from: size)
        }

        guard protein + carbs + fat > 0 || kcal != nil else {
            throw ServiceError.notFound
        }

        return ProductNutrition(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            barcode: barcode,
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat,
            caloriesPer100g: kcal,
            servingGrams: servingGrams,
            brand: brand?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    static func sanitizeBarcode(_ raw: String) -> String {
        raw.filter(\.isNumber)
    }

    static func macros(for product: ProductNutrition, grams: Int) -> (protein: Int, carbs: Int, fat: Int, calories: Int) {
        let g = max(1, grams)
        let factor = Double(g) / 100.0
        let p = Int((product.proteinPer100g * factor).rounded())
        let c = Int((product.carbsPer100g * factor).rounded())
        let f = Int((product.fatPer100g * factor).rounded())
        let kcal: Int
        if let per100 = product.caloriesPer100g, per100 > 0 {
            kcal = Int((Double(per100) * factor).rounded())
        } else {
            kcal = MealPhotoAnalysisEntry.estimatedCalories(protein: p, carbs: c, fat: f)
        }
        return (p, c, f, kcal)
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d.rounded()) }
        if let s = value as? String, let d = Double(s.replacingOccurrences(of: ",", with: ".")) {
            return Int(d.rounded())
        }
        return nil
    }

    private static func parseGrams(from serving: String) -> Int? {
        let normalized = serving
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .lowercased()
        if let match = normalized.range(of: #"(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression) {
            let token = String(normalized[match])
            let digits = token.filter { $0.isNumber || $0 == "." }
            if let value = Double(digits) { return Int(value.rounded()) }
        }
        return nil
    }
}
