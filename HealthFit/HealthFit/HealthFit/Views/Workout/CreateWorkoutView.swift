import SwiftUI

struct CreateWorkoutView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    private let editingSheet: WorkoutSheet?

    @State private var title = ""
    @State private var description = ""
    @State private var selectedFocusGroups: Set<CustomWorkoutFocusGroup> = [.chest]
    @State private var exercises: [Exercise] = []
    @State private var didSetInitialContent = false

    init(editingSheet: WorkoutSheet? = nil) {
        self.editingSheet = editingSheet
    }

    private var isEditing: Bool { editingSheet != nil }

    var body: some View {
        NavigationStack {
            Form {
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
                        ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                            CreateWorkoutExerciseRow(
                                index: index + 1,
                                exercise: exercise
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
                    selectedFocusGroups = inferredFocusGroups(from: sheet.exercises)
                    if selectedFocusGroups.isEmpty {
                        selectedFocusGroups = [.chest]
                    }
                } else {
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
            workoutStore.updateWorkoutSheet(existing)
        } else {
            let sheet = WorkoutSheet(
                title: title,
                description: description,
                exercises: exercises,
                isUserCreated: true
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
    let exercise: Exercise
    let onRemove: () -> Void

    private var focusLabel: String? {
        CustomWorkoutFocusGroup.focusGroup(for: exercise.name)?.rawValue
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                ExerciseExecutionGuideView(steps: exercise.executionGuide, exercise: exercise, compact: true)

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
                        if let weight = exercise.weight {
                            Text("\(Int(weight))kg")
                        }
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
