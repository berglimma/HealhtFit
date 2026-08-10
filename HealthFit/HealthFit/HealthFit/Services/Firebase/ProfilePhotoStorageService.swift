import FirebaseStorage
import Foundation
import UIKit

enum ProfilePhotoStorageService {
    private static var storage: Storage { Storage.storage() }

    static var isAvailable: Bool { FirebaseBootstrap.isConfigured }

    static func photoPath(userId: String) -> String {
        "users/\(userId)/profile/avatar.jpg"
    }

    /// Faz upload do JPEG e retorna a URL de download pública (auth).
    static func uploadJPEG(data: Data, userId: String) async throws -> URL {
        guard isAvailable else {
            throw ProfilePhotoStorageError.unavailable
        }
        let reference = storage.reference(withPath: photoPath(userId: userId))
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        try await putData(data, to: reference, metadata: metadata)
        return try await downloadURL(for: reference)
    }

    static func deletePhoto(userId: String) async throws {
        guard isAvailable else { return }
        let reference = storage.reference(withPath: photoPath(userId: userId))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.delete { error in
                if let error {
                    let ns = error as NSError
                    // Arquivo inexistente não é erro fatal.
                    if ns.domain == StorageErrorDomain, ns.code == StorageErrorCode.objectNotFound.rawValue {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// URL de download do avatar, se existir no Storage.
    static func downloadURLIfExists(userId: String) async -> String? {
        guard isAvailable else { return nil }
        let reference = storage.reference(withPath: photoPath(userId: userId))
        do {
            return try await downloadURL(for: reference).absoluteString
        } catch {
            return nil
        }
    }

    // MARK: - Foto do grupo (duo/equipe)

    static func duoTeamCoverPath(teamId: String) -> String {
        "duoTeams/\(teamId)/cover.jpg"
    }

    static func uploadDuoTeamCoverJPEG(data: Data, teamId: String) async throws -> URL {
        guard isAvailable else {
            throw ProfilePhotoStorageError.unavailable
        }
        let reference = storage.reference(withPath: duoTeamCoverPath(teamId: teamId))
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        try await putData(data, to: reference, metadata: metadata)
        return try await downloadURL(for: reference)
    }

    static func deleteDuoTeamCover(teamId: String) async throws {
        guard isAvailable else { return }
        let reference = storage.reference(withPath: duoTeamCoverPath(teamId: teamId))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.delete { error in
                if let error {
                    let ns = error as NSError
                    if ns.domain == StorageErrorDomain, ns.code == StorageErrorCode.objectNotFound.rawValue {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func downloadURL(for reference: StorageReference) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            reference.downloadURL { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ProfilePhotoStorageError.unavailable)
                }
            }
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

enum ProfilePhotoStorageError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Armazenamento de foto indisponível."
    }
}
