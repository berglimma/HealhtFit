import ImageIO
import Photos
import SwiftUI
import UIKit

struct BodyEvolutionView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var evolutionService: BodyEvolutionService
    @State private var draftImages: [BodyPhotoSlot: UIImage] = [:]
    @State private var photoSourceSlot: BodyPhotoSlot?
    @State private var galleryPickerSlot: BodyPhotoSlot?
    @State private var cameraPickerSlot: BodyPhotoSlot?
    @State private var loadingSlots: Set<BodyPhotoSlot> = []
    @State private var showResult: BodyEvolutionComparisonResult?
    @State private var infoMessage: String?
    @State private var sharePDFURL: URL?
    @State private var showSavePDFPrompt = false
    @State private var pendingHistoryPDF: BodyEvolutionEvaluation?

    var body: some View {
        // ScrollView (não List): Buttons dentro de List exigem long-press no iOS.
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusSection
                photosSection
                actionsSection
                if !evolutionService.evaluations.isEmpty {
                    historySection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Evolução Corporal")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let userId = authService.currentUser?.id else { return }
            await evolutionService.loadIfNeeded(userId: userId)
            await hydrateDraftFromActiveSet(userId: userId)
        }
        .confirmationDialog(
            "Adicionar foto",
            isPresented: Binding(
                get: { photoSourceSlot != nil },
                set: { if !$0 { photoSourceSlot = nil } }
            ),
            titleVisibility: .visible
        ) {
            if PhotoCaptureAvailability.isCameraAvailable {
                Button("Câmera") {
                    let slot = photoSourceSlot
                    photoSourceSlot = nil
                    DispatchQueue.main.async { cameraPickerSlot = slot }
                }
            }
            Button("Galeria") {
                let slot = photoSourceSlot
                photoSourceSlot = nil
                DispatchQueue.main.async { galleryPickerSlot = slot }
            }
            Button("Cancelar", role: .cancel) {
                photoSourceSlot = nil
            }
        }
        .sheet(item: $galleryPickerSlot) { slot in
            LibraryImagePicker { image in
                handlePickedImage(image, for: slot)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $cameraPickerSlot) { slot in
            CameraImagePicker { image in
                handlePickedImage(image, for: slot)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $showResult) { result in
            BodyEvolutionResultView(
                result: result,
                userId: authService.currentUser?.id,
                evolutionService: evolutionService
            )
        }
        .alert(
            "Aviso",
            isPresented: Binding(
                get: { infoMessage != nil || evolutionService.lastError != nil },
                set: { if !$0 {
                    infoMessage = nil
                    evolutionService.lastError = nil
                } }
            )
        ) {
            Button("OK", role: .cancel) {
                infoMessage = nil
                evolutionService.lastError = nil
            }
        } message: {
            Text(infoMessage ?? evolutionService.lastError ?? "")
        }
        .alert("Salvar PDF?", isPresented: $showSavePDFPrompt) {
            Button("Salvar em Arquivos") {
                Task { await openPDFAfterPrompt() }
            }
            Button("Agora não", role: .cancel) {
                pendingHistoryPDF = nil
            }
        } message: {
            Text("Deseja salvar este PDF de medidas em Arquivos (ou compartilhar)? O arquivo fica só no seu dispositivo se você escolher Arquivos.")
        }
        .sheet(isPresented: Binding(
            get: { sharePDFURL != nil },
            set: { if !$0 { sharePDFURL = nil } }
        )) {
            if let sharePDFURL {
                ShareSheet(items: [sharePDFURL])
            }
        }
    }

    private var statusSection: some View {
        evolutionCard(title: "Status") {
            Text(evolutionService.meta.statusLabel)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            Text("O laudo usa as medidas do Perfil. As fotos abaixo são opcionais e reforçam o antes/depois.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Label(
                "\(draftFilledCount)/6 fotos (opcional)",
                systemImage: "photo.on.rectangle.angled"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fotos (opcional e privado)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { col in
                            let index = row * 3 + col
                            if BodyPhotoSlot.allCases.indices.contains(index) {
                                photoCell(BodyPhotoSlot.allCases[index])
                            }
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text(
                """
                Como adicionar: toque em cada ângulo (até 6). É opcional e privado — só você vê.
                Fluxo: salve o lote inicial → aguarde 30 dias → adicione um novo lote e compare.
                Depois da comparação, as fotos antigas são excluídas. Você pode salvar uma cópia em Fotos ou Arquivos. Os PDFs das 4 últimas avaliações ficam na sua conta.
                """
            )
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func photoCell(_ slot: BodyPhotoSlot) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Button {
                    presentPhotoSource(for: slot)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.background.opacity(0.85))
                            .aspectRatio(3 / 4, contentMode: .fit)

                        if let image = draftImages[slot] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else if loadingSlots.contains(slot) {
                            ProgressView()
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: slot.systemImage)
                                    .font(.title3)
                                Text("Adicionar")
                                    .font(.caption2)
                            }
                            .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                if draftImages[slot] != nil {
                    Button {
                        draftImages[slot] = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.55))
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remover foto")
                }
            }

            Text(slot.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func presentPhotoSource(for slot: BodyPhotoSlot) {
        if PhotoCaptureAvailability.isCameraAvailable {
            photoSourceSlot = slot
        } else {
            // Simulator / devices without camera: go straight to gallery.
            galleryPickerSlot = slot
        }
    }

    @MainActor
    private func handlePickedImage(_ image: UIImage?, for slot: BodyPhotoSlot) {
        galleryPickerSlot = nil
        cameraPickerSlot = nil
        guard let image else { return }

        loadingSlots.insert(slot)
        Task {
            let reduced = await Task.detached(priority: .userInitiated) {
                BodyEvolutionImageProcessing.downsampledImage(image: image, maxSide: 1200)
            }.value
            draftImages[slot] = reduced ?? image
            loadingSlots.remove(slot)
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        evolutionCard(title: "Ações") {
            switch evolutionService.cyclePhase {
            case .empty, .waiting:
                Button {
                    Task { await saveBaseline() }
                } label: {
                    actionLabel(
                        title: evolutionService.cyclePhase == .empty
                            ? "Iniciar acompanhamento"
                            : "Atualizar lote (fotos opcionais)",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .buttonStyle(.plain)
                .disabled(evolutionService.isSaving)
                .opacity(evolutionService.isSaving ? 0.5 : 1)

            case .readyToCompare:
                Button {
                    Task { await compare() }
                } label: {
                    actionLabel(
                        title: "Comparar evolução",
                        systemImage: "arrow.left.arrow.right.circle.fill"
                    )
                }
                .buttonStyle(.plain)
                .disabled(evolutionService.isSaving)
                .opacity(evolutionService.isSaving ? 0.5 : 1)

                Text("Fotos novas são opcionais. A comparação usa as medidas do Perfil; se houver fotos, o antes/depois fica só para você.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if evolutionService.isSaving {
                ProgressView("Salvando e sincronizando…")
            }
        }
    }

    private var historySection: some View {
        evolutionCard(title: "Últimas avaliações (PDF)") {
            ForEach(evolutionService.evaluations) { evaluation in
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatted(evaluation.createdAt))
                        .font(.subheadline.weight(.semibold))
                    Text(evaluation.summaryText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(3)
                    Button {
                        pendingHistoryPDF = evaluation
                        showSavePDFPrompt = true
                    } label: {
                        Label("Salvar / compartilhar PDF", systemImage: "square.and.arrow.down")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func evolutionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func actionLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var draftFilledCount: Int { draftImages.count }

    private func hydrateDraftFromActiveSet(userId: String) async {
        switch evolutionService.cyclePhase {
        case .readyToCompare:
            draftImages = [:]
        case .empty:
            break
        case .waiting:
            guard let set = evolutionService.meta.activePhotoSet else { return }
            let slots = set.photos.filter(\.hasPhoto).map(\.slot)
            let loaded: [BodyPhotoSlot: UIImage] = await Task.detached(priority: .utility) {
                var result: [BodyPhotoSlot: UIImage] = [:]
                for slot in slots {
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("BodyEvolution/\(userId)/photos/\(set.id)/\(slot.rawValue).jpg")
                    guard let data = try? Data(contentsOf: url),
                          let image = BodyEvolutionImageProcessing.downsampledImage(data: data, maxSide: 600) else {
                        continue
                    }
                    result[slot] = image
                }
                return result
            }.value
            if !loaded.isEmpty {
                draftImages = loaded
            }
        }
    }

    private func saveBaseline() async {
        guard let user = authService.currentUser else {
            infoMessage = BodyEvolutionError.missingUser.localizedDescription
            return
        }
        do {
            try await evolutionService.saveBaselinePhotos(
                userId: user.id,
                imagesBySlot: draftImages
            )
            infoMessage = "Acompanhamento iniciado. Fotos são opcionais e só você pode vê-las. Em 30 dias você poderá comparar a evolução; o IAssistente avisa quando chegar a hora."
        } catch {
            infoMessage = error.localizedDescription
        }
    }

    private func compare() async {
        guard let user = authService.currentUser else {
            infoMessage = BodyEvolutionError.missingUser.localizedDescription
            return
        }
        do {
            let result = try await evolutionService.compareWithNewPhotos(
                userId: user.id,
                athleteName: user.greetingName,
                imagesBySlot: draftImages,
                previousMeasurements: user.previousBodyMeasurements ?? user.bodyMeasurements,
                currentMeasurements: user.bodyMeasurements
            )
            draftImages = result.currentImages
            showResult = result
        } catch {
            infoMessage = error.localizedDescription
        }
    }

    private func openPDFAfterPrompt() async {
        guard let evaluation = pendingHistoryPDF else { return }
        pendingHistoryPDF = nil
        await openPDF(evaluation)
    }

    private func openPDF(_ evaluation: BodyEvolutionEvaluation) async {
        guard let userId = authService.currentUser?.id else { return }
        if let url = await evolutionService.ensureLocalPDF(userId: userId, evaluation: evaluation) {
            sharePDFURL = url
        } else {
            infoMessage = "PDF ainda não disponível. Tente novamente com conexão."
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct BodyEvolutionResultView: View {
    let result: BodyEvolutionComparisonResult
    let userId: String?
    @ObservedObject var evolutionService: BodyEvolutionService

    @Environment(\.dismiss) private var dismiss
    @State private var showSavePrompt = false
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var statusMessage: String?
    @State private var isSaving = false
    @State private var previewImage: UIImage?

    private var hasPhotos: Bool {
        !result.previousImages.isEmpty || !result.currentImages.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(result.deletionNotice)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.accentSecondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    savePromptCard

                    Text("Resumo")
                        .font(.headline)
                    Text(result.evaluation.summaryText)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    if let comparison = result.measurementComparison, !comparison.changes.isEmpty {
                        Text("Medidas que variaram")
                            .font(.headline)
                        ForEach(comparison.changes) { change in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(change.label)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(BodyMeasurements.formatCm(change.previous)) → \(BodyMeasurements.formatCm(change.current))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                Text(BodyMeasurements.formatDelta(change.delta))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(change.delta < 0 ? AppTheme.accent : AppTheme.accentSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if hasPhotos {
                        Text("Antes × Depois")
                            .font(.headline)

                        ForEach(BodyPhotoSlot.allCases) { slot in
                            let before = result.previousImages[slot]
                            let after = result.currentImages[slot]
                            if before != nil || after != nil {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(slot.title)
                                        .font(.subheadline.weight(.semibold))
                                    HStack(spacing: 8) {
                                        photoThumb(before, caption: "Antes")
                                        photoThumb(after, caption: "Depois")
                                    }
                                }
                            }
                        }
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                    }

                    if isSaving {
                        ProgressView("Salvando…")
                    }
                }
                .padding()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Resultado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .onAppear {
                showSavePrompt = true
            }
            .alert("Salvar em Fotos ou Arquivos?", isPresented: $showSavePrompt) {
                if hasPhotos {
                    Button("Salvar fotos na Galeria") {
                        Task { await savePhotosToLibrary() }
                    }
                }
                Button("Salvar em Arquivos") {
                    Task { await shareToFiles(includePhotos: hasPhotos, includePDF: true) }
                }
                Button("Agora não", role: .cancel) {}
            } message: {
                Text(savePromptMessage)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
            .fullScreenCover(isPresented: Binding(
                get: { previewImage != nil },
                set: { if !$0 { previewImage = nil } }
            )) {
                if let previewImage {
                    BodyEvolutionPhotoPreview(image: previewImage) {
                        self.previewImage = nil
                    }
                }
            }
        }
    }

    private var savePromptMessage: String {
        if hasPhotos {
            return "As fotos antigas foram removidas do app. Deseja salvar uma cópia na Galeria (Fotos) ou em Arquivos (fotos + PDF) no seu dispositivo?"
        }
        return "Deseja salvar o PDF desta avaliação em Arquivos no seu dispositivo?"
    }

    private var savePromptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Salvar cópia no dispositivo?")
                .font(.headline)
            Text(savePromptMessage)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            if hasPhotos {
                Button {
                    Task { await savePhotosToLibrary() }
                } label: {
                    Label("Salvar fotos na Galeria", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.accent.opacity(0.2))
                        .foregroundStyle(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }

            Button {
                Task { await shareToFiles(includePhotos: hasPhotos, includePDF: true) }
            } label: {
                Label(
                    hasPhotos ? "Salvar fotos + PDF em Arquivos" : "Salvar PDF em Arquivos",
                    systemImage: "folder"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppTheme.cardBackground)
                .foregroundStyle(AppTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
        }
        .padding()
        .background(AppTheme.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func photoThumb(_ image: UIImage?, caption: String) -> some View {
        VStack(spacing: 4) {
            Button {
                guard let image else { return }
                previewImage = image
            } label: {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.gray.opacity(0.25)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(image == nil)

            Text(caption)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func allResultImages() -> [(name: String, image: UIImage)] {
        var items: [(String, UIImage)] = []
        for slot in BodyPhotoSlot.allCases {
            if let before = result.previousImages[slot] {
                items.append(("antes_\(slot.rawValue)", before))
            }
            if let after = result.currentImages[slot] {
                items.append(("depois_\(slot.rawValue)", after))
            }
        }
        return items
    }

    @MainActor
    private func savePhotosToLibrary() async {
        let images = allResultImages().map(\.image)
        guard !images.isEmpty else {
            statusMessage = "Não há fotos nesta avaliação para salvar."
            return
        }

        isSaving = true
        defer { isSaving = false }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            statusMessage = "Permissão negada para salvar na Galeria. Ative em Ajustes → HealthFit → Fotos."
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                for image in images {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            }
            statusMessage = "\(images.count) foto(s) salvas na Galeria."
        } catch {
            statusMessage = "Não foi possível salvar na Galeria: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func shareToFiles(includePhotos: Bool, includePDF: Bool) async {
        isSaving = true
        defer { isSaving = false }

        var items: [Any] = []
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BodyEvolutionExport_\(result.evaluation.id)", isDirectory: true)
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        if includePhotos {
            for item in allResultImages() {
                let url = tempDir.appendingPathComponent("\(item.name).jpg")
                if let data = item.image.jpegData(compressionQuality: 0.9) {
                    try? data.write(to: url, options: .atomic)
                    items.append(url)
                }
            }
        }

        if includePDF, let userId {
            if let pdfURL = await evolutionService.ensureLocalPDF(
                userId: userId,
                evaluation: result.evaluation
            ) {
                let exported = tempDir.appendingPathComponent("evolucao_\(result.evaluation.id).pdf")
                try? FileManager.default.copyItem(at: pdfURL, to: exported)
                items.append(FileManager.default.fileExists(atPath: exported.path) ? exported : pdfURL)
            }
        }

        guard !items.isEmpty else {
            statusMessage = "Nada disponível para salvar agora."
            return
        }

        shareItems = items
        showShareSheet = true
        statusMessage = "Escolha Arquivos (ou outro app) para guardar a cópia no dispositivo."
    }
}

extension BodyEvolutionComparisonResult: Identifiable {
    var id: String { evaluation.id }
}

private struct BodyEvolutionPhotoPreview: View {
    let image: UIImage
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding()
                .onTapGesture(perform: onClose)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.35))
                    .padding()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fechar")
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum BodyEvolutionImageProcessing {
    /// Decodifica e reduz a imagem sem carregar o bitmap full-resolution na UI.
    static func downsampledImage(data: Data, maxSide: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return UIImage(data: data)
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }

    static func downsampledImage(image: UIImage, maxSide: CGFloat) -> UIImage? {
        guard let data = image.jpegData(compressionQuality: 0.92)
                ?? image.pngData() else {
            return resized(image, maxSide: maxSide)
        }
        return downsampledImage(data: data, maxSide: maxSide) ?? resized(image, maxSide: maxSide)
    }

    private static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide, longest > 0 else { return image }
        let scale = maxSide / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

