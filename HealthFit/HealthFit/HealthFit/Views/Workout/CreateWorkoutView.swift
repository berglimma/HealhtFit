import SwiftUI

struct CreateWorkoutView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    private let editingSheet: WorkoutSheet?

    @State private var title = ""
    @State private var description = ""
    @State private var selectedMuscleGroup: MuscleGroup = .chest
    @State private var exercises: [Exercise] = []
    @State private var didSetInitialContent = false

    init(editingSheet: WorkoutSheet? = nil) {
        self.editingSheet = editingSheet
    }

    private var isEditing: Bool { editingSheet != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Grupo Muscular") {
                    Picker("Grupo", selection: $selectedMuscleGroup) {
                        ForEach(MuscleGroup.allCases) { group in
                            Label(group.rawValue, systemImage: group.icon)
                                .tag(group)
                        }
                    }
                    .pickerStyle(.menu)

                    if isEditing {
                        Text("Ao trocar o grupo, novos exercícios do catálogo são adicionados à ficha. Remova os que não quiser.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Todos os exercícios de \(selectedMuscleGroup.rawValue) são carregados automaticamente. Remova os que não quiser incluir.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Informações") {
                    TextField("Nome do treino", text: $title)
                    TextField("Descrição", text: $description)
                }

                Section {
                    if exercises.isEmpty {
                        Text("Nenhum exercício nesta ficha. Escolha outro grupo muscular.")
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
                    .disabled(title.isEmpty || exercises.isEmpty)
                }
            }
            .onAppear {
                guard !didSetInitialContent else { return }
                didSetInitialContent = true

                if let sheet = editingSheet {
                    title = sheet.title
                    description = sheet.description
                    exercises = sheet.exercises
                    selectedMuscleGroup = sheet.exercises.first?.muscleGroup ?? .chest
                } else {
                    loadExercises(for: selectedMuscleGroup)
                    if title.isEmpty {
                        title = "Treino - \(selectedMuscleGroup.rawValue)"
                    }
                    if description.isEmpty {
                        description = "Ficha personalizada de \(selectedMuscleGroup.rawValue.lowercased())"
                    }
                }
            }
            .onChange(of: selectedMuscleGroup) { _, newGroup in
                if isEditing {
                    appendExercises(from: newGroup)
                } else {
                    loadExercises(for: newGroup)
                }
            }
        }
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

    private func loadExercises(for group: MuscleGroup) {
        exercises = WorkoutStore.presetExercises(for: group).map {
            WorkoutStore.copyExerciseForWorkout($0)
        }
    }

    private func appendExercises(from group: MuscleGroup) {
        let existingNames = Set(exercises.map(\.name))
        let additions = WorkoutStore.presetExercises(for: group)
            .filter { !existingNames.contains($0.name) }
            .map { WorkoutStore.copyExerciseForWorkout($0) }
        exercises.append(contentsOf: additions)
    }

    private func removeExercise(_ exercise: Exercise) {
        exercises.removeAll { $0.id == exercise.id }
    }
}

private struct CreateWorkoutExerciseRow: View {
    let index: Int
    let exercise: Exercise
    let onRemove: () -> Void

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
