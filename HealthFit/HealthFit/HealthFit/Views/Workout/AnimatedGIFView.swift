import ImageIO
import SwiftUI
import UIKit

struct AnimatedGIFView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        let taskId = url.absoluteString
        context.coordinator.loadTask?.cancel()
        context.coordinator.loadTask = Task {
            guard !Task.isCancelled else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                let image = UIImage.animatedImage(withGIFData: data)
                await MainActor.run {
                    guard context.coordinator.currentTaskId == taskId else { return }
                    imageView.image = image
                }
            } catch {
                await MainActor.run {
                    guard context.coordinator.currentTaskId == taskId else { return }
                    imageView.image = nil
                }
            }
        }
        context.coordinator.currentTaskId = taskId
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var loadTask: Task<Void, Never>?
        var currentTaskId: String?

        deinit {
            loadTask?.cancel()
        }
    }
}

private extension UIImage {
    static func animatedImage(withGIFData data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }

        var images: [UIImage] = []
        var duration = 0.0

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                continue
            }
            duration += gifFrameDuration(at: index, source: source)
            images.append(UIImage(cgImage: cgImage))
        }

        guard !images.isEmpty else { return nil }
        if images.count == 1 {
            return images[0]
        }

        return UIImage.animatedImage(with: images, duration: max(duration, 0.1))
    }

    private static func gifFrameDuration(at index: Int, source: CGImageSource) -> Double {
        let key = kCGImagePropertyGIFDictionary as String
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
              let gifInfo = properties[key] as? [String: Any] else {
            return 0.1
        }

        let unclamped = gifInfo[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
        let clamped = gifInfo[kCGImagePropertyGIFDelayTime as String] as? Double
        let delay = unclamped ?? clamped ?? 0.1
        return delay > 0.01 ? delay : 0.1
    }
}
