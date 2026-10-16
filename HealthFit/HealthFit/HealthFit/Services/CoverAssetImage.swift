import ImageIO
import SwiftUI
import UIKit

/// Decodifica capas do Asset Catalog em thumbnail (evita bitmap full-res → jetsam).
final class CoverAssetDecoder {
    static let shared = CoverAssetDecoder()

    /// Largura típica do card (~390pt) × 3x, com folga.
    static let cardMaxPixel: CGFloat = 960

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 48
        cache.totalCostLimit = 24 * 1024 * 1024
    }

    func image(named name: String, maxPixel: CGFloat = CoverAssetDecoder.cardMaxPixel) -> UIImage? {
        let key = "\(name)#\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        guard let decoded = Self.decode(named: name, maxPixel: maxPixel) else { return nil }
        let cost = Int(decoded.size.width * decoded.size.height * decoded.scale * decoded.scale * 4)
        cache.setObject(decoded, forKey: key, cost: max(cost, 1))
        return decoded
    }

    func clear() {
        cache.removeAllObjects()
    }

    private static func decode(named name: String, maxPixel: CGFloat) -> UIImage? {
        // Preferir arquivo no bundle (imageset) via ImageIO — sem materializar full-res.
        if let url = bundleURL(forAssetNamed: name),
           let thumb = imageIOThumbnail(url: url, maxPixel: maxPixel) {
            return thumb
        }

        // Fallback: UIImage(named:) + downsample (ainda paga 1 decode; cacheia só o thumb).
        guard let full = UIImage(named: name) else { return nil }
        return downsample(full, maxPixel: maxPixel) ?? full
    }

    private static func bundleURL(forAssetNamed name: String) -> URL? {
        let exts = ["jpg", "jpeg", "png", "webp"]
        for ext in exts {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        // Paths típicos de cópia solta / resources
        for ext in exts {
            if let path = Bundle.main.path(forResource: name, ofType: ext) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private static func imageIOThumbnail(url: URL, maxPixel: CGFloat) -> UIImage? {
        let srcOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, srcOptions as CFDictionary) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }

    private static func downsample(_ image: UIImage, maxPixel: CGFloat) -> UIImage? {
        let pixelW = image.size.width * image.scale
        let pixelH = image.size.height * image.scale
        let longest = max(pixelW, pixelH)
        guard longest > maxPixel else { return image }

        let scale = maxPixel / longest
        let size = CGSize(width: max(1, pixelW * scale), height: max(1, pixelH * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

/// Capa fotográfica full-bleed com decode limitado (cards de modalidade / Coach / Constância).
struct CoverAssetImage: View {
    let name: String
    var maxPixel: CGFloat = CoverAssetDecoder.cardMaxPixel

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black.opacity(0.25)
            }
        }
        .task(id: "\(name)-\(Int(maxPixel))") {
            let decoded = await Task.detached(priority: .utility) {
                CoverAssetDecoder.shared.image(named: name, maxPixel: maxPixel)
            }.value
            image = decoded
        }
    }
}
