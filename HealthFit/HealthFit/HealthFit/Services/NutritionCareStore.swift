import Combine
import Foundation

/// Acompanhamento nutricional escopado por vínculo Coach (`linkId`).
/// Aluno e nutricionista compartilham o mesmo documento Firestore; o store espelha localmente por vínculo.
@MainActor
final class NutritionCareStore: ObservableObject {
    static let shared = NutritionCareStore()

    /// Vínculo em foco na UI (ficha do nutri ou aba Acompanhar).
    @Published private(set) var activeLinkId: String?
    @Published private(set) var bundle: NutritionCareBundle = .empty
    @Published private(set) var lastSyncMessage: String?

    private var boundUserId: String?
    private var bundlesByLinkId: [String: NutritionCareBundle] = [:]

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private enum ScopedKey {
        static func care(linkId: String) -> String { "nutritionCare.bundle.v2.\(linkId)" }
        /// Migração do blob único antigo.
        static let legacyCare = "nutritionCare.bundle.v1"
    }

    func bind(userId: String?) {
        guard boundUserId != userId else { return }
        boundUserId = userId
        bundlesByLinkId = [:]
        if activeLinkId != nil {
            reloadActiveFromDisk()
        } else {
            bundle = .empty
        }
    }

    /// Define o vínculo ativo (aluno: link do nutri; coach: ficha do aluno).
    func focus(linkId: String?) {
        if activeLinkId == linkId, linkId != nil, bundlesByLinkId[linkId!] != nil {
            bundle = bundlesByLinkId[linkId!] ?? bundle
            return
        }
        activeLinkId = linkId
        guard let linkId else {
            bundle = .empty
            return
        }
        if let cached = bundlesByLinkId[linkId] {
            bundle = cached
            return
        }
        if let disk = loadLocal(linkId: linkId) {
            bundlesByLinkId[linkId] = disk
            bundle = disk
            return
        }
        // Migra dados locais antigos (sem link) para o primeiro vínculo do aluno.
        if let legacy = loadLegacyLocal() {
            bundlesByLinkId[linkId] = legacy
            bundle = legacy
            persistLocal(linkId: linkId, bundle: legacy)
            clearLegacyLocal()
            return
        }
        bundlesByLinkId[linkId] = .empty
        bundle = .empty
    }

    func bundle(for linkId: String) -> NutritionCareBundle {
        if let cached = bundlesByLinkId[linkId] { return cached }
        if let disk = loadLocal(linkId: linkId) {
            bundlesByLinkId[linkId] = disk
            return disk
        }
        return .empty
    }

    // MARK: - Mutations (sempre no vínculo ativo)

    func saveAnamnesis(_ anamnesis: NutritionAnamnesis, actorUid: String?, actorName: String?) {
        var next = anamnesis
        next.updatedAt = .now
        next.lastUpdatedByUid = actorUid
        next.lastUpdatedByName = actorName
        mutateActive { $0.anamnesis = next }
    }

    func upsertQuestionnaire(_ response: NutritionQuestionnaireResponse) {
        mutateActive { current in
            var list = current.questionnaires
            if let idx = list.firstIndex(where: { $0.kindRaw == response.kindRaw }) {
                list[idx] = response
            } else {
                list.append(response)
            }
            current.questionnaires = list
        }
    }

    func response(for kind: NutritionQuestionnaireKind) -> NutritionQuestionnaireResponse {
        bundle.questionnaires.first(where: { $0.kind == kind }) ?? .blank(kind: kind)
    }

    func addGoal(_ goal: NutritionGoal) {
        mutateActive { $0.goals.insert(goal, at: 0) }
    }

    func updateGoal(_ goal: NutritionGoal) {
        mutateActive { current in
            guard let idx = current.goals.firstIndex(where: { $0.id == goal.id }) else { return }
            var copy = goal
            copy.updatedAt = .now
            current.goals[idx] = copy
        }
    }

