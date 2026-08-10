import Foundation
import UIKit
import Vision

/// Estima tipo de alimento e macros a partir da foto (on-device). A imagem não é persistida.
enum MealPhotoAnalysisEngine {
    struct Estimate: Equatable {
        var foodLabel: String
        var proteinGrams: Int
        var carbsGrams: Int
        var fatGrams: Int
        var calories: Int
        var confidence: Double
        var note: String
        /// Alimentos individuais reconhecidos na foto (quando há mais de um).
        var detectedFoods: [String]
    }

    enum AnalysisError: LocalizedError {
        case invalidImage
        case visionFailed

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "Não foi possível ler a foto da refeição."
            case .visionFailed: return "Falha ao analisar a imagem. Tente outra foto com boa iluminação."
            }
        }
    }

    static func analyze(image: UIImage) async throws -> Estimate {
        guard let cgImage = normalizedCGImage(from: image) else {
            throw AnalysisError.invalidImage
        }

        async let classificationsTask = classify(cgImage: cgImage)
        async let ocrTask = recognizeText(cgImage: cgImage)

        let classifications = try await classificationsTask
        let ocrText = (try? await ocrTask) ?? ""

        var hits: [CatalogHit] = []
        hits.append(contentsOf: matchAllInText(ocrText, sourceBoost: 0.85))
        hits.append(contentsOf: matchAllClassifications(classifications))

        let merged = mergeHits(hits)
        if merged.isEmpty {
            return genericFallback(classifications: classifications, ocrText: ocrText)
        }

        return composeEstimate(from: merged, ocrBoosted: !ocrText.isEmpty)
    }

    // MARK: - Vision

    private static func classify(cgImage: CGImage) async throws -> [VNClassificationObservation] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    continuation.resume(returning: request.results ?? [])
                } catch {
                    continuation.resume(throwing: AnalysisError.visionFailed)
                }
            }
        }
    }

    private static func recognizeText(cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["pt-BR", "en-US"]
                request.minimumTextHeight = 0.02
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let text = (request.results ?? [])
                        .compactMap { $0.topCandidates(2).first?.string }
                        .joined(separator: " ")
                        .lowercased()
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func normalizedCGImage(from image: UIImage) -> CGImage? {
        // Reduz imagens muito grandes para acelerar Vision sem perder comida no enquadramento.
        let maxSide: CGFloat = 1280
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image.cgImage }

        let longest = max(size.width, size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.cgImage
    }

    // MARK: - Matching

    struct CatalogHit: Equatable {
        let item: FoodMacroItem
        let confidence: Double
        let source: String
    }

    static func matchAllInText(_ text: String, sourceBoost: Double) -> [CatalogHit] {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return [] }
        var hits: [CatalogHit] = []
        for item in FoodMacroCatalog.items {
            guard let score = bestKeywordScore(item: item, in: normalized) else { continue }
            hits.append(
                CatalogHit(
                    item: item,
                    confidence: min(score * sourceBoost * item.matchWeight, 0.96),
                    source: "ocr"
                )
            )
        }
        return hits
    }

    static func matchAllClassifications(_ observations: [VNClassificationObservation]) -> [CatalogHit] {
        var hits: [CatalogHit] = []
        for observation in observations.prefix(20) {
            let identifier = normalize(observation.identifier)
            let tokens = identifier
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: ",")
                .map { normalize(String($0)) }

            var candidateTokens = tokens
            candidateTokens.append(identifier)
            // Também tenta o último segmento de taxonomias "food › dish › pizza"
            if let last = identifier.split(whereSeparator: { $0 == ">" || $0 == "/" || $0 == "|" }).last {
                candidateTokens.append(normalize(String(last)))
            }

            for token in Set(candidateTokens) where token.count >= 3 {
                if let item = FoodMacroCatalog.item(matching: token)
                    ?? FoodMacroCatalog.item(matchingVisionLabel: token) {
                    let score = Double(observation.confidence) * item.matchWeight
                    guard score >= 0.04 else { continue }
                    hits.append(
                        CatalogHit(
                            item: item,
                            confidence: min(max(score, 0.12), 0.94),
                            source: "vision"
                        )
                    )
                }
            }
        }
        return hits
    }

    /// Agrupa pelo nome do alimento e fica com a maior confiança de cada um.
    static func mergeHits(_ hits: [CatalogHit]) -> [CatalogHit] {
        var bestByName: [String: CatalogHit] = [:]
        for hit in hits {
            let key = hit.item.displayName
            if let existing = bestByName[key] {
                if hit.confidence > existing.confidence {
                    bestByName[key] = hit
                }
            } else {
                bestByName[key] = hit
            }
        }

        // Remove genéricos fracos se já houver alimentos específicos.
        let specific = bestByName.values.filter { !$0.item.isGeneric }
        let pool = specific.isEmpty ? Array(bestByName.values) : specific

        return pool
            .sorted { $0.confidence > $1.confidence }
            .prefix(4)
            .map { $0 }
    }

    static func composeEstimate(from hits: [CatalogHit], ocrBoosted: Bool) -> Estimate {
        let foods = hits.map(\.item.displayName)
        let protein = hits.reduce(0) { $0 + $1.item.proteinGrams }
        let carbs = hits.reduce(0) { $0 + $1.item.carbsGrams }
        let fat = hits.reduce(0) { $0 + $1.item.fatGrams }
        // Em pratos compostos, macros somados tendem a exagerar — aplica fator leve.
        let scale = hits.count >= 3 ? 0.75 : (hits.count == 2 ? 0.85 : 1.0)
        let p = Int((Double(protein) * scale).rounded())
        let c = Int((Double(carbs) * scale).rounded())
        let f = Int((Double(fat) * scale).rounded())
        let confidence = min(hits.map(\.confidence).reduce(0, +) / Double(hits.count) + (ocrBoosted ? 0.05 : 0), 0.97)

        let label: String
        if foods.count == 1 {
            label = foods[0]
        } else if foods.count == 2 {
            label = "\(foods[0]) e \(foods[1])"
        } else {
            let head = foods.dropLast().joined(separator: ", ")
            label = "\(head) e \(foods.last!)"
        }

        let sources = Set(hits.map(\.source))
        let note: String
        if sources.contains("ocr"), sources.contains("vision") {
            note = "Identifiquei: \(label). Combinei visão + texto da embalagem/prato — ajuste a porção se precisar."
        } else if sources.contains("ocr") {
            note = "Identifiquei pelo texto: \(label). Macros de porção típica — ajuste se a quantidade for diferente."
        } else if foods.count > 1 {
            note = "Detectei vários alimentos no prato: \(label). Macros somados (porção típica)."
        } else {
            note = "Alimento identificado: \(label). Estimativa visual da porção típica — ajuste se precisar."
        }

        return Estimate(
            foodLabel: label,
            proteinGrams: p,
            carbsGrams: c,
            fatGrams: f,
            calories: MealPhotoAnalysisEntry.estimatedCalories(protein: p, carbs: c, fat: f),
            confidence: confidence,
            note: note,
            detectedFoods: foods
        )
    }

    private static func genericFallback(
        classifications: [VNClassificationObservation],
        ocrText: String
    ) -> Estimate {
        let topLabels = classifications.prefix(3).map(\.identifier).joined(separator: ", ")
        var note = "Não reconheci o prato com precisão. Ajuste o alimento e os macros abaixo."
        if !topLabels.isEmpty {
            note += " Pistas da câmera: \(topLabels)."
        }
        if !ocrText.isEmpty {
            note += " Texto lido: \(ocrText.prefix(80))."
        }
        return Estimate(
            foodLabel: "Refeição mista (estimativa)",
            proteinGrams: 28,
            carbsGrams: 45,
            fatGrams: 15,
            calories: MealPhotoAnalysisEntry.estimatedCalories(protein: 28, carbs: 45, fat: 15),
            confidence: 0.18,
            note: note,
            detectedFoods: ["Refeição mista"]
        )
    }

    private static func bestKeywordScore(item: FoodMacroItem, in normalizedText: String) -> Double? {
        var best: Double?
        for keyword in item.keywords {
            let key = normalize(keyword)
            guard key.count >= 3, normalizedText.contains(key) else { continue }
            // Palavras mais longas / específicas pontuam mais.
            let lengthBonus = min(Double(key.count) / 24.0, 0.25)
            let score = 0.72 + lengthBonus
            if best == nil || score > best! { best = score }
        }
        return best
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Catálogo local (porção típica + sinônimos Vision)

struct FoodMacroItem: Equatable {
    let displayName: String
    let keywords: [String]
    /// Rótulos comuns do classificador Vision / ImageNet.
    let visionLabels: [String]
    let proteinGrams: Int
    let carbsGrams: Int
    let fatGrams: Int
    let matchWeight: Double
    let isGeneric: Bool

    init(
        displayName: String,
        keywords: [String],
        visionLabels: [String] = [],
        proteinGrams: Int,
        carbsGrams: Int,
        fatGrams: Int,
        matchWeight: Double,
        isGeneric: Bool = false
    ) {
        self.displayName = displayName
        self.keywords = keywords
        self.visionLabels = visionLabels
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.matchWeight = matchWeight
        self.isGeneric = isGeneric
    }
}

enum FoodMacroCatalog {
    static let items: [FoodMacroItem] = [
        FoodMacroItem(
            displayName: "Frango grelhado",
            keywords: ["frango", "peito de frango", "chicken", "grilled chicken", "roast chicken"],
            visionLabels: ["chicken", "roast chicken", "hen", "poultry"],
            proteinGrams: 42, carbsGrams: 2, fatGrams: 8, matchWeight: 1.0
        ),
        FoodMacroItem(
            displayName: "Carne bovina",
            keywords: ["carne", "bife", "picanha", "alcatra", "steak", "beef", "meat"],
            visionLabels: ["steak", "meat loaf", "filet", "ribeye", "beef"],
            proteinGrams: 38, carbsGrams: 0, fatGrams: 18, matchWeight: 1.0
        ),
        FoodMacroItem(
            displayName: "Peixe",
            keywords: ["peixe", "salmao", "salmão", "tilapia", "tilápia", "fish", "salmon", "tuna", "atum"],
            visionLabels: ["salmon", "fish", "tuna", "seafood"],
            proteinGrams: 34, carbsGrams: 0, fatGrams: 12, matchWeight: 1.0
        ),
        FoodMacroItem(
            displayName: "Ovos",
            keywords: ["ovo", "ovos", "omelete", "egg", "omelet", "omelette", "scrambled"],
            visionLabels: ["egg", "omelet", "scrambled eggs"],
            proteinGrams: 18, carbsGrams: 2, fatGrams: 14, matchWeight: 0.95
        ),
        FoodMacroItem(
            displayName: "Arroz e feijão",
            keywords: ["arroz e feijao", "arroz e feijão", "arroz com feijao", "rice and beans"],
            visionLabels: [],
            proteinGrams: 14, carbsGrams: 55, fatGrams: 6, matchWeight: 1.0
        ),
        FoodMacroItem(
            displayName: "Arroz",
            keywords: ["arroz", "arroz branco", "arroz integral", "white rice", "brown rice"],
            visionLabels: ["rice", "white rice", "fried rice"],
            proteinGrams: 4, carbsGrams: 45, fatGrams: 1, matchWeight: 0.9
        ),
        FoodMacroItem(
            displayName: "Feijão",
            keywords: ["feijao", "feijão", "feijoada", "black bean", "beans"],
            visionLabels: ["bean", "black bean", "soup"],
            proteinGrams: 12, carbsGrams: 28, fatGrams: 1, matchWeight: 0.9
        ),
        FoodMacroItem(
            displayName: "Batata doce",
            keywords: ["batata doce", "batata-doce", "sweet potato", "yam"],
            visionLabels: ["sweet potato"],
            proteinGrams: 3, carbsGrams: 36, fatGrams: 0, matchWeight: 0.95
        ),
        FoodMacroItem(
            displayName: "Batata",
            keywords: ["batata", "batata frita", "pure", "purê", "potato", "french fries", "fries", "mashed"],
            visionLabels: ["potato", "french fries", "mashed potato"],
            proteinGrams: 4, carbsGrams: 40, fatGrams: 10, matchWeight: 0.88
        ),
        FoodMacroItem(
            displayName: "Macarrão",
            keywords: ["macarrao", "macarrão", "massa", "espaguete", "lasanha", "pasta", "spaghetti", "lasagna", "noodle"],
            visionLabels: ["carbonara", "spaghetti", "pasta", "lasagna", "ramen"],
            proteinGrams: 12, carbsGrams: 60, fatGrams: 6, matchWeight: 0.95
        ),
        FoodMacroItem(
            displayName: "Salada",
            keywords: ["salada", "alface", "rúcula", "rucula", "salad", "lettuce", "greens"],
            visionLabels: ["salad", "lettuce", "guacamole", "vegetable"],
            proteinGrams: 4, carbsGrams: 10, fatGrams: 8, matchWeight: 0.82
        ),
        FoodMacroItem(
            displayName: "Brócolis",
            keywords: ["brocolis", "brócolis", "broccoli"],
            visionLabels: ["broccoli", "cauliflower"],
            proteinGrams: 4, carbsGrams: 8, fatGrams: 0, matchWeight: 0.9
        ),
        FoodMacroItem(
            displayName: "Sanduíche",
            keywords: ["sanduiche", "sanduíche", "hamburguer", "hambúrguer", "burger", "hamburger", "sandwich", "hot dog"],
            visionLabels: ["cheeseburger", "hamburger", "hotdog", "sandwich", "bagel"],
            proteinGrams: 24, carbsGrams: 38, fatGrams: 18, matchWeight: 0.95
        ),
        FoodMacroItem(
            displayName: "Pizza",
            keywords: ["pizza"],
            visionLabels: ["pizza", "pepperoni pizza"],
            proteinGrams: 18, carbsGrams: 48, fatGrams: 16, matchWeight: 1.0
        ),
        FoodMacroItem(
            displayName: "Sushi",
            keywords: ["sushi", "sashimi", "temaki", "nigiri", "uramaki"],
            visionLabels: ["sushi", "sashimi"],
            proteinGrams: 22, carbsGrams: 40, fatGrams: 6, matchWeight: 1.0
        ),
        FoodMacroItem(
            displayName: "Açaí",
            keywords: ["acai", "açaí", "acai bowl"],
            visionLabels: [],
            proteinGrams: 6, carbsGrams: 55, fatGrams: 10, matchWeight: 1.0
        ),
        FoodMacroItem(
            displayName: "Iogurte",
            keywords: ["iogurte", "yogurt", "yoghurt", "grego"],
            visionLabels: ["yogurt", "ice cream", "custard"],
            proteinGrams: 12, carbsGrams: 18, fatGrams: 4, matchWeight: 0.9
        ),
        FoodMacroItem(
            displayName: "Aveia com frutas",
            keywords: ["aveia", "granola", "oatmeal", "cereal", "mingau"],
            visionLabels: ["cereal", "granola"],
            proteinGrams: 10, carbsGrams: 42, fatGrams: 8, matchWeight: 0.9
        ),
        FoodMacroItem(
            displayName: "Banana",
            keywords: ["banana"],
            visionLabels: ["banana"],
            proteinGrams: 1, carbsGrams: 27, fatGrams: 0, matchWeight: 1.0
        ),
        FoodMacroItem(
            displayName: "Maçã",
            keywords: ["maca", "maçã", "apple"],
            visionLabels: ["apple", "granny smith"],
            proteinGrams: 0, carbsGrams: 25, fatGrams: 0, matchWeight: 1.0
        ),
        FoodMacroItem(
            displayName: "Laranja",
            keywords: ["laranja", "orange"],
            visionLabels: ["orange", "lemon"],
            proteinGrams: 1, carbsGrams: 18, fatGrams: 0, matchWeight: 0.95
        ),
        FoodMacroItem(
            displayName: "Fruta",
            keywords: ["fruta", "fruit", "morango", "strawberry", "uva", "grape", "manga", "mango", "mamao", "mamão", "abacate", "avocado"],
            visionLabels: ["strawberry", "grape", "mango", "pineapple", "fruit"],
            proteinGrams: 1, carbsGrams: 22, fatGrams: 1, matchWeight: 0.75
        ),
        FoodMacroItem(
            displayName: "Whey / shake",
            keywords: ["whey", "shake", "smoothie", "proteina", "proteína", "protein shake"],
            visionLabels: ["smoothie", "milkshake", "coffee mug"],
            proteinGrams: 25, carbsGrams: 8, fatGrams: 2, matchWeight: 0.88
        ),
        FoodMacroItem(
            displayName: "Pão",
            keywords: ["pao", "pão", "pao frances", "toast", "bread", "torrada"],
            visionLabels: ["bagel", "pretzel", "bakery", "bread loaf", "french loaf"],
            proteinGrams: 8, carbsGrams: 40, fatGrams: 4, matchWeight: 0.85
        ),
        FoodMacroItem(
            displayName: "Queijo",
            keywords: ["queijo", "cheese", "mussarela", "muçarela", "cottage"],
            visionLabels: ["cheese"],
            proteinGrams: 14, carbsGrams: 2, fatGrams: 16, matchWeight: 0.85
        ),
        FoodMacroItem(
            displayName: "Omelete / café da manhã",
            keywords: ["cafe da manha", "café da manhã", "breakfast", "pancake", "waffle", "tapioca"],
            visionLabels: ["pancake", "waffle", "burrito"],
            proteinGrams: 18, carbsGrams: 40, fatGrams: 14, matchWeight: 0.72
        ),
        FoodMacroItem(
            displayName: "Sopa",
            keywords: ["sopa", "caldo", "soup", "broth"],
            visionLabels: ["soup", "hot pot", "consomme"],
            proteinGrams: 12, carbsGrams: 20, fatGrams: 6, matchWeight: 0.85
        ),
        FoodMacroItem(
            displayName: "Tacos / mexicano",
            keywords: ["taco", "burrito", "mexican", "nachos"],
            visionLabels: ["taco", "burrito", "guacamole"],
            proteinGrams: 20, carbsGrams: 35, fatGrams: 16, matchWeight: 0.9
        ),
        FoodMacroItem(
            displayName: "Prato feito",
            keywords: ["marmita", "prato feito", "pf", "almoço", "jantar", "meal", "dinner", "lunch", "plate"],
            visionLabels: ["plate", "restaurant", "tray"],
            proteinGrams: 35, carbsGrams: 50, fatGrams: 16, matchWeight: 0.45,
            isGeneric: true
        ),
    ]

    static func item(matching token: String) -> FoodMacroItem? {
        let normalized = normalize(token)
        guard normalized.count >= 3 else { return nil }

        // Preferência por keyword exata / contida mais longa.
        var best: (FoodMacroItem, Int)?
        for item in items {
            for keyword in item.keywords {
                let key = normalize(keyword)
                guard key.count >= 3 else { continue }
                if normalized == key || normalized.contains(key) || key.contains(normalized) {
                    let score = key.count
                    if best == nil || score > best!.1 {
                        best = (item, score)
                    }
                }
            }
        }
        return best?.0
    }

    static func item(matchingVisionLabel label: String) -> FoodMacroItem? {
        let normalized = normalize(label)
        guard normalized.count >= 3 else { return nil }
        var best: (FoodMacroItem, Int)?
        for item in items {
            for vision in item.visionLabels {
                let key = normalize(vision)
                guard key.count >= 3 else { continue }
                if normalized == key || normalized.contains(key) || key.contains(normalized) {
                    let score = key.count
                    if best == nil || score > best!.1 {
                        best = (item, score)
                    }
                }
            }
        }
        return best?.0
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
