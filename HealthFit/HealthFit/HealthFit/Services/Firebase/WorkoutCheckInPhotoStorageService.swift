import FirebaseStorage
import Foundation

/// Fotos do card Constância (check-in de treino) — sincroniza iPhone ↔ iPad.
enum WorkoutCheckInPhotoStorageService {
    private static var storage: Storage { Storage.storage() }

    static var isAvailable: Bool {
        FirebaseBootstrap.isConfigured
    }

    static func photoPath(userId: String, sessionId: UUID) -> String {
        "users/\(userId)/workoutCheckIn/\(sessionId.uuidString.lowercased()).jpg"
    }

    static func uploadJPEG(data: Data, userId: String, sessionId: UUID) async throws -> String {
        guard isAvailable else {
            throw WorkoutCheckInPhotoStorageError.firebaseUnavailable
        }
        let path = photoPath(userId: userId, sessionId: sessionId)
        let reference = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        try await putData(data, to: reference, metadata: metadata)
        return path
    }

    static func downloadData(storagePath: String) async -> Data? {
        guard isAvailable, !storagePath.isEmpty else { return nil }
        do {
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                storage.reference(withPath: storagePath).getData(maxSize: 8 * 1024 * 1024) { data, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: WorkoutCheckInPhotoStorageError.unknown)
                    }
                }
            }
        } catch {
            return nil
        }
    }

    static func deletePaths(_ paths: [String]) async {
        guard isAvailable else { return }
        for path in paths where !path.isEmpty {
            let reference = storage.reference(withPath: path)
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    reference.delete { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            } catch {
                #if DEBUG
                print("[HealthFit] Falha ao apagar check-in \(path): \(error.localizedDescription)")
                #endif
            }
        }
    }

    static func deleteAllUserData(userId: String, knownPaths: [String] = []) async {
        guard isAvailable else { return }
        await deletePaths(knownPaths)
        let root = storage.reference(withPath: "users/\(userId)/workoutCheckIn")
        do {
            let listing = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageListResult, Error>) in
                root.listAll { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let result {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: WorkoutCheckInPhotoStorageError.unknown)
                    }
                }
            }
            await deletePaths(listing.items.map(\.fullPath))
        } catch {
            #if DEBUG
            print("[HealthFit] listAll workoutCheckIn: \(error.localizedDescription)")
            #endif
        }
    }

    private static func putData(
        _ data: Data,
        to reference: StorageReference,
        metadata: StorageMetadata
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.putData(data, metadata: metadata) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

enum WorkoutCheckInPhotoStorageError: LocalizedError {
    case firebaseUnavailable
    case unknown

    var errorDescription: String? {
        switch self {
        case .firebaseUnavailable:
            return "Firebase indisponível. Verifique a conexão e tente novamente."
        case .unknown:
            return "Não foi possível sincronizar a foto de constância."
        }
    }
}
