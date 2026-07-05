import FirebaseAuth
import FirebaseStorage
import Foundation

struct ExerciseVideoUploadSummary: Equatable {
    let uploaded: Int
    let skipped: Int
    let failed: Int
    let missingLocal: Int

    var isSuccess: Bool { failed == 0 && (uploaded > 0 || skipped > 0) }

    var statusMessage: String {
        if uploaded > 0 {
            return "\(uploaded) vídeo(s) enviado(s) ao Firebase Storage."
        }
        if skipped > 0, failed == 0, missingLocal == 0 {
            return "Vídeos já sincronizados no Firebase (\(skipped))."
        }
        if missingLocal > 0 {
            return "Nenhum vídeo local encontrado no app."
        }
        if failed > 0 {
            return "Falha ao enviar \(failed) vídeo(s). Tente novamente logado."
        }
        return "Nenhum vídeo para sincronizar."
    }
}

actor ExerciseVideoURLCache {
    static let shared = ExerciseVideoURLCache()

    private var cache: [String: URL] = [:]

    func url(for storagePath: String) -> URL? {
        cache[storagePath]
    }

    func store(_ url: URL, for storagePath: String) {
        cache[storagePath] = url
    }
}

enum ExerciseVideoStorageService {
    private static var storage: Storage { Storage.storage() }

    static var isAvailable: Bool {
        FirebaseBootstrap.isConfigured
    }

    static func storagePath(for exerciseName: String, muscleGroup: MuscleGroup) -> String {
        let slug = ExerciseVideoRecord.slug(for: exerciseName)
        return "exerciseVideos/exercises/\(slug).mp4"
    }

    static func groupStoragePath(for muscleGroup: MuscleGroup) -> String {
        "exerciseVideos/groups/\(muscleGroup.storageSlug).mp4"
    }

    static func resolvePlaybackURL(storagePath: String) async -> URL? {
        if let cached = await ExerciseVideoURLCache.shared.url(for: storagePath) {
            return cached
        }

        guard isAvailable else { return nil }

        do {
            let url = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                storage.reference(withPath: storagePath).downloadURL { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: NSError(domain: "HealthFit", code: -1))
                    }
                }
            }
            await ExerciseVideoURLCache.shared.store(url, for: storagePath)
            return url
        } catch {
            print("[HealthFit] Vídeo não encontrado em \(storagePath): \(error.localizedDescription)")
            return nil
        }
    }

    static func uploadBundledVideosIfNeeded(force: Bool = false) async -> ExerciseVideoUploadSummary {
        guard isAvailable else {
            return ExerciseVideoUploadSummary(uploaded: 0, skipped: 0, failed: 0, missingLocal: 0)
        }

        guard await waitForAuthenticatedUser() else {
            print("[HealthFit] Upload de vídeos ignorado: usuário Firebase não autenticado.")
            return ExerciseVideoUploadSummary(uploaded: 0, skipped: 0, failed: 0, missingLocal: 0)
        }

        var uploaded = 0
        var skipped = 0
        var failed = 0
        var missingLocal = 0

        for muscleGroup in MuscleGroup.allCases {
            let storagePath = groupStoragePath(for: muscleGroup)
            let resourceName = muscleGroup.storageSlug

            guard let fileURL = Bundle.main.url(forResource: resourceName, withExtension: "mp4", subdirectory: "ExerciseVideos")
                ?? Bundle.main.url(forResource: resourceName, withExtension: "mp4") else {
                missingLocal += 1
                print("[HealthFit] Vídeo local ausente: \(resourceName).mp4")
                continue
            }

            let reference = storage.reference(withPath: storagePath)

            if !force {
                do {
                    _ = try await fetchMetadata(for: reference)
                    skipped += 1
                    continue
                } catch {
                    // Objeto ausente no Storage — segue para upload.
                }
            }

            do {
                try await uploadFile(at: fileURL, to: reference)
                uploaded += 1
                print("[HealthFit] Vídeo enviado para Firebase Storage: \(storagePath)")
            } catch {
                failed += 1
                print("[HealthFit] Falha ao enviar \(storagePath): \(error.localizedDescription)")
            }
        }

        return ExerciseVideoUploadSummary(
            uploaded: uploaded,
            skipped: skipped,
            failed: failed,
            missingLocal: missingLocal
        )
    }

    private static func waitForAuthenticatedUser(maxAttempts: Int = 25) async -> Bool {
        for _ in 0..<maxAttempts {
            if Auth.auth().currentUser != nil {
                return true
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return Auth.auth().currentUser != nil
    }

    private static func uploadFile(at fileURL: URL, to reference: StorageReference) async throws {
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.putFile(from: fileURL, metadata: metadata) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func fetchMetadata(for reference: StorageReference) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { continuation in
            reference.getMetadata { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: NSError(domain: "HealthFit", code: -1))
                }
            }
        }
    }
}

private extension MuscleGroup {
    var storageSlug: String {
        switch self {
        case .chest: return "peito"
        case .back: return "costas"
        case .legs: return "pernas"
        case .shoulders: return "ombros"
        case .arms: return "bracos"
        case .core: return "abdomen"
        case .fullBody: return "corpo_inteiro"
        }
    }
}
