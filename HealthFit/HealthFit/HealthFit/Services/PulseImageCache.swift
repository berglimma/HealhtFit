import Foundation
import UIKit
import ImageIO
import SwiftUI

/// Cache de thumbs do Pulse — decode off-main para não travar o scroll.
actor PulseImageCache {
    static let shared = PulseImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let thumbMaxPixel: CGFloat = 720

    init() {
        memory.countLimit = 80
        memory.totalCostLimit = 40 * 1024 * 1024
    }

    func thumbnail(filePath: String) async -> UIImage? {
        let key = filePath as NSString
        if let cached = memory.object(forKey: key) { return cached }
        guard let image = Self.decodeThumbnail(path: filePath, maxPixel: thumbMaxPixel) else { return nil }
        memory.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        return image
    }

    func memoryCached(filePath: String) -> UIImage? {
        memory.object(forKey: filePath as NSString)
    }

    func store(_ image: UIImage, filePath: String) {
        memory.setObject(image, forKey: filePath as NSString, cost: Int(image.size.width * image.size.height * 4))
    }

    func clear() {
        memory.removeAllObjects()
    }

    nonisolated private static func decodeThumbnail(path: String, maxPixel: CGFloat) -> UIImage? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return UIImage(contentsOfFile: path)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(contentsOfFile: path)
        }
        return UIImage(cgImage: cgImage)
    }
}

/// Thumb assíncrono para cards do feed (evita `UIImage(contentsOfFile:)` no body).
struct PulseCachedAsyncImage: View {
    let filePath: String?
    var contentMode: ContentMode = .fill
    var placeholder: AnyView = AnyView(Color.white.opacity(0.06))

    @State private var image: UIImage?

    private var aspectRatio: CGFloat {
        guard let image, image.size.height > 1 else { return 1 }
        return image.size.width / image.size.height
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(aspectRatio, contentMode: contentMode)
            } else {
                placeholder
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .task(id: filePath) {
            guard let filePath, !filePath.isEmpty else {
                image = nil
                return
            }
            if let mem = await PulseImageCache.shared.memoryCached(filePath: filePath) {
                image = mem
                return
            }
            image = await PulseImageCache.shared.thumbnail(filePath: filePath)
        }
    }
}
