import Foundation

/// Ângulos fixos para comparação consistente entre períodos (até 6 fotos).
enum BodyPhotoSlot: String, Codable, CaseIterable, Identifiable, Hashable {
    case front
    case back
    case leftSide
    case rightSide
    case abdomen
    case extra

    var id: String { rawValue }

    var title: String {
        switch self {
        case .front: return "Frente"
        case .back: return "Costas"
        case .leftSide: return "Lado esquerdo"
        case .rightSide: return "Lado direito"
        case .abdomen: return "Abdômen"
        case .extra: return "Extra"
        }
    }

    var systemImage: String {
        switch self {
        case .front: return "person.fill"
        case .back: return "person.fill.turn.right"
        case .leftSide, .rightSide: return "person.and.arrow.left.and.arrow.right"
        case .abdomen: return "figure.stand"
        case .extra: return "camera.fill"
        }
    }
}

struct BodyPhotoEntry: Codable, Equatable, Identifiable {
    var slot: BodyPhotoSlot
    var storagePath: String?
    var localFileName: String?

    var id: String { slot.rawValue }

    var hasPhoto: Bool {
        storagePath != nil || localFileName != nil
    }
}

struct BodyPhotoSet: Codable, Equatable, Identifiable {
    var id: String
    var capturedAt: Date
    var photos: [BodyPhotoEntry]

    init(id: String = UUID().uuidString, capturedAt: Date = .now, photos: [BodyPhotoEntry] = BodyPhotoSet.emptyEntries()) {
        self.id = id
        self.capturedAt = capturedAt
        self.photos = photos
    }

    static func emptyEntries() -> [BodyPhotoEntry] {
        BodyPhotoSlot.allCases.map { BodyPhotoEntry(slot: $0) }
    }

    var filledCount: Int {
        photos.filter(\.hasPhoto).count
    }

    var maxPhotos: Int { BodyPhotoSlot.allCases.count }

    var hasAnyPhoto: Bool { filledCount > 0 }

    var storagePaths: [String] {
        photos.compactMap(\.storagePath)
    }

    func entry(for slot: BodyPhotoSlot) -> BodyPhotoEntry? {
        photos.first { $0.slot == slot }
    }

    mutating func upsert(_ entry: BodyPhotoEntry) {
        if let index = photos.firstIndex(where: { $0.slot == entry.slot }) {
            photos[index] = entry
        } else {
            photos.append(entry)
        }
    }

    var comparisonEligibleAt: Date {
        Calendar.current.date(
            byAdding: .day,
            value: BodyMeasurements.comparisonIntervalDays,
            to: capturedAt
        ) ?? capturedAt.addingTimeInterval(
            TimeInterval(BodyMeasurements.comparisonIntervalDays * 24 * 60 * 60)
        )
    }

    func daysUntilComparisonEligible(referenceDate: Date = .now) -> Int {
        let elapsed = BodyMeasurements.daysBetween(capturedAt, referenceDate)
        return max(BodyMeasurements.comparisonIntervalDays - elapsed, 0)
    }

    func isEligibleForComparison(referenceDate: Date = .now) -> Bool {
        BodyMeasurements.daysBetween(capturedAt, referenceDate) >= BodyMeasurements.comparisonIntervalDays
    }
}

struct BodyEvolutionMeta: Codable, Equatable {
    var activePhotoSet: BodyPhotoSet?
    var lastEvaluationAt: Date?

    static let empty = BodyEvolutionMeta()

    var statusLabel: String {
        guard let set = activePhotoSet else {
            return "Inicie o acompanhamento (fotos opcionais e privadas)."
        }
        if set.isEligibleForComparison() {
            return set.hasAnyPhoto
                ? "Pronto para nova comparação (30 dias concluídos)."
                : "Pronto para comparar medidas (30 dias concluídos). Fotos continuam opcionais."
        }
        let remaining = set.daysUntilComparisonEligible()
        let photoNote = set.hasAnyPhoto
            ? "\(set.filledCount) foto(s) privadas salvas. "
            : "Sem fotos neste lote (opcional). "
        return "\(photoNote)Próxima comparação em \(remaining) dia(s)."
    }
}

struct BodyEvolutionEvaluation: Codable, Equatable, Identifiable {
    var id: String
    var createdAt: Date
    var previousMeasurements: BodyMeasurements
    var currentMeasurements: BodyMeasurements
    var changes: [BodyMeasurementChange]
    var periodDays: Int
    var pdfStoragePath: String?
    var previousPhotoSetId: String
    var currentPhotoSetId: String
    var summaryText: String
    var previousPhotosDeleted: Bool

    static let maxRetainedEvaluations = 4

    static func makeSummary(
        comparison: BodyMeasurementComparison?,
        photoCountPrevious: Int,
        photoCountCurrent: Int
    ) -> String {
        var lines: [String] = []
        if let comparison {
            lines.append("Comparativo de \(comparison.periodDays) dia(s).")
            if comparison.changes.isEmpty {
                lines.append("Nenhuma circunferência variou de forma mensurável.")
            } else {
                let top = comparison.changes
                    .sorted { abs($0.delta) > abs($1.delta) }
                    .prefix(4)
                for change in top {
                    lines.append(
                        "\(change.label): \(BodyMeasurements.formatCm(change.previous)) → \(BodyMeasurements.formatCm(change.current)) (\(BodyMeasurements.formatDelta(change.delta)))."
                    )
                }
            }
        } else {
            lines.append("Comparação registrada. Atualize as medidas no Perfil para um laudo mais completo.")
        }
        lines.append("Fotos: \(photoCountPrevious) → \(photoCountCurrent) (envio opcional e privado).")
        if photoCountPrevious > 0 {
            lines.append("As fotos anteriores foram excluídas após a comparação. Os PDFs das últimas \(maxRetainedEvaluations) avaliações permanecem salvos (somente você acessa).")
        } else {
            lines.append("Nenhuma foto anterior para excluir. Os PDFs das últimas \(maxRetainedEvaluations) avaliações permanecem salvos (somente você acessa).")
        }
        return lines.joined(separator: " ")
    }
}

enum BodyEvolutionCyclePhase: Equatable {
    case empty
    case waiting(daysRemaining: Int)
    case readyToCompare
}
