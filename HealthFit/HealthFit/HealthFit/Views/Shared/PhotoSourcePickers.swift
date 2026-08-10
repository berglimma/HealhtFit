import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum PhotoCaptureAvailability {
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    static var isVideoCameraAvailable: Bool {
        guard isCameraAvailable else { return false }
        let types = UIImagePickerController.availableMediaTypes(for: .camera) ?? []
        return types.contains(where: { $0 == UTType.movie.identifier || $0 == "public.movie" })
    }
}

/// PHPicker nativo — abre rápido e evita travamentos do PhotosPicker dentro de List.
struct LibraryImagePicker: UIViewControllerRepresentable {
    var onPick: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .compatible

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage?) -> Void

        init(onPick: @escaping (UIImage?) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                DispatchQueue.main.async { self.onPick(nil) }
                return
            }

            let onPick = self.onPick
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let image = object as? UIImage {
                        DispatchQueue.main.async { onPick(image) }
                    } else {
                        Self.loadImageData(from: provider, onPick: onPick)
                    }
                }
            } else {
                Self.loadImageData(from: provider, onPick: onPick)
            }
        }

        private static func loadImageData(
            from provider: NSItemProvider,
            onPick: @escaping (UIImage?) -> Void
        ) {
            let typeIds = [UTType.image.identifier, UTType.jpeg.identifier, UTType.heic.identifier, UTType.png.identifier]
            guard let typeId = typeIds.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
                DispatchQueue.main.async { onPick(nil) }
                return
            }
            provider.loadDataRepresentation(forTypeIdentifier: typeId) { data, _ in
                let image = data.flatMap(UIImage.init(data:))
                DispatchQueue.main.async { onPick(image) }
            }
        }
    }
}

/// Câmera via UIImagePickerController (indisponível no Simulator sem hardware).
struct CameraImagePicker: UIViewControllerRepresentable {
    var onPick: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (UIImage?) -> Void

        init(onPick: @escaping (UIImage?) -> Void) {
            self.onPick = onPick
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onPick(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            onPick(image)
        }
    }
}

/// PHPicker de vídeo da galeria — grava cópia temporária para compartilhar.
struct LibraryVideoPicker: UIViewControllerRepresentable {
    var onPick: (URL?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .videos
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (URL?) -> Void

        init(onPick: @escaping (URL?) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                DispatchQueue.main.async { self.onPick(nil) }
                return
            }

            let movieType = UTType.movie.identifier
            guard provider.hasItemConformingToTypeIdentifier(movieType) else {
                DispatchQueue.main.async { self.onPick(nil) }
                return
            }

            let onPick = self.onPick
            provider.loadFileRepresentation(forTypeIdentifier: movieType) { url, _ in
                guard let url else {
                    DispatchQueue.main.async { onPick(nil) }
                    return
                }
                let copied = Self.copyToTemporaryURL(source: url)
                DispatchQueue.main.async { onPick(copied) }
            }
        }

        private static func copyToTemporaryURL(source: URL) -> URL? {
            let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("HealthFitWorkout-\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.copyItem(at: source, to: dest)
                return dest
            } catch {
                return nil
            }
        }
    }
}

/// Câmera em modo vídeo (quando o hardware permite).
struct CameraVideoPicker: UIViewControllerRepresentable {
    var onPick: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.movie.identifier]
        picker.videoQuality = .typeHigh
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (URL?) -> Void

        init(onPick: @escaping (URL?) -> Void) {
            self.onPick = onPick
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onPick(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let source = info[.mediaURL] as? URL else {
                onPick(nil)
                return
            }
            let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("HealthFitWorkout-\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.copyItem(at: source, to: dest)
                onPick(dest)
            } catch {
                onPick(source)
            }
        }
    }
}
