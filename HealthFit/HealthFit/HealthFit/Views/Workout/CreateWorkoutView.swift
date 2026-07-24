import SwiftUI

struct CreateWorkoutView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    private let editingSheet: WorkoutSheet?
    private let initialTargetGender: Gender?

    @State private var title = ""
    @State private var description = ""
    @State private var selectedFocusGroups: Set<CustomWorkoutFocusGroup> = [.chest]
    @State private var exercises: [Exercise] = []
    @State private var didSetInitialContent = false
    @State private var targetGender: Gender = .male

    init(editingSheet: WorkoutSheet? = nil, initialTargetGender: Gender? = nil) {
        self.editingSheet = editingSheet
        self.initialTargetGender = initialTargetGender
    }

    private var isEditing: Bool { editingSheet != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Perfil", selection: $targetGender) {
                        Text("Masculino").tag(Gender.male)
                        Text("Feminino").tag(Gender.female)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Perfil")
                } footer: {
                    Text(targetGender == .female
                         ? "Ficha vinculada ao programa feminino."
                         : "Ficha vinculada ao programa masculino.")
                }

                Section {
                    Text("Selecione um ou mais grupos musculares. Os exercícios do catálogo são carregados automaticamente — remova os que não quiser.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(CustomWorkoutFocusGroup.allCases) { group in
                        Toggle(isOn: focusGroupBinding(for: group)) {
                            Label(group.rawValue, systemImage: group.icon)
                        }
                    }

                    if selectedFocusGroups.isEmpty {
                        Text("Escolha pelo menos um grupo muscular.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Grupos Musculares")
                } footer: {
                    if !selectedFocusGroups.isEmpty {
                        Text(selectedGroupsSummary)
                    }
                }

                Section("Informações") {
                    TextField("Nome do treino", text: $title)
                    TextField("Descrição", text: $description)
                }

                Section {
                    if exercises.isEmpty {
                        Text("Nenhum exercício nesta ficha. Selecione ao menos um grupo muscular.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($exercises) { $exercise in
                            CreateWorkoutExerciseRow(
                                index: (exercises.firstIndex(where: { $0.id == exercise.id }) ?? 0) + 1,
                                exercise: $exercise,
                                preferredGender: targetGender
                            ) {
                                removeExercise(exercise)
                            }
                        }
                        .onDelete { indexSet in
                            exercises.remove(atOffsets: indexSet)
                        }
                    }
                } header: {
                    Text("Exercícios (\(exercises.count))")
                } footer: {
                    if !exercises.isEmpty {
                        Text("Deslize para a esquerda ou toque no ícone de lixeira para remover um exercício.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar Ficha" : "Nova Ficha")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .numericKeyboardDismiss()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        saveSheet()
                    }
                    .disabled(title.isEmpty || exercises.isEmpty || selectedFocusGroups.isEmpty)
                }
            }
            .onAppear {
                guard !didSetInitialContent else { return }
                didSetInitialContent = true

                if let sheet = editingSheet {
                    title = sheet.title
                    description = sheet.description
                    exercises = sheet.exercises
                    targetGender = sheet.targetGender ?? .male
                    selectedFocusGroups = inferredFocusGroups(from: sheet.exercises)
                    if selectedFocusGroups.isEmpty {
                        selectedFocusGroups = [.chest]
                    }
                } else {
                    targetGender = initialTargetGender ?? .male
                    reloadExercisesFromSelection()
                    updateDefaultMetadataIfNeeded()
                }
            }
        }
    }

    private var selectedGroupsSummary: String {
        let names = CustomWorkoutFocusGroup.allCases
            .filter { selectedFocusGroups.contains($0) }
            .map(\.rawValue)
            .joined(separator: ", ")
        return "Selecionados: \(names)"
    }

    private func focusGroupBinding(for group: CustomWorkoutFocusGroup) -> Binding<Bool> {
        Binding(
            get: { selectedFocusGroups.contains(group) },
            set: { isSelected in
                let previous = selectedFocusGroups
                if isSelected {
                    selectedFocusGroups.insert(group)
                } else {
                    selectedFocusGroups.remove(group)
                }
                syncExercisesAfterSelectionChange(from: previous, to: selectedFocusGroups)
                updateDefaultMetadataIfNeeded()
            }
        )
    }

    private func inferredFocusGroups(from exercises: [Exercise]) -> Set<CustomWorkoutFocusGroup> {
        Set(exercises.compactMap { WorkoutStore.focusGroup(for: $0) })
    }

    private func syncExercisesAfterSelectionChange(
        from previous: Set<CustomWorkoutFocusGroup>,
        to current: Set<CustomWorkoutFocusGroup>
    ) {
        let removed = previous.subtracting(current)
        let added = current.subtracting(previous)

        if !removed.isEmpty {
            exercises.removeAll { exercise in
                guard let focus = WorkoutStore.focusGroup(for: exercise) else { return false }
                return removed.contains(focus)
            }
        }

        for group in added {
            appendExercises(from: group)
        }

        if previous.isEmpty, !current.isEmpty, exercises.isEmpty {
            reloadExercisesFromSelection()
        }
    }

    private func reloadExercisesFromSelection() {
        exercises = WorkoutStore.presetExercises(for: selectedFocusGroups).map {
            WorkoutStore.copyExerciseForWorkout($0)
        }
    }

    private func appendExercises(from group: CustomWorkoutFocusGroup) {
        let existingNames = Set(exercises.map(\.name))
        let additions = WorkoutStore.presetExercises(for: [group])
            .filter { !existingNames.contains($0.name) }
            .map { WorkoutStore.copyExerciseForWorkout($0) }
        exercises.append(contentsOf: additions)
    }

    private func updateDefaultMetadataIfNeeded() {
        guard !isEditing else { return }

        let groupNames = CustomWorkoutFocusGroup.allCases
            .filter { selectedFocusGroups.contains($0) }
            .map(\.rawValue)

        guard !groupNames.isEmpty else { return }

        let joined = groupNames.joined(separator: ", ")
        title = "Treino - \(joined)"
        description = "Ficha personalizada de \(joined.lowercased())"
    }

    private func saveSheet() {
        if var existing = editingSheet {
            existing.title = title
            existing.description = description
            existing.exercises = exercises
            existing.targetGender = targetGender
            workoutStore.updateWorkoutSheet(existing)
        } else {
            let sheet = WorkoutSheet(
                title: title,
                description: description,
                exercises: exercises,
                isUserCreated: true,
                targetGender: targetGender
            )
            workoutStore.addWorkoutSheet(sheet)
        }
        dismiss()
    }

    private func removeExercise(_ exercise: Exercise) {
        exercises.removeAll { $0.id == exercise.id }
    }
}

