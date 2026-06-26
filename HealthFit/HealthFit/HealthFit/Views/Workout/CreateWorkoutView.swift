import SwiftUI

struct CreateWorkoutView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var exercises: [Exercise] = []
    @State private var showAddExercise = false

    @State private var newExerciseName = ""
    @State private var newSets = 3
    @State private var newReps = 12
    @State private var newRest = 60
    @State private var newMuscleGroup: MuscleGroup = .chest

    var body: some View {
        NavigationStack {
            Form {
                Section("Informações") {
                    TextField("Nome do treino", text: $title)
                    TextField("Descrição", text: $description)
                }

                Section("Exercícios (\(exercises.count))") {
                    ForEach(exercises) { exercise in
                        VStack(alignment: .leading) {
                            Text(exercise.name).font(.headline)
                            Text("\(exercise.sets)x\(exercise.reps) • \(exercise.restSeconds)s descanso")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        exercises.remove(atOffsets: indexSet)
                    }

                    Button("Adicionar Exercício") {
                        showAddExercise = true
                    }
                }
            }
            .navigationTitle("Nova Ficha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let sheet = WorkoutSheet(
                            title: title,
                            description: description,
                            exercises: exercises
                        )
                        workoutStore.addWorkoutSheet(sheet)
                        dismiss()
                    }
                    .disabled(title.isEmpty || exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showAddExercise) {
                NavigationStack {
                    Form {
                        TextField("Nome do exercício", text: $newExerciseName)
                        Stepper("Séries: \(newSets)", value: $newSets, in: 1...10)
                        Stepper("Repetições: \(newReps)", value: $newReps, in: 1...50)
                        Stepper("Descanso: \(newRest)s", value: $newRest, in: 15...300, step: 15)
                        Picker("Grupo Muscular", selection: $newMuscleGroup) {
                            ForEach(MuscleGroup.allCases) { group in
                                Text(group.rawValue).tag(group)
                            }
                        }
                    }
                    .navigationTitle("Novo Exercício")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Adicionar") {
                                exercises.append(Exercise(
                                    name: newExerciseName,
                                    sets: newSets,
                                    reps: newReps,
                                    restSeconds: newRest,
                                    muscleGroup: newMuscleGroup
                                ))
                                newExerciseName = ""
                                showAddExercise = false
                            }
                            .disabled(newExerciseName.isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}
