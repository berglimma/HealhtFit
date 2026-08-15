import Foundation

import Combine
@MainActor
final class ExerciseVideoRepository: ObservableObject {
    static let shared = ExerciseVideoRepository()

    @Published private(set) var isSyncing = false
    @Published private(set) var uploadSummary: ExerciseVideoUploadSummary?
    @Published private(set) var lastSyncMessage: String?

    private var videosByName: [String: ExerciseDemoVideo] = [:]
    private var keywordRules: [(keywords: [String], video: ExerciseDemoVideo)] = []
    private var muscleGroupFallbacks: [MuscleGroup: ExerciseDemoVideo] = [:]
    private var playbackURLs: [String: URL] = [:]
    private var hasLoadedRemoteCatalog = false
    private var didApplyLocalCatalog = false

    /// Evita re-leitura remota a cada foreground (custo Firestore em escala).
    private static let remoteOverlayDayKey = "healthfit.exerciseVideos.remoteOverlayDay"
    private static let remoteOverlayVersionKey = "healthfit.exerciseVideos.remoteOverlayCatalogVersion"
    /// Bump quando o seed local mudar e quiser forçar um refresh remoto leve.
    private static let localCatalogVersion = 1

    private init() {
        // Local catalog is applied lazily on first lookup / remote bootstrap.
    }

    /// Startup/foreground: usa catálogo local. Lê Firestore no máximo 1×/dia (só leitura).
    /// Nunca faz upload nem rewrite do catálogo compartilhado — isso quebrava cota em escala.
    func bootstrapRemoteCatalog() async {
        ensureLocalCatalogLoaded()

        guard ExerciseVideoFirestoreService.isAvailable else {
            lastSyncMessage = "Catálogo local ativo."
            return
        }
        guard !isSyncing else { return }
        guard shouldAttemptRemoteOverlay() else {
            lastSyncMessage = hasLoadedRemoteCatalog
                ? "Catálogo remoto em cache (hoje)."
                : "Catálogo local ativo."
            return
        }

        // Prefer a responsive first tab; remote overlay can wait.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 600_000_000)

        isSyncing = true
        defer { isSyncing = false }

        do {
            let records = try await ExerciseVideoFirestoreService.fetchAllVideos()
            if !records.isEmpty {
                applyCatalog(records: records)
                markRemoteOverlayCompleted()
                lastSyncMessage = "Catálogo remoto carregado (\(records.count) itens)."
            } else {
                // Coleção vazia: continua no bundle local. Seed só via Admin/CI ou publishAdminCatalog().
                lastSyncMessage = "Catálogo local ativo (Firestore sem seed)."
                markRemoteOverlayCompleted()
            }
        } catch {
            print("[HealthFit] Falha ao carregar vídeos do Firebase: \(error.localizedDescription)")
            applyLocalCatalog()
            lastSyncMessage = "Catálogo local ativo (falha na leitura remota)."
        }

        await resolvePlaybackURLs(for: Set(muscleGroupFallbacks.values.map(\.storagePath)))
    }

    /// Manual / admin: sobe MP4s e publica seed.
    /// Após o deploy das rules (write negado ao cliente), use Admin SDK / Console —
    /// esta rota só funciona em builds de operação com rules permissivas ou via ferramenta server-side.
    func uploadVideosToFirebase() async {
        guard ExerciseVideoFirestoreService.isAvailable else {
            lastSyncMessage = "Firebase não configurado neste build."
            return
        }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        let summary = await ExerciseVideoStorageService.uploadBundledVideosIfNeeded(force: true)
        uploadSummary = summary

        if summary.uploaded > 0 || summary.skipped > 0 {
            let published = await ExerciseVideoFirestoreService.publishSeedCatalog()
            if published, let records = try? await ExerciseVideoFirestoreService.fetchAllVideos() {
                applyCatalog(records: records)
                markRemoteOverlayCompleted()
                lastSyncMessage = summary.statusMessage
            } else {
                lastSyncMessage = "\(summary.statusMessage) Seed Firestore bloqueado para clientes — publique via Admin/Console."
            }
            await resolvePlaybackURLs(for: Set(muscleGroupFallbacks.values.map(\.storagePath)))
        } else {
            lastSyncMessage = summary.statusMessage
        }
    }

