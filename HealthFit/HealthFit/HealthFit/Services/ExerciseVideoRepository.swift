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

    private init() {
        // Local catalog is applied lazily on first lookup / remote bootstrap.
    }

    func bootstrapRemoteCatalog() async {
        guard ExerciseVideoFirestoreService.isAvailable else {
            ensureLocalCatalogLoaded()
            return
        }
        guard !isSyncing else { return }

        // Prefer a responsive first tab; Firebase GIF/video sync can wait.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 600_000_000)

        ensureLocalCatalogLoaded()
        isSyncing = true
        defer { isSyncing = false }

        let summary = await ExerciseVideoFirestoreService.syncCatalog()
        uploadSummary = summary
        lastSyncMessage = summary.statusMessage

        do {
            let records = try await ExerciseVideoFirestoreService.fetchAllVideos()
            applyCatalog(records: records)
        } catch {
            print("[HealthFit] Falha ao carregar vídeos do Firebase: \(error.localizedDescription)")
            applyLocalCatalog()
            lastSyncMessage = "Catálogo local ativo. \(summary.statusMessage)"
        }

        await resolvePlaybackURLs(for: Set(muscleGroupFallbacks.values.map(\.storagePath)))
    }

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
        lastSyncMessage = summary.statusMessage

        if summary.uploaded > 0 || summary.skipped > 0 {
            await ExerciseVideoFirestoreService.syncFirestoreCatalog()
            if let records = try? await ExerciseVideoFirestoreService.fetchAllVideos() {
                applyCatalog(records: records)
            }
            await resolvePlaybackURLs(for: Set(muscleGroupFallbacks.values.map(\.storagePath)))
        }
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
