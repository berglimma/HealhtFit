import Foundation
import UIKit

import Combine
struct BodyEvolutionComparisonResult: Equatable {
    let evaluation: BodyEvolutionEvaluation
    let previousImages: [BodyPhotoSlot: UIImage]
    let currentImages: [BodyPhotoSlot: UIImage]
    let measurementComparison: BodyMeasurementComparison?
    let deletionNotice: String
}

@MainActor
final class BodyEvolutionService: ObservableObject {
    static let shared = BodyEvolutionService()

    @Published private(set) var meta: BodyEvolutionMeta = .empty
    @Published private(set) var evaluations: [BodyEvolutionEvaluation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var lastError: String?
    @Published var lastDeletionNotice: String?

    /// Mensagem pendente para o IAssistente consumir na próxima abertura do chat.
    @Published private(set) var pendingAssistantMessage: String?

    private var loadedUserId: String?
    private let pendingMessageKey = "bodyEvolution.pendingAssistantMessage"

    private init() {
        pendingAssistantMessage = UserDefaults.standard.string(forKey: pendingMessageKey)
    }

    var cyclePhase: BodyEvolutionCyclePhase {
        guard let set = meta.activePhotoSet else { return .empty }
        if set.isEligibleForComparison() { return .readyToCompare }
        return .waiting(daysRemaining: set.daysUntilComparisonEligible())
    }

    func loadIfNeeded(userId: String) async {
        if loadedUserId == userId, !evaluations.isEmpty || meta.activePhotoSet != nil {
            return
        }
        await refresh(userId: userId)
    }

    func refresh(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        loadedUserId = userId

        if let local = loadLocalState(userId: userId) {
            meta = local.meta
            evaluations = local.evaluations
        }

        do {
            if let remoteMeta = try await BodyEvolutionFirestoreService.fetchMeta(userId: userId) {
                meta = remoteMeta
            }
            let remoteEvaluations = try await BodyEvolutionFirestoreService.fetchEvaluations(userId: userId)
            if !remoteEvaluations.isEmpty {
                evaluations = remoteEvaluations
            }
            persistLocalState(userId: userId)
            scheduleReadyReminderIfNeeded(userId: userId)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func localImage(userId: String, setId: String, slot: BodyPhotoSlot) -> UIImage? {
        let url = localPhotoURL(userId: userId, setId: setId, slot: slot)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Salva o checkpoint do ciclo (fotos opcionais e privadas).
    func saveBaselinePhotos(
        userId: String,
        imagesBySlot: [BodyPhotoSlot: UIImage]
    ) async throws {
        if let active = meta.activePhotoSet, active.isEligibleForComparison() {
            throw BodyEvolutionError.notEligible
        }

        isSaving = true
        defer { isSaving = false }

        let setId = meta.activePhotoSet?.id ?? UUID().uuidString
        let capturedAt = meta.activePhotoSet?.capturedAt ?? .now
        var photoSet = BodyPhotoSet(id: setId, capturedAt: capturedAt)

        for slot in BodyPhotoSlot.allCases {
            guard let image = imagesBySlot[slot] else { continue }
            let jpeg = try jpegData(from: image)
            let fileName = "\(slot.rawValue).jpg"
            try writeLocalPhoto(jpeg, userId: userId, setId: setId, slot: slot)

            var entry = BodyPhotoEntry(slot: slot, localFileName: fileName)
            if BodyEvolutionStorageService.isAvailable {
                // Upload privado: Storage rules permitem só request.auth.uid == userId.
                entry.storagePath = try await BodyEvolutionStorageService.uploadJPEG(
                    data: jpeg,
                    userId: userId,
                    setId: setId,
                    slot: slot
                )
            }
            photoSet.upsert(entry)
        }

        // Preserva slots já salvos que não foram reenviados nesta sessão.
        if let previous = meta.activePhotoSet {
            for entry in previous.photos where entry.hasPhoto && imagesBySlot[entry.slot] == nil {
                photoSet.upsert(entry)
            }
        }

        meta.activePhotoSet = photoSet
        try await BodyEvolutionFirestoreService.saveMeta(meta, userId: userId)
        persistLocalState(userId: userId)
        scheduleReadyReminderIfNeeded(userId: userId)
        lastError = nil
    }

    /// Compara evolução após 30 dias. Fotos novas são opcionais.
    func compareWithNewPhotos(
        userId: String,
        athleteName: String,
        imagesBySlot: [BodyPhotoSlot: UIImage],
        previousMeasurements: BodyMeasurements?,
        currentMeasurements: BodyMeasurements
    ) async throws -> BodyEvolutionComparisonResult {
        guard let previousSet = meta.activePhotoSet else {
            throw BodyEvolutionError.noBaseline
        }
        guard previousSet.isEligibleForComparison() else {
            throw BodyEvolutionError.notEligible
        }

        let previousMeasures = previousMeasurements ?? .empty
        let comparison = BodyMeasurementComparison.make(
            previous: previousMeasures,
            current: currentMeasurements
        )
        guard !imagesBySlot.isEmpty || comparison != nil || currentMeasurements.hasAnyValue else {
            throw BodyEvolutionError.missingComparisonData
        }

        isSaving = true
        defer { isSaving = false }

        // Carrega imagens anteriores antes de apagar (somente neste dispositivo / conta).
        var previousImages: [BodyPhotoSlot: UIImage] = [:]
        for entry in previousSet.photos where entry.hasPhoto {
            if let local = localImage(userId: userId, setId: previousSet.id, slot: entry.slot) {
                previousImages[entry.slot] = local
            } else if let path = entry.storagePath,
                      let data = await BodyEvolutionStorageService.downloadData(storagePath: path),
                      let image = UIImage(data: data) {
                previousImages[entry.slot] = image
            }
        }

        let newSetId = UUID().uuidString
        var newSet = BodyPhotoSet(id: newSetId, capturedAt: .now)
        var currentImages: [BodyPhotoSlot: UIImage] = [:]

        for slot in BodyPhotoSlot.allCases {
            guard let image = imagesBySlot[slot] else { continue }
            currentImages[slot] = image
            let jpeg = try jpegData(from: image)
            try writeLocalPhoto(jpeg, userId: userId, setId: newSetId, slot: slot)
            var entry = BodyPhotoEntry(slot: slot, localFileName: "\(slot.rawValue).jpg")
            if BodyEvolutionStorageService.isAvailable {
                entry.storagePath = try await BodyEvolutionStorageService.uploadJPEG(
                    data: jpeg,
                    userId: userId,
                    setId: newSetId,
                    slot: slot
                )
            }
            newSet.upsert(entry)
        }

        let evaluationId = UUID().uuidString
        let summary = BodyEvolutionEvaluation.makeSummary(
            comparison: comparison,
            photoCountPrevious: previousSet.filledCount,
            photoCountCurrent: newSet.filledCount
        )

        var evaluation = BodyEvolutionEvaluation(
            id: evaluationId,
            createdAt: .now,
            previousMeasurements: previousMeasures,
            currentMeasurements: currentMeasurements,
            changes: comparison?.changes ?? [],
            periodDays: comparison?.periodDays
                ?? BodyMeasurements.daysBetween(previousSet.capturedAt, newSet.capturedAt),
            pdfStoragePath: nil,
            previousPhotoSetId: previousSet.id,
            currentPhotoSetId: newSet.id,
            summaryText: summary,
            previousPhotosDeleted: false
        )

        let pdfData = BodyMeasurementsPDFBuilder.build(
            evaluation: evaluation,
            athleteName: athleteName
        )
        if BodyEvolutionStorageService.isAvailable {
            evaluation.pdfStoragePath = try await BodyEvolutionStorageService.uploadPDF(
                data: pdfData,
                userId: userId,
                evaluationId: evaluationId
            )
        }
        try writeLocalPDF(pdfData, userId: userId, evaluationId: evaluationId)

        // Apaga fotos do baseline anterior (privadas — só o dono tinha acesso).
        if !previousSet.storagePaths.isEmpty {
            await BodyEvolutionStorageService.deletePaths(previousSet.storagePaths)
        }
        deleteLocalPhotoSet(userId: userId, setId: previousSet.id)
        evaluation.previousPhotosDeleted = previousSet.filledCount > 0

        let deletionNotice: String = {
            if previousSet.filledCount > 0 {
                return "As \(previousSet.filledCount) foto(s) anteriores foram excluídas automaticamente. " +
                    "Somente você podia vê-las. Os PDFs das últimas \(BodyEvolutionEvaluation.maxRetainedEvaluations) avaliações permanecem salvos (acesso exclusivo da sua conta)."
            }
            return "Avaliação salva sem fotos anteriores. Os PDFs das últimas \(BodyEvolutionEvaluation.maxRetainedEvaluations) avaliações ficam apenas na sua conta."
        }()

        meta = BodyEvolutionMeta(activePhotoSet: newSet, lastEvaluationAt: evaluation.createdAt)
        try await BodyEvolutionFirestoreService.saveMeta(meta, userId: userId)
        try await BodyEvolutionFirestoreService.saveEvaluation(evaluation, userId: userId)

        let removedPDFPaths = try await BodyEvolutionFirestoreService.trimEvaluations(userId: userId)
        if !removedPDFPaths.isEmpty {
            await BodyEvolutionStorageService.deletePaths(removedPDFPaths)
            for path in removedPDFPaths {
                let id = (path as NSString).lastPathComponent.replacingOccurrences(of: ".pdf", with: "")
                deleteLocalPDF(userId: userId, evaluationId: id)
            }
        }

        evaluations = ([evaluation] + evaluations.filter { $0.id != evaluation.id })
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(BodyEvolutionEvaluation.maxRetainedEvaluations)
            .map { $0 }

        persistLocalState(userId: userId)
        lastDeletionNotice = deletionNotice
        queueAssistantAnnouncement(summary)
        NotificationService.shared.deliverBodyEvolutionResult(
            summary: shortNotificationBody(from: summary)
        )
        scheduleReadyReminderIfNeeded(userId: userId)

        return BodyEvolutionComparisonResult(
            evaluation: evaluation,
            previousImages: previousImages,
            currentImages: currentImages,
            measurementComparison: comparison,
            deletionNotice: deletionNotice
        )
    }

    func consumePendingAssistantMessage() -> String? {
        let message = pendingAssistantMessage
        pendingAssistantMessage = nil
        UserDefaults.standard.removeObject(forKey: pendingMessageKey)
        return message
    }

    func localPDFURL(userId: String, evaluationId: String) -> URL? {
        let url = pdfDirectory(userId: userId).appendingPathComponent("\(evaluationId).pdf")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func ensureLocalPDF(userId: String, evaluation: BodyEvolutionEvaluation) async -> URL? {
        if let existing = localPDFURL(userId: userId, evaluationId: evaluation.id) {
            return existing
        }
        guard let path = evaluation.pdfStoragePath,
              let data = await BodyEvolutionStorageService.downloadData(storagePath: path) else {
            return nil
        }
        try? writeLocalPDF(data, userId: userId, evaluationId: evaluation.id)
        return localPDFURL(userId: userId, evaluationId: evaluation.id)
    }

    // MARK: - Private

    private func queueAssistantAnnouncement(_ text: String) {
        let message = """
        Sua evolução corporal foi atualizada.

        \(text)

        Abra Perfil → Evolução Corporal para ver o comparativo e o PDF da avaliação.
        """
        pendingAssistantMessage = message
        UserDefaults.standard.set(message, forKey: pendingMessageKey)
        PostWorkoutCheckInService.shared.notifyAssistantMessagePending()
    }

    private func shortNotificationBody(from summary: String) -> String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 160 { return trimmed }
        return String(trimmed.prefix(157)) + "..."
    }

    private func scheduleReadyReminderIfNeeded(userId: String) {
        guard let set = meta.activePhotoSet else {
            NotificationService.shared.cancelBodyEvolutionReadyReminder()
            return
        }
        NotificationService.shared.scheduleBodyEvolutionReady(
            fireDate: set.comparisonEligibleAt,
            userId: userId
        )
    }

    private func jpegData(from image: UIImage) throws -> Data {
        let resized = Self.resized(image, maxSide: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.82) else {
            throw BodyEvolutionError.unknown
        }
        return data
    }

    private static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private struct LocalState: Codable {
        var meta: BodyEvolutionMeta
        var evaluations: [BodyEvolutionEvaluation]
    }

    private func stateURL(userId: String) -> URL {
        rootDirectory(userId: userId).appendingPathComponent("state.json")
    }

    private func loadLocalState(userId: String) -> LocalState? {
        let url = stateURL(userId: userId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LocalState.self, from: data)
    }

    private func persistLocalState(userId: String) {
        let state = LocalState(meta: meta, evaluations: evaluations)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        try? FileManager.default.createDirectory(
            at: rootDirectory(userId: userId),
            withIntermediateDirectories: true
        )
        try? data.write(to: stateURL(userId: userId), options: .atomic)
    }

    private func rootDirectory(userId: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("BodyEvolution/\(userId)", isDirectory: true)
    }

    private func photosDirectory(userId: String, setId: String) -> URL {
        rootDirectory(userId: userId)
            .appendingPathComponent("photos", isDirectory: true)
            .appendingPathComponent(setId, isDirectory: true)
    }

    private func pdfDirectory(userId: String) -> URL {
        rootDirectory(userId: userId).appendingPathComponent("pdfs", isDirectory: true)
    }

    private func localPhotoURL(userId: String, setId: String, slot: BodyPhotoSlot) -> URL {
        photosDirectory(userId: userId, setId: setId).appendingPathComponent("\(slot.rawValue).jpg")
    }

    private func writeLocalPhoto(_ data: Data, userId: String, setId: String, slot: BodyPhotoSlot) throws {
        let dir = photosDirectory(userId: userId, setId: setId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: localPhotoURL(userId: userId, setId: setId, slot: slot), options: .atomic)
    }

    private func deleteLocalPhotoSet(userId: String, setId: String) {
        let dir = photosDirectory(userId: userId, setId: setId)
        try? FileManager.default.removeItem(at: dir)
    }

    private func writeLocalPDF(_ data: Data, userId: String, evaluationId: String) throws {
        let dir = pdfDirectory(userId: userId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(
            to: dir.appendingPathComponent("\(evaluationId).pdf"),
            options: .atomic
        )
    }

    private func deleteLocalPDF(userId: String, evaluationId: String) {
        let url = pdfDirectory(userId: userId).appendingPathComponent("\(evaluationId).pdf")
        try? FileManager.default.removeItem(at: url)
    }

    /// Limpa estado em memória e pending message ao trocar/sair da conta.
    func resetForAccountSwitch() {
        meta = .empty
        evaluations = []
        isLoading = false
        isSaving = false
        lastError = nil
        lastDeletionNotice = nil
        loadedUserId = nil
        pendingAssistantMessage = nil
        UserDefaults.standard.removeObject(forKey: pendingMessageKey)
    }
}
