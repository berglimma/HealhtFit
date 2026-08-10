import Foundation
import PDFKit
import UIKit
import UniformTypeIdentifiers
import Vision

struct ParsedWorkoutSheetDraft: Equatable {
    var title: String
    var description: String
    var exercises: [Exercise]
}

enum WorkoutSheetImportSource: String {
    case camera
    case photo
    case file

    var descriptionPrefix: String {
        switch self {
        case .camera: return "Importada pela câmera"
        case .photo: return "Importada de uma foto"
        case .file: return "Importada de um arquivo"
        }
    }
}

/// OCR + interpretação de texto de fichas de treino impressas.
enum WorkoutSheetOCRParser {
    static let supportedFileContentTypes: [UTType] = [.pdf, .jpeg, .png, .image]

    /// Converte PDF/JPEG/PNG (e imagens genéricas) em páginas para OCR.
    static func images(fromFileURL url: URL) throws -> [UIImage] {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" || UTType(filenameExtension: ext)?.conforms(to: .pdf) == true {
            return try renderPDF(at: url)
        }

        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else {
            throw WorkoutSheetScanError.invalidImage
        }
        return [image]
    }

    static func renderPDF(at url: URL, maxPages: Int = 8) throws -> [UIImage] {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            throw WorkoutSheetScanError.invalidPDF
        }

        var images: [UIImage] = []
        let pageCount = min(document.pageCount, maxPages)
        for index in 0..<pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.5
            let size = CGSize(width: max(bounds.width * scale, 1), height: max(bounds.height * scale, 1))
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 0, y: size.height)
                context.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: context.cgContext)
                context.cgContext.restoreGState()
            }
            images.append(image)
        }

        guard !images.isEmpty else {
            throw WorkoutSheetScanError.invalidPDF
        }
        return images
    }

    static func recognizeText(in images: [UIImage]) async throws -> String {
        var pages: [String] = []
        for image in images {
            let page = try await recognizeText(in: image)
            if !page.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pages.append(page)
            }
        }
        guard !pages.isEmpty else {
            throw WorkoutSheetScanError.noTextRecognized
        }
        return pages.joined(separator: "\n")
    }

    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw WorkoutSheetScanError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["pt-BR", "pt-PT", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    static func parse(
        _ rawText: String,
        source: WorkoutSheetImportSource = .camera
    ) -> ParsedWorkoutSheetDraft {
        let lines = rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var title = inferredTitle(from: lines) ?? "Ficha importada"
        var exercises: [Exercise] = []

        for line in lines {
            if isLikelyTitleLine(line), exercises.isEmpty {
                let cleaned = cleanTitle(line)
                if !cleaned.isEmpty { title = cleaned }
                continue
            }
            if isNoiseLine(line) { continue }
            if let exercise = parseExerciseLine(line) {
                exercises.append(exercise)
            }
        }

        let description = "\(source.descriptionPrefix) em \(formattedScanDate())."
        return ParsedWorkoutSheetDraft(
            title: title,
            description: description,
            exercises: exercises
        )
    }

    // MARK: - Line parsing

    static func parseExerciseLine(_ line: String) -> Exercise? {
        let stripped = stripLeadingIndex(line)
        guard stripped.count >= 3 else { return nil }
        if isNoiseLine(stripped) { return nil }

        var working = stripped
        var sets = 3
        var reps = 12
        var weight: Double?
        var restSeconds = 60
        var foundVolume = false

        if let match = firstMatch(
            in: working,
            pattern: #"(?i)(\d+)\s*[xX×]\s*(\d+)"#
        ) {
            if let s = Int(match.1), let r = Int(match.2), s > 0, r > 0, s <= 20, r <= 100 {
                sets = s
                reps = r
                foundVolume = true
                working = working.replacingOccurrences(of: match.0, with: " ")
            }
        } else if let match = firstMatch(
            in: working,
            pattern: #"(?i)(\d+)\s*s[eé]ries?\s*(?:de\s*)?(\d+)\s*(?:reps?|repeti[cç][oõ]es?)?"#
        ) {
            if let s = Int(match.1), let r = Int(match.2), s > 0, r > 0 {
                sets = s
                reps = r
                foundVolume = true
                working = working.replacingOccurrences(of: match.0, with: " ")
            }
        } else if let match = firstMatch(
            in: working,
            pattern: #"(?i)(\d+)\s*(?:reps?|repeti[cç][oõ]es?)"#
        ), let r = Int(match.1), r > 0, r <= 100 {
            reps = r
            foundVolume = true
            working = working.replacingOccurrences(of: match.0, with: " ")
        }

        if let match = firstMatch(
            in: working,
            pattern: #"(?i)(\d+(?:[.,]\d+)?)\s*kg"#
        ) {
            let normalized = match.1.replacingOccurrences(of: ",", with: ".")
            if let value = Double(normalized), value > 0, value < 1000 {
                weight = value
                working = working.replacingOccurrences(of: match.0, with: " ")
            }
        }

        if let match = firstMatch(
            in: working,
            pattern: #"(?i)(?:descanso|rest|intervalo)\s*[:=]?\s*(\d+)\s*s?"#
        ), let seconds = Int(match.1), seconds > 0, seconds <= 600 {
            restSeconds = seconds
            working = working.replacingOccurrences(of: match.0, with: " ")
        }

        let name = cleanExerciseName(working)
        guard name.count >= 3 else { return nil }

        // Evita capturar títulos soltos sem volume como exercício.
        if !foundVolume, looksLikeSectionHeader(name) {
            return nil
        }

        return Exercise(
            name: name,
            sets: sets,
            reps: reps,
            weight: weight,
            restSeconds: restSeconds,
            muscleGroup: inferredMuscleGroup(for: name)
        )
    }

    // MARK: - Helpers

    private static func inferredTitle(from lines: [String]) -> String? {
        for line in lines.prefix(8) {
            if isLikelyTitleLine(line) {
                let cleaned = cleanTitle(line)
                if !cleaned.isEmpty { return cleaned }
            }
        }
        return lines.first.map(cleanTitle).flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func isLikelyTitleLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        if lower.contains("treino") || lower.contains("ficha") || lower.contains("programa") {
            return true
        }
        if looksLikeSectionHeader(line), parseExerciseLine(stripLeadingIndex(line)) == nil {
            return line.count <= 40
        }
        return false
    }

    private static func isNoiseLine(_ line: String) -> Bool {
        let lower = line.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
        let noise: Set<String> = [
            "exercicio", "exercícios", "exercicios", "series", "séries", "reps", "repeticoes",
            "repetições", "carga", "peso", "kg", "observacoes", "observações", "nome",
            "musculo", "músculo", "grupo", "descanso", "assinatura", "data", "aluno", "professor"
        ]
        if noise.contains(lower) { return true }
        if lower.count <= 2 { return true }
        // Cabeçalhos de tabela com muitas barras/colunas
        if line.filter({ $0 == "|" || $0 == "/" }).count >= 2, line.count < 24 {
            return true
        }
        return false
    }

    private static func looksLikeSectionHeader(_ line: String) -> Bool {
        let lower = line.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
        let headers = [
            "peito", "costas", "pernas", "ombros", "bracos", "bracos", "abdomen", "abdômen",
            "triceps", "biceps", "trapezio", "gluteos", "treino a", "treino b", "treino c",
            "treino d", "dia 1", "dia 2", "dia 3", "superior", "inferior"
        ]
        return headers.contains(where: { lower == $0 || lower.hasPrefix($0 + " ") })
    }

    private static func stripLeadingIndex(_ line: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"^\s*\d+[\.\)\-\:]\s*"#) else {
            return line
        }
        let range = NSRange(line.startIndex..., in: line)
        return regex.stringByReplacingMatches(in: line, range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanTitle(_ line: String) -> String {
        var text = stripLeadingIndex(line)
        text = text.replacingOccurrences(of: #"^[-\•\*]+"#, with: "", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanExerciseName(_ raw: String) -> String {
        var text = raw
        text = text.replacingOccurrences(
            of: #"(?i)\b\d+(?:[.,]\d+)?\s*(?:kg|lbs?)\b"#,
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"(?i)\b\d+\s*[xX×]\s*\d+\b"#,
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        // Capitaliza de forma simples
        if text == text.lowercased() || text == text.uppercased() {
            text = text.capitalized(with: Locale(identifier: "pt_BR"))
        }
        return text
    }

    static func inferredMuscleGroup(for exerciseName: String) -> MuscleGroup {
        switch CustomWorkoutFocusGroup.focusGroup(for: exerciseName) {
        case .chest: return .chest
        case .back, .trapezius: return .back
        case .legs: return .legs
        case .shoulders: return .shoulders
        case .biceps, .triceps: return .arms
        case .none:
            let n = exerciseName.lowercased()
            if n.contains("abdom") || n.contains("prancha") || n.contains("core") {
                return .core
            }
            return .fullBody
        }
    }

    private static func firstMatch(
        in text: String,
        pattern: String
    ) -> (String, String, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges >= 2 else {
            return nil
        }
        guard let fullRange = Range(match.range(at: 0), in: text),
              let g1 = Range(match.range(at: 1), in: text) else { return nil }
        let g2: String
        if match.numberOfRanges >= 3, let r2 = Range(match.range(at: 2), in: text) {
            g2 = String(text[r2])
        } else {
            g2 = ""
        }
        return (String(text[fullRange]), String(text[g1]), g2)
    }

    private static func formattedScanDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: .now)
    }
}

enum WorkoutSheetScanError: LocalizedError {
    case invalidImage
    case invalidPDF
    case unsupportedFile
    case noTextRecognized
    case noExercisesFound
    case cameraUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Não foi possível ler a imagem. Use JPEG ou PNG nítidos."
        case .invalidPDF:
            return "Não foi possível ler o PDF. Verifique se o arquivo não está corrompido."
        case .unsupportedFile:
            return "Formato não suportado. Envie PDF, JPEG ou PNG."
        case .noTextRecognized:
            return "Nenhum texto foi reconhecido. Tente outra foto, print ou PDF mais nítido."
        case .noExercisesFound:
            return "Não encontramos exercícios na ficha. Confira se o arquivo está legível e tente de novo."
        case .cameraUnavailable:
            return "A câmera de documentos não está disponível neste dispositivo."
        }
    }
}
