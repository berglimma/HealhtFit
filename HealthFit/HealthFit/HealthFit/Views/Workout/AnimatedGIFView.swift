import ImageIO
import SwiftUI
import UIKit

struct AnimatedGIFView: UIViewRepresentable {
    let url: URL
    @Binding var loadState: ExerciseGifLoadState
    var contentMode: UIView.ContentMode = .scaleAspectFit

    func makeUIView(context: Context) -> GIFContainerView {
        let view = GIFContainerView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ container: GIFContainerView, context: Context) {
        container.imageView.contentMode = contentMode

        let taskId = url.absoluteString

        if context.coordinator.loadedTaskId == taskId, let image = context.coordinator.loadedImage {
            container.setImage(image)
            if loadState != .loaded {
                loadState = .loaded
            }
            return
        }

        guard context.coordinator.currentTaskId != taskId else { return }

        context.coordinator.loadTask?.cancel()
        context.coordinator.currentTaskId = taskId
        context.coordinator.loadedTaskId = nil
        context.coordinator.loadedImage = nil
        loadState = .loading

        context.coordinator.loadTask = Task {
            do {
                let data = try await loadData(from: url)
                guard !Task.isCancelled else { return }

                let image = UIImage.animatedImage(withGIFData: data)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard context.coordinator.currentTaskId == taskId else { return }
                    context.coordinator.loadedTaskId = taskId
                    context.coordinator.loadedImage = image
                    container.setImage(image)
                    loadState = image == nil ? .failed : .loaded
                }
            } catch {
                await MainActor.run {
                    guard context.coordinator.currentTaskId == taskId else { return }
                    container.setImage(nil)
                    loadState = .failed
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var loadTask: Task<Void, Never>?
        var currentTaskId: String?
        var loadedTaskId: String?
        var loadedImage: UIImage?

        deinit {
            loadTask?.cancel()
        }
    }

    private func loadData(from url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }

        if let cached = ExerciseGifCache.shared.data(for: url) {
            return cached
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        ExerciseGifCache.shared.store(data, for: url)
        return data
    }
}

enum ExerciseGifLoadState {
    case loading
    case loaded
    case failed
}

final class GIFContainerView: UIView {
    let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setImage(_ image: UIImage?) {
        imageView.stopAnimating()
        imageView.image = image
        if image?.images != nil {
            imageView.animationRepeatCount = 0
            imageView.startAnimating()
        }
    }
}

private final class ExerciseGifCache {
    static let shared = ExerciseGifCache()

    private let cache = NSCache<NSURL, NSData>()

    private init() {
        cache.countLimit = 80
    }

    func data(for url: URL) -> Data? {
        cache.object(forKey: url as NSURL) as Data?
    }

    func store(_ data: Data, for url: URL) {
        cache.setObject(data as NSData, forKey: url as NSURL)
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
