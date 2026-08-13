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
        /// `true` quando os macros vieram de tabela nutricional lida por OCR.
        var fromNutritionLabel: Bool
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

        // Prioridade: tabela nutricional impressa (valores reais do rótulo).
        if let labelEstimate = estimateFromNutritionLabel(ocrText) {
            return labelEstimate
        }

        var hits: [CatalogHit] = []
        hits.append(contentsOf: matchAllInText(ocrText, sourceBoost: 0.85))
        hits.append(contentsOf: matchAllClassifications(classifications))

        let merged = mergeHits(hits)
        if merged.isEmpty {
            return genericFallback(classifications: classifications, ocrText: ocrText)
        }

        return composeEstimate(from: merged, ocrBoosted: !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                // Rótulos de embalagem usam tipografia pequena.
                request.minimumTextHeight = 0.011
                if #available(iOS 16.0, *) {
                    request.automaticallyDetectsLanguage = true
                }
                request.customWords = [
                    "proteínas", "proteinas", "carboidratos", "gorduras", "kcal",
                    "calorias", "valor energético", "porção", "frango", "arroz",
                    "feijão", "protein", "carbohydrate", "calories",
                ]
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    // Mantém quebras de linha — ajuda o parser de tabela nutricional.
                    let lines = (request.results ?? []).compactMap { observation -> String? in
                        let candidates = observation.topCandidates(3).map(\.string)
                        return candidates.first
                    }
                    continuation.resume(returning: lines.joined(separator: "\n"))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func normalizedCGImage(from image: UIImage) -> CGImage? {
        // Maior resolução favorece OCR de rótulos sem custo excessivo no Vision.
        let maxSide: CGFloat = 1600
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image.cgImage }

        let longest = max(size.width, size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        // `UIImage.draw` aplica a orientação EXIF corretamente.
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.cgImage
    }

    // MARK: - Nutrition label OCR

    struct NutritionLabelReading: Equatable {
        var calories: Int?
        var proteinGrams: Int?
        var carbsGrams: Int?
        var fatGrams: Int?
        var isPer100g: Bool
        var productHint: String?

        var macroCount: Int {
            [proteinGrams, carbsGrams, fatGrams].compactMap { $0 }.count
        }

        var isUsable: Bool {
            macroCount >= 2 || (calories != nil && macroCount >= 1)
        }
    }

    /// Extrai P/C/G/kcal de texto de tabela nutricional (pt/en).
    static func parseNutritionLabel(from text: String) -> NutritionLabelReading? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.count >= 8 else { return nil }

        let normalized = normalize(raw)
            .replacingOccurrences(of: ",", with: ".")
        let compact = normalized
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        let looksLikeLabel =
            compact.contains("kcal")
            || compact.contains("proteina")
            || compact.contains("protein")
            || compact.contains("carboidrato")
            || compact.contains("carbohydrate")
            || compact.contains("gordura")
            || compact.contains("valor energetico")
            || compact.contains("nutrition facts")
            || compact.contains("informacao nutricional")

        guard looksLikeLabel else { return nil }

        let protein = firstNumber(
            in: compact,
            patterns: [
                #"prote[i]?nas?\D{0,24}(\d+(?:\.\d+)?)\s*g"#,
                #"protein[s]?\D{0,24}(\d+(?:\.\d+)?)\s*g"#,
                #"(\d+(?:\.\d+)?)\s*g\D{0,12}prote[i]?nas?"#,
                #"(\d+(?:\.\d+)?)\s*g\D{0,12}protein"#,
            ]
        )
        let carbs = firstNumber(
            in: compact,
            patterns: [
                #"carboidratos?\D{0,24}(\d+(?:\.\d+)?)\s*g"#,
                #"carbohydrates?\D{0,24}(\d+(?:\.\d+)?)\s*g"#,
                #"total\s+carb(?:ohydrate)?s?\D{0,24}(\d+(?:\.\d+)?)\s*g"#,
                #"carbs?\D{0,16}(\d+(?:\.\d+)?)\s*g"#,
                #"(\d+(?:\.\d+)?)\s*g\D{0,12}carboidratos?"#,
            ]
        )
        // Evita capturar "gorduras saturadas" antes de "gorduras totais" quando possível.
        let fat = firstNumber(
            in: compact,
            patterns: [
                #"gorduras?\s+totais\D{0,24}(\d+(?:\.\d+)?)\s*g"#,
                #"total\s+fat\D{0,24}(\d+(?:\.\d+)?)\s*g"#,
                #"gorduras?\D{0,24}(\d+(?:\.\d+)?)\s*g"#,
                #"fat\D{0,16}(\d+(?:\.\d+)?)\s*g"#,
                #"(\d+(?:\.\d+)?)\s*g\D{0,12}gorduras?\s+totais"#,
            ]
        )
        let calories = firstNumber(
            in: compact,
            patterns: [
                #"(\d+(?:\.\d+)?)\s*kcal"#,
                #"(?:valor\s+energetico|energy|calories?|calorias?)\D{0,40}(\d+(?:\.\d+)?)\s*kcal"#,
                #"calories?\D{0,20}(\d+(?:\.\d+)?)"#,
            ]
        ).map { Int($0.rounded()) }

        let isPer100g =
            compact.contains("por 100 g")
            || compact.contains("por 100g")
            || compact.contains("per 100 g")
            || compact.contains("per 100g")
            || compact.contains("/ 100 g")
            || compact.contains("/100g")
            || compact.range(of: #"porcao\s*[:\-]?\s*100\s*g"#, options: .regularExpression) != nil
            || compact.range(of: #"serving\s*(?:size)?\s*[:\-]?\s*100\s*g"#, options: .regularExpression) != nil

        var reading = NutritionLabelReading(
            calories: calories,
            proteinGrams: protein.map { Int($0.rounded()) },
            carbsGrams: carbs.map { Int($0.rounded()) },
            fatGrams: fat.map { Int($0.rounded()) },
            isPer100g: isPer100g,
            productHint: extractProductHint(from: raw)
        )

        // Valores absurdos → ignora (OCR ruidoso).
        if let p = reading.proteinGrams, p > 120 { reading.proteinGrams = nil }
        if let c = reading.carbsGrams, c > 250 { reading.carbsGrams = nil }
        if let f = reading.fatGrams, f > 120 { reading.fatGrams = nil }
        if let kcal = reading.calories, kcal > 1500 || kcal < 5 { reading.calories = nil }

        return reading.isUsable ? reading : nil
    }

    private static func estimateFromNutritionLabel(_ ocrText: String) -> Estimate? {
        guard let reading = parseNutritionLabel(from: ocrText) else { return nil }

        let p = reading.proteinGrams ?? 0
        let c = reading.carbsGrams ?? 0
        let f = reading.fatGrams ?? 0
        let atwater = MealPhotoAnalysisEntry.estimatedCalories(protein: p, carbs: c, fat: f)
        let calories: Int
        if let labeled = reading.calories, labeled > 0 {
            // Se Atwater e rótulo divergem muito e há 3 macros, confia nos macros.
            if reading.macroCount == 3, atwater > 0, abs(atwater - labeled) > Int(Double(max(atwater, labeled)) * 0.25) {
                calories = atwater
            } else {
                calories = labeled
            }
        } else {
            calories = atwater
        }

        let label = reading.productHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        let foodLabel = (label?.isEmpty == false) ? label! : "Alimento (rótulo nutricional)"

        var note = "Li a tabela nutricional da embalagem"
        if reading.isPer100g {
            note += " (valores por 100 g — ajuste à porção que você comeu)"
        } else {
            note += " — confira se os valores são da porção consumida"
        }
        note += "."

        let confidence = reading.macroCount == 3 ? 0.92 : (reading.macroCount == 2 ? 0.84 : 0.72)

        return Estimate(
            foodLabel: foodLabel,
            proteinGrams: p,
            carbsGrams: c,
            fatGrams: f,
            calories: calories,
            confidence: confidence,
            note: note,
            detectedFoods: [foodLabel],
            fromNutritionLabel: true
        )
    }

    private static func firstNumber(in text: String, patterns: [String]) -> Double? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: range),
                  match.numberOfRanges > 1,
                  let numRange = Range(match.range(at: 1), in: text) else { continue }
            let raw = String(text[numRange])
            if let value = Double(raw) { return value }
        }
        return nil
    }

    private static func extractProductHint(from text: String) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        // Primeira linha “de produto” antes da tabela, se parecer nome.
        for line in lines.prefix(6) {
            let n = normalize(line)
            if n.contains("informacao nutricional") || n.contains("nutrition facts") { continue }
            if n.contains("valor energetico") || n.contains("proteina") { continue }
            if n.count < 3 || n.count > 42 { continue }
            if line.rangeOfCharacter(from: .decimalDigits) != nil, n.contains("kcal") { continue }
            // Evita linhas só de unidade.
            if n == "g" || n == "ml" || n == "kg" { continue }
            return String(line.prefix(42))
        }
        return nil
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
            if let last = identifier.split(whereSeparator: { $0 == ">" || $0 == "/" || $0 == "|" }).last {
                candidateTokens.append(normalize(String(last)))
            }

            for token in Set(candidateTokens) where token.count >= 3 {
                if let item = FoodMacroCatalog.item(matching: token)
                    ?? FoodMacroCatalog.item(matchingVisionLabel: token) {
                    let score = Double(observation.confidence) * item.matchWeight
                    guard score >= 0.05 else { continue }
                    // Classificações genéricas/fracas do Vision não devem dominar.
                    let floor: Double = item.isGeneric ? 0.18 : 0.14
                    hits.append(
                        CatalogHit(
                            item: item,
                            confidence: min(max(score, floor), 0.94),
                            source: "vision"
                        )
                    )
                }
            }
        }
        return hits
    }

    /// Agrupa pelo nome, remove genéricos/componentes redundantes e limita a 4 itens.
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

        // Se arroz + feijão aparecem separados, consolida no combo BR.
        if let arroz = bestByName["Arroz"], let feijao = bestByName["Feijão"],
           bestByName["Arroz e feijão"] == nil,
           let combo = FoodMacroCatalog.items.first(where: { $0.displayName == "Arroz e feijão" }) {
            let conf = min(max((arroz.confidence + feijao.confidence) / 2 + 0.08, 0.55), 0.95)
            bestByName["Arroz e feijão"] = CatalogHit(item: combo, confidence: conf, source: arroz.source)
            bestByName.removeValue(forKey: "Arroz")
            bestByName.removeValue(forKey: "Feijão")
        }

        // Combos / mais específicos supersedem componentes.
        applySupersession(&bestByName)

        let specific = bestByName.values.filter { !$0.item.isGeneric }
        let pool = specific.isEmpty ? Array(bestByName.values) : specific

        // Descarta hits muito fracos quando já há um forte.
        let strong = pool.filter { $0.confidence >= 0.28 }
        let trimmed = strong.isEmpty ? pool : strong

        return trimmed
            .sorted { $0.confidence > $1.confidence }
            .prefix(4)
            .map { $0 }
    }

    private static func applySupersession(_ map: inout [String: CatalogHit]) {
        // componente → alimentos que o invalidam
        let supersededBy: [String: Set<String>] = [
            "Arroz": ["Arroz e feijão"],
            "Feijão": ["Arroz e feijão", "Feijoada"],
            "Batata": ["Batata doce"],
            "Ovos": ["Omelete / café da manhã", "Tapioca"],
            "Fruta": ["Banana", "Maçã", "Laranja", "Açaí"],
            "Pão": ["Sanduíche", "Pizza"],
            "Queijo": ["Sanduíche", "Pizza", "Tacos / mexicano"],
            "Salada": ["Tacos / mexicano"],
        ]
        for (component, parents) in supersededBy {
            guard map[component] != nil else { continue }
            if parents.contains(where: { map[$0] != nil }) {
                map.removeValue(forKey: component)
            }
        }
    }

    static func composeEstimate(from hits: [CatalogHit], ocrBoosted: Bool) -> Estimate {
        let foods = hits.map(\.item.displayName)
        let protein = hits.reduce(0) { $0 + $1.item.proteinGrams }
        let carbs = hits.reduce(0) { $0 + $1.item.carbsGrams }
        let fat = hits.reduce(0) { $0 + $1.item.fatGrams }
        // Pratos compostos: soma de porções típicas tende a exagerar.
        let scale: Double
        switch hits.count {
        case 0, 1: scale = 1.0
        case 2: scale = 0.82
        case 3: scale = 0.72
        default: scale = 0.65
        }
        let p = Int((Double(protein) * scale).rounded())
        let c = Int((Double(carbs) * scale).rounded())
        let f = Int((Double(fat) * scale).rounded())

        let avgConfidence = hits.map(\.confidence).reduce(0, +) / Double(max(hits.count, 1))
        let maxConfidence = hits.map(\.confidence).max() ?? avgConfidence
        // Confiança global: média + bônus OCR, limitada pelo melhor hit (evita % inflado).
        var confidence = min(avgConfidence + (ocrBoosted ? 0.04 : 0), 0.97)
        confidence = min(confidence, maxConfidence + 0.08)
        if maxConfidence < 0.35 {
            confidence = min(confidence, 0.32)
        }

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
        var note: String
        if maxConfidence < 0.35 {
            note = "Identificação incerta (\(label)). Confirme o alimento e ajuste a porção."
        } else if sources.contains("ocr"), sources.contains("vision") {
            note = "Identifiquei: \(label). Combinei visão + texto — ajuste a porção se precisar."
        } else if sources.contains("ocr") {
            note = "Identifiquei pelo texto: \(label). Macros de porção típica — ajuste se a quantidade for diferente."
        } else if foods.count > 1 {
            note = "Detectei vários alimentos: \(label). Macros somados com fator de prato composto."
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
            detectedFoods: foods,
            fromNutritionLabel: false
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
        let trimmedOCR = ocrText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOCR.isEmpty {
            note += " Texto lido: \(trimmedOCR.prefix(80))."
        }
        return Estimate(
            foodLabel: "Refeição mista (estimativa)",
            proteinGrams: 28,
            carbsGrams: 45,
            fatGrams: 15,
            calories: MealPhotoAnalysisEntry.estimatedCalories(protein: 28, carbs: 45, fat: 15),
            confidence: 0.18,
            note: note,
            detectedFoods: ["Refeição mista"],
            fromNutritionLabel: false
        )
    }

    private static func bestKeywordScore(item: FoodMacroItem, in normalizedText: String) -> Double? {
        var best: Double?
        for keyword in item.keywords {
            let key = normalize(keyword)
            guard key.count >= 3, textContainsKeyword(normalizedText, keyword: key) else { continue }
            let isPhrase = key.contains(" ")
            let isShort = !isPhrase && key.count <= 4
            // Frases longas / específicas pontuam mais; tokens curtos (carne, pao) pontuam menos.
            let base = isShort ? 0.52 : (isPhrase ? 0.78 : 0.70)
            let lengthBonus = min(Double(key.count) / 22.0, 0.28)
            let score = base + lengthBonus
            if best == nil || score > best! { best = score }
        }
        return best
    }

    /// Evita colisões por substring (`orange` em outras palavras, `pao` em tokens maiores).
    static func textContainsKeyword(_ text: String, keyword: String) -> Bool {
        let key = normalize(keyword)
        guard !key.isEmpty else { return false }
        if key.contains(" ") {
            return text.contains(key)
        }
        let pattern = "(?<![a-z0-9])\(NSRegularExpression.escapedPattern(for: key))(?![a-z0-9])"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    static func normalize(_ value: String) -> String {
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
            keywords: ["peito de frango", "frango grelhado", "frango", "chicken", "grilled chicken", "roast chicken"],
            visionLabels: ["chicken", "roast chicken", "hen", "poultry"],
            proteinGrams: 42, carbsGrams: 2, fatGrams: 8, matchWeight: 1.0
        ),
        FoodMacroItem(
            displayName: "Carne bovina",
            keywords: ["carne bovina", "carne moida", "carne moída", "picanha", "alcatra", "bife", "steak", "beef", "carne"],
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
            keywords: ["ovos", "omelete", "ovo", "egg", "omelet", "omelette", "scrambled eggs"],
            visionLabels: ["egg", "omelet", "scrambled eggs"],
            proteinGrams: 18, carbsGrams: 2, fatGrams: 14, matchWeight: 0.95
        ),
        FoodMacroItem(
            displayName: "Arroz e feijão",
            keywords: ["arroz e feijao", "arroz e feijão", "arroz com feijao", "arroz com feijão", "rice and beans"],
            visionLabels: [],
            proteinGrams: 14, carbsGrams: 55, fatGrams: 6, matchWeight: 1.05
        ),
        FoodMacroItem(
            displayName: "Arroz",
            keywords: ["arroz branco", "arroz integral", "arroz", "white rice", "brown rice"],
            visionLabels: ["rice", "white rice", "fried rice"],
            proteinGrams: 4, carbsGrams: 45, fatGrams: 1, matchWeight: 0.9
        ),
        FoodMacroItem(
            displayName: "Feijão",
            keywords: ["feijao", "feijão", "black bean", "beans"],
            visionLabels: ["bean", "black bean"],
            proteinGrams: 12, carbsGrams: 28, fatGrams: 1, matchWeight: 0.9
        ),
        FoodMacroItem(
            displayName: "Feijoada",
            keywords: ["feijoada"],
            visionLabels: [],
            proteinGrams: 28, carbsGrams: 32, fatGrams: 18, matchWeight: 1.05
        ),
        FoodMacroItem(
            displayName: "Batata doce",
            keywords: ["batata doce", "batata-doce", "sweet potato"],
            visionLabels: ["sweet potato"],
            proteinGrams: 3, carbsGrams: 36, fatGrams: 0, matchWeight: 0.98
        ),
        FoodMacroItem(
            displayName: "Batata",
            keywords: ["batata frita", "pure de batata", "purê", "french fries", "mashed potato", "batata", "potato", "fries"],
            visionLabels: ["potato", "french fries", "mashed potato"],
            proteinGrams: 4, carbsGrams: 40, fatGrams: 10, matchWeight: 0.88
        ),
        FoodMacroItem(
            displayName: "Macarrão",
            keywords: ["macarrao", "macarrão", "espaguete", "lasanha", "pasta", "spaghetti", "lasagna", "noodle", "massa"],
            visionLabels: ["carbonara", "spaghetti", "pasta", "lasagna", "ramen"],
            proteinGrams: 12, carbsGrams: 60, fatGrams: 6, matchWeight: 0.95
        ),
        FoodMacroItem(
            displayName: "Salada",
            keywords: ["salada", "alface", "rúcula", "rucula", "salad", "lettuce", "greens"],
            visionLabels: ["salad", "lettuce", "vegetable"],
            proteinGrams: 4, carbsGrams: 10, fatGrams: 8, matchWeight: 0.82
        ),
        FoodMacroItem(
            displayName: "Brócolis",
            keywords: ["brocolis", "brócolis", "broccoli"],
            visionLabels: ["broccoli"],
            proteinGrams: 4, carbsGrams: 8, fatGrams: 0, matchWeight: 0.9
        ),
        FoodMacroItem(
            displayName: "Sanduíche",
            keywords: ["sanduiche", "sanduíche", "hamburguer", "hambúrguer", "cheeseburger", "burger", "hamburger", "sandwich", "hot dog"],
            visionLabels: ["cheeseburger", "hamburger", "hotdog", "sandwich"],
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
            keywords: ["acai bowl", "acai", "açaí"],
            visionLabels: ["acai", "smoothie bowl"],
            proteinGrams: 6, carbsGrams: 55, fatGrams: 10, matchWeight: 1.0
        ),
        FoodMacroItem(
            displayName: "Tapioca",
            keywords: ["tapioca", "crepioca"],
            visionLabels: [],
            proteinGrams: 8, carbsGrams: 36, fatGrams: 6, matchWeight: 1.0
        ),
        FoodMacroItem(
            displayName: "Salgado",
            keywords: ["coxinha", "pastel", "risoles", "empada", "enrroladinho", "salgado"],
            visionLabels: [],
            proteinGrams: 10, carbsGrams: 28, fatGrams: 14, matchWeight: 0.92
        ),
        FoodMacroItem(
            displayName: "Iogurte",
            keywords: ["iogurte grego", "iogurte", "yogurt", "yoghurt", "grego"],
            visionLabels: ["yogurt"],
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
            keywords: ["laranja", "suco de laranja"],
            visionLabels: ["orange"],
            proteinGrams: 1, carbsGrams: 18, fatGrams: 0, matchWeight: 0.95
        ),
        FoodMacroItem(
            displayName: "Fruta",
            keywords: ["fruta", "fruit", "morango", "strawberry", "uva", "grape", "manga", "mango", "mamao", "mamão", "abacate", "avocado"],
            visionLabels: ["strawberry", "grape", "mango", "pineapple", "fruit"],
            proteinGrams: 1, carbsGrams: 22, fatGrams: 1, matchWeight: 0.72
        ),
        FoodMacroItem(
            displayName: "Whey / shake",
            keywords: ["whey protein", "whey", "protein shake", "shake proteico", "smoothie", "proteina", "proteína"],
            visionLabels: ["smoothie", "milkshake"],
            proteinGrams: 25, carbsGrams: 8, fatGrams: 2, matchWeight: 0.88
        ),
        FoodMacroItem(
            displayName: "Pão",
            keywords: ["pao frances", "pão francês", "pao de forma", "torrada", "toast", "bread", "pao", "pão"],
            visionLabels: ["bagel", "pretzel", "bread loaf", "french loaf"],
            proteinGrams: 8, carbsGrams: 40, fatGrams: 4, matchWeight: 0.85
        ),
        FoodMacroItem(
            displayName: "Queijo",
            keywords: ["queijo", "mussarela", "muçarela", "cottage", "cheese"],
            visionLabels: ["cheese"],
            proteinGrams: 14, carbsGrams: 2, fatGrams: 16, matchWeight: 0.85
        ),
        FoodMacroItem(
            displayName: "Omelete / café da manhã",
            keywords: ["cafe da manha", "café da manhã", "breakfast", "pancake", "waffle"],
            visionLabels: ["pancake", "waffle"],
            proteinGrams: 18, carbsGrams: 40, fatGrams: 14, matchWeight: 0.7
        ),
        FoodMacroItem(
            displayName: "Sopa",
            keywords: ["sopa", "caldo", "soup", "broth"],
            visionLabels: ["soup", "hot pot", "consomme"],
            proteinGrams: 12, carbsGrams: 20, fatGrams: 6, matchWeight: 0.85
        ),
        FoodMacroItem(
            displayName: "Tacos / mexicano",
            keywords: ["taco", "burrito", "mexican", "nachos", "guacamole"],
            visionLabels: ["taco", "burrito", "guacamole"],
            proteinGrams: 20, carbsGrams: 35, fatGrams: 16, matchWeight: 0.9
        ),
        FoodMacroItem(
            displayName: "Mandioca",
            keywords: ["mandioca", "aipim", "macaxeira", "cassava"],
            visionLabels: [],
            proteinGrams: 2, carbsGrams: 38, fatGrams: 2, matchWeight: 0.95
        ),
        FoodMacroItem(
            displayName: "Prato feito",
            keywords: ["prato feito", "marmita", "almoco", "almoço", "jantar"],
            visionLabels: ["plate", "restaurant", "tray"],
            proteinGrams: 35, carbsGrams: 50, fatGrams: 16, matchWeight: 0.42,
            isGeneric: true
        ),
    ]

    static func item(matching token: String) -> FoodMacroItem? {
        let normalized = MealPhotoAnalysisEngine.normalize(token)
        guard normalized.count >= 3 else { return nil }

        var best: (FoodMacroItem, Int)?
        for item in items {
            for keyword in item.keywords {
                let key = MealPhotoAnalysisEngine.normalize(keyword)
                guard key.count >= 3 else { continue }
                let exact = normalized == key
                let tokenHasKey = MealPhotoAnalysisEngine.textContainsKeyword(normalized, keyword: key)
                let keyHasToken = key.count >= 5 && MealPhotoAnalysisEngine.textContainsKeyword(key, keyword: normalized)
                guard exact || tokenHasKey || keyHasToken else { continue }
                // Preferência forte por match exato / keyword mais longa.
                let score = key.count + (exact ? 20 : 0) + (tokenHasKey && key.count >= 8 ? 8 : 0)
                if best == nil || score > best!.1 {
                    best = (item, score)
                }
            }
        }
        return best?.0
    }

    static func item(matchingVisionLabel label: String) -> FoodMacroItem? {
        let normalized = MealPhotoAnalysisEngine.normalize(label)
        guard normalized.count >= 3 else { return nil }
        var best: (FoodMacroItem, Int)?
        for item in items {
            for vision in item.visionLabels {
                let key = MealPhotoAnalysisEngine.normalize(vision)
                guard key.count >= 3 else { continue }
                let exact = normalized == key
                let contains = MealPhotoAnalysisEngine.textContainsKeyword(normalized, keyword: key)
                    || MealPhotoAnalysisEngine.textContainsKeyword(key, keyword: normalized)
                guard exact || contains else { continue }
                let score = key.count + (exact ? 20 : 0)
                if best == nil || score > best!.1 {
                    best = (item, score)
                }
            }
        }
        return best?.0
    }
}
