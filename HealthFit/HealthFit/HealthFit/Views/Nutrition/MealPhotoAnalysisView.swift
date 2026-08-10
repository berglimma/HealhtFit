import SwiftUI
import UIKit

struct MealPhotoAnalysisView: View {
    @EnvironmentObject private var authService: AuthService
    @ObservedObject private var analysisService = MealPhotoAnalysisService.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedMealType: MealType = .breakfast
    @State private var previewImage: UIImage?
    @State private var draft: MealPhotoAnalysisDraft?
    @State private var analysisNote: String?
    @State private var detectedFoods: [String] = []
    @State private var isAnalyzing = false
    @State private var showPhotoSource = false
    @State private var showGallery = false
    @State private var showCamera = false
    @State private var infoMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            mealTypePicker
            photoCard
            if let draft {
                if !detectedFoods.isEmpty {
                    detectedFoodsRow
                }
                macrosCard(draft)
            }
            todayHistory
        }
        .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))
        .padding(.top, 8)
        .padding(.bottom, 24)
        .adaptiveContentWidth()
        .task {
            guard let userId = authService.currentUser?.id else { return }
            analysisService.bind(userId: userId)
            await analysisService.loadIfNeeded(userId: userId)
        }
        .confirmationDialog("Foto da refeição", isPresented: $showPhotoSource, titleVisibility: .visible) {
            if PhotoCaptureAvailability.isCameraAvailable {
                Button("Câmera") {
                    DispatchQueue.main.async { showCamera = true }
                }
            }
            Button("Galeria") {
                DispatchQueue.main.async { showGallery = true }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $showGallery) {
            LibraryImagePicker { image in
                showGallery = false
                handlePickedImage(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker { image in
                showCamera = false
                handlePickedImage(image)
            }
            .ignoresSafeArea()
        }
        .alert(
            "Aviso",
            isPresented: Binding(
                get: { infoMessage != nil || analysisService.lastError != nil },
                set: { if !$0 {
                    infoMessage = nil
                    analysisService.lastError = nil
                } }
            )
        ) {
            Button("OK", role: .cancel) {
                infoMessage = nil
                analysisService.lastError = nil
            }
        } message: {
            Text(infoMessage ?? analysisService.lastError ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Análise de refeição")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Tire ou escolha uma foto do prato. O app estima proteína, carbo e gordura; os dados vão para o Firebase e a foto é descartada.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var mealTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Refeição")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ],
                spacing: 8
            ) {
                ForEach(MealType.allCases) { meal in
                    Button {
                        selectedMealType = meal
                        if var current = draft {
                            current.mealType = meal
                            draft = current
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: meal.icon)
                            Text(meal.shortLabel)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(selectedMealType == meal ? AppTheme.background : AppTheme.textPrimary)
                        .background(selectedMealType == meal ? AppTheme.accent : AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    .overlay(alignment: .topTrailing) {
                        if isAnalyzing {
                            ProgressView()
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .padding(10)
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(AppTheme.cardBackground)
                    .frame(height: 140)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 28))
                                .foregroundStyle(AppTheme.accent)
                            Text("Nenhuma foto selecionada")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
            }

            Button {
                showPhotoSource = true
            } label: {
                Label(
                    previewImage == nil ? "Adicionar foto" : "Trocar foto",
                    systemImage: "camera.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isAnalyzing)

            if let analysisNote {
                Text(analysisNote)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var detectedFoodsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alimentos identificados")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            FlowFoodChips(foods: detectedFoods)
        }
    }

    private func macrosCard(_ draft: MealPhotoAnalysisDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resultado da análise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            TextField("Tipo de alimento", text: binding(\.foodLabel, draft: draft))
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                macroField(title: "Proteína (g)", value: binding(\.proteinGrams, draft: draft))
                macroField(title: "Carbo (g)", value: binding(\.carbsGrams, draft: draft))
                macroField(title: "Gordura (g)", value: binding(\.fatGrams, draft: draft))
            }

            HStack {
                Text("Calorias estimadas")
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(draft.calories) kcal")
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .font(.subheadline)

            Text("Confiança: \(Int((draft.confidence * 100).rounded()))%")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Button {
                Task { await registerAndDiscardPhoto() }
            } label: {
                if analysisService.isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Registrar e descartar foto", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: draft.isValid && !analysisService.isSaving))
            .disabled(!draft.isValid || analysisService.isSaving)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func macroField(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            TextField(title, value: value, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity)
    }

    private var todayHistory: some View {
        let today = analysisService.todayEntries()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Registros de hoje")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if today.isEmpty {
                Text("Nenhuma análise registrada hoje.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(today) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: entry.mealType.icon)
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.mealType.shortLabel) · \(entry.foodLabel)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("P \(entry.proteinGrams)g · C \(entry.carbsGrams)g · G \(entry.fatGrams)g · \(entry.calories) kcal")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Foto descartada · salvo no Firebase")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.85))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Actions

    private func handlePickedImage(_ image: UIImage?) {
        guard let image else { return }
        previewImage = image
        draft = nil
        detectedFoods = []
        analysisNote = "Identificando alimentos na foto…"
        isAnalyzing = true

        Task {
            do {
                let estimate = try await MealPhotoAnalysisEngine.analyze(image: image)
                draft = MealPhotoAnalysisDraft(
                    mealType: selectedMealType,
                    foodLabel: estimate.foodLabel,
                    proteinGrams: estimate.proteinGrams,
                    carbsGrams: estimate.carbsGrams,
                    fatGrams: estimate.fatGrams,
                    calories: estimate.calories,
                    confidence: estimate.confidence
                )
                detectedFoods = estimate.detectedFoods
                analysisNote = estimate.note
            } catch {
                infoMessage = error.localizedDescription
                analysisNote = nil
                detectedFoods = []
            }
            isAnalyzing = false
        }
    }

    private func registerAndDiscardPhoto() async {
        guard var draft else { return }
        draft.mealType = selectedMealType
        draft.calories = MealPhotoAnalysisEntry.estimatedCalories(
            protein: draft.proteinGrams,
            carbs: draft.carbsGrams,
            fat: draft.fatGrams
        )
        self.draft = draft

        guard let saved = await analysisService.register(draft) else { return }

        // Descarte explícito da foto após registrar tipo + macros.
        previewImage = nil
        self.draft = nil
        detectedFoods = []
        analysisNote = "\(saved.foodLabel) registrado. Foto descartada do aparelho."
        infoMessage = "Análise salva. A foto não fica armazenada — só proteína, carbo e gordura."
    }

    private func binding(_ keyPath: WritableKeyPath<MealPhotoAnalysisDraft, String>, draft: MealPhotoAnalysisDraft) -> Binding<String> {
        Binding(
            get: { self.draft?[keyPath: keyPath] ?? draft[keyPath: keyPath] },
            set: { newValue in
                guard var current = self.draft else { return }
                current[keyPath: keyPath] = newValue
                self.draft = current
            }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<MealPhotoAnalysisDraft, Int>, draft: MealPhotoAnalysisDraft) -> Binding<Int> {
        Binding(
            get: { self.draft?[keyPath: keyPath] ?? draft[keyPath: keyPath] },
            set: { newValue in
                guard var current = self.draft else { return }
                current[keyPath: keyPath] = max(0, newValue)
                current.calories = MealPhotoAnalysisEntry.estimatedCalories(
                    protein: current.proteinGrams,
                    carbs: current.carbsGrams,
                    fat: current.fatGrams
                )
                self.draft = current
            }
        )
    }
}

/// Chips simples sem depender de Layout API nova.
private struct FlowFoodChips: View {
    let foods: [String]

    var body: some View {
        FlexibleChipWrap(items: foods)
    }
}

private struct FlexibleChipWrap: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { food in
                        Text(food)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(AppTheme.textPrimary)
                            .background(AppTheme.accent.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    /// Quebra em linhas de até ~2–3 chips por largura aproximada.
    private var rows: [[String]] {
        var result: [[String]] = []
        var current: [String] = []
        var widthBudget = 0
        for item in items {
            let cost = max(item.count, 6)
            if widthBudget + cost > 28, !current.isEmpty {
                result.append(current)
                current = [item]
                widthBudget = cost
            } else {
                current.append(item)
                widthBudget += cost
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
