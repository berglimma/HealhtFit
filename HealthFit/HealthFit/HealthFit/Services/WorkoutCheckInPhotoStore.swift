import Foundation
import ImageIO
import UIKit

/// Armazena fotos de check-in de treino em disco (calendário estilo GymRats).
enum WorkoutCheckInPhotoStore {
    private static let folderName = "WorkoutCheckInPhotos"
    private static let maxSide: CGFloat = 1_280
    private static let jpegQuality: CGFloat = 0.82

    static func directoryURL() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func fileName(for sessionId: UUID) -> String {
        "\(sessionId.uuidString.lowercased()).jpg"
    }

    static func fileURL(for fileName: String) -> URL {
        directoryURL().appendingPathComponent(fileName)
    }

    /// Salva JPEG redimensionado e devolve o nome do arquivo.
    @discardableResult
    static func save(_ image: UIImage, sessionId: UUID) -> String? {
        let resized = downsample(image, maxSide: maxSide)
        guard let data = resized.jpegData(compressionQuality: jpegQuality) else { return nil }
        return save(data: data, sessionId: sessionId)
    }

    /// Persiste bytes JPEG já compactados (ex.: download do Storage).
    @discardableResult
    static func save(data: Data, sessionId: UUID) -> String? {
        let name = fileName(for: sessionId)
        let url = fileURL(for: name)
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            print("[HealthFit] Falha ao salvar foto de check-in: \(error.localizedDescription)")
            return nil
        }
    }

    static func jpegData(fileName: String?) -> Data? {
        guard let fileName, !fileName.isEmpty else { return nil }
        let url = fileURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func load(fileName: String?) -> UIImage? {
        guard let fileName, !fileName.isEmpty else { return nil }
        let url = fileURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return downsample(at: url, maxSide: maxSide) ?? UIImage(contentsOfFile: url.path)
    }

    static func loadThumbnail(fileName: String?, maxSide: CGFloat = 240) -> UIImage? {
        guard let fileName, !fileName.isEmpty else { return nil }
        let url = fileURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return downsample(at: url, maxSide: maxSide) ?? UIImage(contentsOfFile: url.path)
    }

    static func exists(fileName: String?) -> Bool {
        guard let fileName, !fileName.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: fileURL(for: fileName).path)
    }

    static func delete(fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: fileURL(for: fileName))
    }

    // MARK: - Downsample

    private static func downsample(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        if let data = image.jpegData(compressionQuality: 0.92) ?? image.pngData(),
           let downsampled = downsample(data: data, maxSide: maxSide) {
            return downsampled
        }
        return resizeFallback(image, maxSide: maxSide)
    }

    private static func downsample(at url: URL, maxSide: CGFloat) -> UIImage? {
        let srcOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, srcOptions as CFDictionary) else {
            return nil
        }
        return thumbnail(from: source, maxSide: maxSide)
    }

    private static func downsample(data: Data, maxSide: CGFloat) -> UIImage? {
        let srcOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, srcOptions as CFDictionary) else {
            return nil
        }
        return thumbnail(from: source, maxSide: maxSide)
    }

    private static func thumbnail(from source: CGImageSource, maxSide: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    private static func resizeFallback(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longestSide = max(pixelWidth, pixelHeight)
        guard longestSide > maxSide else { return image }

        let scaleFactor = maxSide / longestSide
        let newSize = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
