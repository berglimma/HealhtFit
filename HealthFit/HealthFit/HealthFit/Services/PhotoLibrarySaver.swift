import Photos
import UIKit

/// Salva imagens (e vídeos curtos) na Galeria do iPhone com permissão `.addOnly`.
enum PhotoLibrarySaver {
    enum SaveError: LocalizedError {
        case permissionDenied
        case empty
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Permissão negada para salvar em Fotos. Ative em Ajustes → HealthFit → Fotos."
            case .empty:
                return "Nenhuma imagem para salvar."
            case .underlying(let error):
                return error.localizedDescription
            }
        }
    }

    @MainActor
    static func saveImage(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw SaveError.permissionDenied
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        } catch {
            throw SaveError.underlying(error)
        }
    }

    @MainActor
    static func saveImages(_ images: [UIImage]) async throws {
        let valid = images.filter { $0.size.width > 0 && $0.size.height > 0 }
        guard !valid.isEmpty else { throw SaveError.empty }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw SaveError.permissionDenied
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for image in valid {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            }
        } catch {
            throw SaveError.underlying(error)
        }
    }

    @MainActor
    static func saveVideo(at fileURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw SaveError.permissionDenied
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            }
        } catch {
            throw SaveError.underlying(error)
        }
    }
}