private struct CreateWorkoutExerciseRow: View {
    let index: Int
    @Binding var exercise: Exercise
    var preferredGender: Gender? = nil
    let onRemove: () -> Void

    private var focusLabel: String? {
        CustomWorkoutFocusGroup.focusGroup(for: exercise.name)?.rawValue
    }

    private var recommendedWeightText: Binding<String> {
        Binding(
            get: { ExerciseLoadEditor.text(from: exercise.recommendedWeight) },
            set: { exercise.recommendedWeight = ExerciseLoadEditor.weight(from: $0) }
        )
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Carga recomendada")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        TextField("Ex: 40", text: recommendedWeightText)
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Text("kg")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                ExerciseExecutionGuideView(
                    steps: exercise.executionGuide,
                    exercise: exercise,
                    preferredGender: preferredGender,
                    compact: true
                )

                Button(role: .destructive, action: onRemove) {
                    Label("Remover da ficha", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 12) {
                Text("\(index)")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 26, height: 26)
                    .background(AppTheme.accent.opacity(0.2))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 8) {
                        if let focusLabel {
                            Text(focusLabel)
                        }
                        Text("\(exercise.sets)x\(exercise.reps)")
                        Text("Rec. \(exercise.recommendedWeightLabel)")
                        Text("\(exercise.restSeconds)s descanso")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
        .tint(AppTheme.accent)
    }
}