    func deleteGoal(id: UUID) {
        mutateActive { $0.goals.removeAll { $0.id == id } }
    }

    func addCheckIn(_ checkIn: NutritionCheckIn) {
        mutateActive { current in
            current.checkIns.insert(checkIn, at: 0)
            if current.checkIns.count > 90 {
                current.checkIns = Array(current.checkIns.prefix(90))
            }
        }
    }

    func markGoalsSyncedWithCoach() {
        mutateActive { current in
            current.goals = current.goals.map { goal in
                var g = goal
                g.syncedWithCoach = true
                g.updatedAt = .now
                return g
            }
        }
    }

    // MARK: - Sync

    func applyRemote(linkId: String, remote: NutritionCareBundle) {
        let current = bundlesByLinkId[linkId] ?? loadLocal(linkId: linkId) ?? .empty
        guard remote.updatedAt > current.updatedAt else {
            if bundlesByLinkId[linkId] == nil {
                bundlesByLinkId[linkId] = current
            }
            return
        }
        bundlesByLinkId[linkId] = remote
        persistLocal(linkId: linkId, bundle: remote)
        if activeLinkId == linkId {
            bundle = remote
            lastSyncMessage = "Acompanhamento sincronizado"
        }
    }

    func encodedBundleJSON(for linkId: String? = nil) throws -> [String: Any] {
        let targetId = linkId ?? activeLinkId
        let payload: NutritionCareBundle
        if let targetId {
            payload = bundlesByLinkId[targetId] ?? bundle
        } else {
            payload = bundle
        }
        let data = try encoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dict = json as? [String: Any] else {
            throw NSError(domain: "NutritionCareStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "JSON inválido"])
        }
        return dict
    }

    func decodeBundle(from dict: [String: Any]) -> NutritionCareBundle? {
        guard JSONSerialization.isValidJSONObject(dict),
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let decoded = try? decoder.decode(NutritionCareBundle.self, from: data) else {
            return nil
        }
        return decoded
    }

    // MARK: - Internals

    private func mutateActive(_ update: (inout NutritionCareBundle) -> Void) {
        guard let linkId = activeLinkId else { return }
        var current = bundlesByLinkId[linkId] ?? bundle
        update(&current)
        current.updatedAt = .now
        bundlesByLinkId[linkId] = current
        bundle = current
        persistLocal(linkId: linkId, bundle: current)
    }

    private func reloadActiveFromDisk() {
        guard let linkId = activeLinkId else {
            bundle = .empty
            return
        }
        if let disk = loadLocal(linkId: linkId) {
            bundlesByLinkId[linkId] = disk
            bundle = disk
        } else {
            bundlesByLinkId[linkId] = .empty
            bundle = .empty
        }
    }

    private func loadLocal(linkId: String) -> NutritionCareBundle? {
        guard let uid = boundUserId,
              let data = UserScopedDefaults.data(forLogicalKey: ScopedKey.care(linkId: linkId), uid: uid),
              let decoded = try? decoder.decode(NutritionCareBundle.self, from: data) else {
            return nil
        }
        return decoded
    }

    private func persistLocal(linkId: String, bundle: NutritionCareBundle) {
        guard let uid = boundUserId,
              let data = try? encoder.encode(bundle) else { return }
        UserScopedDefaults.setData(data, forLogicalKey: ScopedKey.care(linkId: linkId), uid: uid)
    }

    private func loadLegacyLocal() -> NutritionCareBundle? {
        guard let uid = boundUserId,
              let data = UserScopedDefaults.data(forLogicalKey: ScopedKey.legacyCare, uid: uid),
              let decoded = try? decoder.decode(NutritionCareBundle.self, from: data) else {
            return nil
        }
        return decoded
    }

    private func clearLegacyLocal() {
        guard let uid = boundUserId else { return }
        UserScopedDefaults.setData(nil, forLogicalKey: ScopedKey.legacyCare, uid: uid)
    }
}
