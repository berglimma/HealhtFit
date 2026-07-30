import FirebaseStorage
import Foundation

enum BodyEvolutionStorageService {
    private static var storage: Storage { Storage.storage() }

    static var isAvailable: Bool {
        FirebaseBootstrap.isConfigured
    }

    static func photoPath(userId: String, setId: String, slot: BodyPhotoSlot) -> String {
        "users/\(userId)/bodyEvolution/photos/\(setId)/\(slot.rawValue).jpg"
    }

    static func pdfPath(userId: String, evaluationId: String) -> String {
        "users/\(userId)/bodyEvolution/pdfs/\(evaluationId).pdf"
    }

    static func uploadJPEG(
        data: Data,
        userId: String,
        setId: String,
        slot: BodyPhotoSlot
    ) async throws -> String {
        guard isAvailable else {
            throw BodyEvolutionError.firebaseUnavailable
        }
        let path = photoPath(userId: userId, setId: setId, slot: slot)
        let reference = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        try await putData(data, to: reference, metadata: metadata)
        return path
    }

    static func uploadPDF(data: Data, userId: String, evaluationId: String) async throws -> String {
        guard isAvailable else {
            throw BodyEvolutionError.firebaseUnavailable
        }
        let path = pdfPath(userId: userId, evaluationId: evaluationId)
        let reference = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"
        try await putData(data, to: reference, metadata: metadata)
        return path
    }

    static func downloadURL(for storagePath: String) async -> URL? {
        guard isAvailable, !storagePath.isEmpty else { return nil }
        do {
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                storage.reference(withPath: storagePath).downloadURL { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: BodyEvolutionError.unknown)
                    }
                }
            }
        } catch {
            return nil
        }
    }

    static func downloadData(storagePath: String) async -> Data? {
        guard isAvailable, !storagePath.isEmpty else { return nil }
        do {
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                storage.reference(withPath: storagePath).getData(maxSize: 15 * 1024 * 1024) { data, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: BodyEvolutionError.unknown)
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
                print("[HealthFit] Falha ao apagar \(path): \(error.localizedDescription)")
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

enum BodyEvolutionError: LocalizedError {
    case firebaseUnavailable
    case noBaseline
    case missingComparisonData
    case notEligible
    case missingUser
    case unknown

    var errorDescription: String? {
        switch self {
        case .firebaseUnavailable:
            return "Firebase indisponível. Verifique a conexão e tente novamente."
        case .noBaseline:
            return "Inicie o acompanhamento primeiro (as fotos são opcionais)."
        case .missingComparisonData:
            return "Salve medidas no Perfil ou adicione fotos opcionais para registrar a evolução."
        case .notEligible:
            return "Aguarde 30 dias após o início do ciclo para comparar a evolução."
        case .missingUser:
            return "Faça login para salvar a evolução corporal."
        case .unknown:
            return "Não foi possível concluir a operação."
        }
    }
}
