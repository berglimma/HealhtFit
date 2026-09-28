import Photos
import UIKit

/// Salva imagens (e vídeos curtos) na Galeria do iPhone com permissão `.addOnly`.
enum PhotoLibrarySaver {
    enum SaveError: LocalizedError {
        case permissionDenied
        case empty
        case videoFailed
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Permissão negada para salvar em Fotos. Ative em Ajustes → HealthFit → Fotos."
            case .empty:
                return "Nenhuma imagem para salvar."
            case .videoFailed:
                return "Não foi possível salvar o vídeo na Galeria."
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
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SaveError.underlying(
                NSError(
                    domain: "PhotoLibrarySaver",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Arquivo de vídeo não encontrado."]
                )
            )
        }
        // Cópia estável: o arquivo temporário pode sumir durante o performChanges.
        let stableURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("healthfit-save-\(UUID().uuidString).mp4")
        do {
            try FileManager.default.copyItem(at: fileURL, to: stableURL)
        } catch {
            throw SaveError.underlying(error)
        }
        defer { try? FileManager.default.removeItem(at: stableURL) }

        final class Flag: @unchecked Sendable { var ok = false }
        let flag = Flag()
        do {
            try await PHPhotoLibrary.shared().performChanges {
                flag.ok = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: stableURL) != nil
            }
        } catch {
            throw SaveError.underlying(error)
        }
        guard flag.ok else { throw SaveError.videoFailed }
    }
}
