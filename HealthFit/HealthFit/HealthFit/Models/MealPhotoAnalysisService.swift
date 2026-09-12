import Combine
import Foundation

@MainActor
final class MealPhotoAnalysisService: ObservableObject {
    static let shared = MealPhotoAnalysisService()

    @Published private(set) var entries: [MealPhotoAnalysisEntry] = []
    @Published var lastError: String?
    @Published private(set) var isSaving = false
    @Published private(set) var isLoading = false

    private var boundUserId: String?
    private var didLoadFromCloud = false

    private enum ScopedKey {
        static let analyses = "meal_photo_analyses"
    }

    private init() {}

    func bind(userId: String?) {
        boundUserId = userId
        didLoadFromCloud = false
        loadLocal()
        guard userId != nil else {
            entries = []
            return
        }
    }

    func loadIfNeeded(userId: String) async {
        if boundUserId != userId {
            bind(userId: userId)
        }
        guard !didLoadFromCloud else { return }
        await syncFromCloud()
    }

    func clearAllLocalData() {
        if let uid = boundUserId {
            UserScopedDefaults.remove(logicalKey: ScopedKey.analyses, uid: uid, legacyKey: nil)
        }
        entries = []
        boundUserId = nil
        didLoadFromCloud = false
    }

    /// Persiste macros no Firebase e localmente. A foto nunca é enviada nem salva.
    func register(_ draft: MealPhotoAnalysisDraft) async -> MealPhotoAnalysisEntry? {
        guard draft.isValid else {
            lastError = "Informe o alimento e os macros antes de registrar."
            return nil
        }
        guard let userId = boundUserId else {
            lastError = "Faça login para salvar a análise no Firebase."
            return nil
        }

        isSaving = true
        lastError = nil
        defer { isSaving = false }

        var entry = draft.asEntry()
        entry.photoDiscarded = true

        entries.insert(entry, at: 0)
        persistLocal()

        do {
            try await MealPhotoAnalysisFirestoreService.save(entry, userId: userId)
        } catch {
            lastError = "Salvo no aparelho, mas falhou o envio ao Firebase. Tentaremos de novo depois."
        }
        return entry
    }

    func todayEntries(on date: Date = .now) -> [MealPhotoAnalysisEntry] {
        let key = DailyWellnessEntry.dayKey(for: date)
        return entries.filter { $0.dayKey == key }
    }

    func latestEntry(for mealType: MealType, on date: Date = .now) -> MealPhotoAnalysisEntry? {
        let key = DailyWellnessEntry.dayKey(for: date)
        return entries.first { $0.dayKey == key && $0.mealType == mealType }
    }

    private func syncFromCloud() async {
        guard let userId = boundUserId else { return }
        isLoading = true
        defer {
            isLoading = false
            didLoadFromCloud = true
        }
        do {
            let remote = try await MealPhotoAnalysisFirestoreService.fetchRecent(userId: userId)
            if !remote.isEmpty {
                entries = merge(local: entries, remote: remote)
                persistLocal()
            }
        } catch {
            // Mantém cache local se o cloud falhar.
        }
    }

    private func merge(local: [MealPhotoAnalysisEntry], remote: [MealPhotoAnalysisEntry]) -> [MealPhotoAnalysisEntry] {
        var map: [String: MealPhotoAnalysisEntry] = [:]
        for entry in local + remote {
            if let existing = map[entry.id] {
                if entry.analyzedAt > existing.analyzedAt {
                    map[entry.id] = entry
                }
            } else {
                map[entry.id] = entry
            }
        }
        return map.values.sorted { $0.analyzedAt > $1.analyzedAt }
    }

    private func loadLocal() {
        guard let data = UserScopedDefaults.data(
            forLogicalKey: ScopedKey.analyses,
            uid: boundUserId,
            legacyKey: nil
        ),
        let decoded = try? JSONDecoder().decode([MealPhotoAnalysisEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded.sorted { $0.analyzedAt > $1.analyzedAt }
    }

    private func persistLocal() {
        guard let uid = boundUserId,
              let data = try? JSONEncoder().encode(entries) else { return }
        UserScopedDefaults.setData(data, forLogicalKey: ScopedKey.analyses, uid: uid, legacyKey: nil)
    }
}