    /// Publica o seed no Firestore sem upload de Storage (Admin/CI / operação).
    func publishFirestoreSeedCatalog() async {
        guard ExerciseVideoFirestoreService.isAvailable else {
            lastSyncMessage = "Firebase não configurado neste build."
            return
        }
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let ok = await ExerciseVideoFirestoreService.publishSeedCatalog()
        lastSyncMessage = ok
            ? "Seed do catálogo publicado no Firestore."
            : "Falha ao publicar seed (rules/admin)."
        if ok, let records = try? await ExerciseVideoFirestoreService.fetchAllVideos() {
            applyCatalog(records: records)
            markRemoteOverlayCompleted()
        }
    }

    private func shouldAttemptRemoteOverlay() -> Bool {
        let defaults = UserDefaults.standard
        let today = Self.dayKey(for: .now)
        let lastDay = defaults.string(forKey: Self.remoteOverlayDayKey)
        let lastVersion = defaults.integer(forKey: Self.remoteOverlayVersionKey)
        // Já lemos (ou tentamos) hoje nesta versão do catálogo local.
        if lastDay == today, lastVersion == Self.localCatalogVersion {
            return false
        }
        return true
    }

    private func markRemoteOverlayCompleted() {
        let defaults = UserDefaults.standard
        defaults.set(Self.dayKey(for: .now), forKey: Self.remoteOverlayDayKey)
        defaults.set(Self.localCatalogVersion, forKey: Self.remoteOverlayVersionKey)
    }

    private static func dayKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    private func applyCatalog(records: [ExerciseVideoRecord]) {
        var merged = ExerciseVideoCatalog.bundledVideos()
        for record in records {
            merged[record.exerciseName] = record.demoVideo
        }

        videosByName = merged
        keywordRules = ExerciseVideoCatalog.bundledKeywordRules()
        muscleGroupFallbacks = ExerciseVideoCatalog.bundledMuscleGroupFallbacks()
        didApplyLocalCatalog = true
        hasLoadedRemoteCatalog = !records.isEmpty
    }

    func video(for exercise: Exercise) -> ExerciseDemoVideo? {
        ensureLocalCatalogLoaded()

        if let exact = videosByName[exercise.name] {
            return exact
        }

        let normalized = exercise.name.lowercased()
        for rule in keywordRules {
            if rule.keywords.contains(where: { normalized.contains($0) }) {
                return rule.video
            }
        }

        return muscleGroupFallbacks[exercise.muscleGroup]
    }

    func playbackURL(for video: ExerciseDemoVideo) async -> URL? {
        if let cached = playbackURLs[video.storagePath] {
            return cached
        }

        if let resolved = await ExerciseVideoStorageService.resolvePlaybackURL(storagePath: video.storagePath) {
            playbackURLs[video.storagePath] = resolved
            return resolved
        }

        if let group = video.fallbackMuscleGroup,
           let fallback = muscleGroupFallbacks[group] {
            return await playbackURL(for: fallback)
        }

        return nil
    }

    private func resolvePlaybackURLs(for storagePaths: Set<String>) async {
        await withTaskGroup(of: (String, URL?).self) { group in
            for path in storagePaths {
                group.addTask {
                    let url = await ExerciseVideoStorageService.resolvePlaybackURL(storagePath: path)
                    return (path, url)
                }
            }

            for await (path, url) in group {
                if let url {
                    playbackURLs[path] = url
                }
            }
        }
    }

    private func ensureLocalCatalogLoaded() {
        guard !didApplyLocalCatalog else { return }
        applyLocalCatalog()
    }

    private func applyLocalCatalog() {
        videosByName = ExerciseVideoCatalog.bundledVideos()
        keywordRules = ExerciseVideoCatalog.bundledKeywordRules()
        muscleGroupFallbacks = ExerciseVideoCatalog.bundledMuscleGroupFallbacks()
        didApplyLocalCatalog = true
    }
}
