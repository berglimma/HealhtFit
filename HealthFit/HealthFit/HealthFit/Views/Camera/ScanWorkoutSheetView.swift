import SwiftUI
import UniformTypeIdentifiers
import VisionKit

/// Fluxo: câmera / foto / PDF-JPEG-PNG → OCR → revisão → salva em Personalizados.
struct ScanWorkoutSheetView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    let targetGender: Gender

    @State private var phase: Phase = .chooseSource
    @State private var title = ""
    @State private var descriptionText = ""
    @State private var exercises: [Exercise] = []
    @State private var errorMessage: String?
    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false

    private enum Phase {
        case chooseSource
        case processing
        case review
        case failed
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                    if phase == .review {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Salvar") { saveSheet() }
                                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || exercises.isEmpty)
                        }
                    }
                }
                .fullScreenCover(isPresented: $showScanner) {
                    documentScannerCover
                }
                .fullScreenCover(isPresented: $showPhotoPicker) {
                    LibraryImagePicker { image in
                        showPhotoPicker = false
                        guard let image else { return }
                        Task { await processImages([image], source: .photo) }
                    }
                    .ignoresSafeArea()
                }
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: WorkoutSheetOCRParser.supportedFileContentTypes,
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        Task { await processFile(at: url) }
                    case .failure(let error):
                        phase = .failed
                        errorMessage = error.localizedDescription
                    }
                }
                .onAppear {
                    workoutStore.setFullscreenCameraPresented(true)
                }
                .onDisappear {
                    workoutStore.setFullscreenCameraPresented(false)
                }
        }
    }

    @ViewBuilder
    private var documentScannerCover: some View {
        if VNDocumentCameraViewController.isSupported {
            WorkoutSheetDocumentScanner(
                onFinish: { images in
                    showScanner = false
                    Task { await processImages(images, source: .camera) }
                },
                onCancel: {
                    showScanner = false
                }
            )
            .ignoresSafeArea()
        } else {
            VStack(spacing: 16) {
                Text(WorkoutSheetScanError.cameraUnavailable.localizedDescription)
                Button("Fechar") { showScanner = false }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .chooseSource:
            sourceChooser
        case .processing:
            VStack(spacing: 16) {
                ProgressView()
                Text("Lendo a ficha…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            VStack(spacing: 20) {
                ContentUnavailableView(
                    "Não foi possível ler a ficha",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(errorMessage ?? WorkoutSheetScanError.noExercisesFound.localizedDescription)
                )
                Button("Escolher outra origem") {
                    errorMessage = nil
                    phase = .chooseSource
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        case .review:
            Form {
                Section {
                    LabeledContent("Programa", value: targetGender == .female ? "Feminino" : "Masculino")
                } header: {
                    Text("Destino")
                } footer: {
                    Text("A ficha será salva em Personalizados deste programa.")
                }

                Section("Informações") {
                    TextField("Nome do treino", text: $title)
                    TextField("Descrição", text: $descriptionText)
                }

                Section {
                    if exercises.isEmpty {
                        Text("Nenhum exercício reconhecido. Importe novamente.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($exercises) { $exercise in
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Exercício", text: $exercise.name)
                                HStack {
                                    Stepper("Séries: \(exercise.sets)", value: $exercise.sets, in: 1...10)
                                    Stepper("Reps: \(exercise.reps)", value: $exercise.reps, in: 1...50)
                                }
                                .font(.caption)
                            }
                        }
                        .onDelete { exercises.remove(atOffsets: $0) }
                    }
                } header: {
                    Text("Exercícios (\(exercises.count))")
                } footer: {
                    Text("Revise os nomes e volumes antes de salvar. Você poderá editar depois em Personalizados.")
                }

                Section {
                    Button("Importar de novo") {
                        phase = .chooseSource
                    }
                }
            }
        }
    }

    private var sourceChooser: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Como deseja importar a ficha?")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Use a câmera, uma foto/print da galeria ou um arquivo PDF, JPEG ou PNG. Depois revise e salve em Personalizados.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            sourceButton(
                title: "Escanear com a câmera",
                subtitle: "Fotografe a ficha de treino impressa",
                systemImage: "doc.text.viewfinder",
                enabled: VNDocumentCameraViewController.isSupported
            ) {
                openCameraScanner()
            }

            sourceButton(
                title: "Escolher foto ou print",
                subtitle: "JPEG ou PNG da galeria",
                systemImage: "photo.on.rectangle"
            ) {
                showPhotoPicker = true
            }

            sourceButton(
                title: "Importar arquivo",
                subtitle: "PDF, JPEG ou PNG dos Arquivos",
                systemImage: "folder"
            ) {
                showFileImporter = true
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func sourceButton(
        title: String,
        subtitle: String,
        systemImage: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var navigationTitle: String {
        switch phase {
        case .review: return "Revisar ficha"
        case .chooseSource: return "Importar ficha"
        case .failed: return "Importar ficha"
        case .processing: return "Lendo ficha"
        }
    }

    private func openCameraScanner() {
        errorMessage = nil
        guard VNDocumentCameraViewController.isSupported else {
            phase = .failed
            errorMessage = WorkoutSheetScanError.cameraUnavailable.localizedDescription
            return
        }
        showScanner = true
    }

    @MainActor
    private func processFile(at url: URL) async {
        phase = .processing
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let images = try WorkoutSheetOCRParser.images(fromFileURL: url)
            await processImages(images, source: .file)
        } catch {
            phase = .failed
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func processImages(_ images: [UIImage], source: WorkoutSheetImportSource) async {
        phase = .processing
        do {
            let text = try await WorkoutSheetOCRParser.recognizeText(in: images)
            let draft = WorkoutSheetOCRParser.parse(text, source: source)
            guard !draft.exercises.isEmpty else {
                throw WorkoutSheetScanError.noExercisesFound
            }
            title = draft.title
            descriptionText = draft.description
            exercises = draft.exercises
            phase = .review
        } catch {
            phase = .failed
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func saveSheet() {
        let sheet = WorkoutSheet(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            exercises: exercises,
            isUserCreated: true,
            targetGender: targetGender
        )
        workoutStore.addWorkoutSheet(sheet)
        dismiss()
    }
}
