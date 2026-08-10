import SwiftUI

/// Escolha de exercício extra após concluir uma ficha recomendada.
struct AddExerciseDuringWorkoutView: View {
    @Environment(\.dismiss) private var dismiss

    let excludeNames: Set<String>
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var selectedGroup: MuscleGroup?

    private var catalog: [Exercise] {
        WorkoutStore.allCatalogExercises().filter { !excludeNames.contains($0.name) }
    }

    private var filtered: [Exercise] {
        catalog.filter { exercise in
            if let selectedGroup, exercise.muscleGroup != selectedGroup {
                return false
            }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            return exercise.name.localizedCaseInsensitiveContains(query)
                || exercise.muscleGroup.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip(title: "Todos", group: nil)
                            ForEach(MuscleGroup.allCases) { group in
                                filterChip(title: group.rawValue, group: group)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section {
                    if filtered.isEmpty {
                        Text("Nenhum exercício encontrado.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filtered) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: exercise.muscleGroup.icon)
                                        .foregroundStyle(AppTheme.accent)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text("\(exercise.sets)x\(exercise.reps) · \(exercise.muscleGroup.rawValue)")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Catálogo (\(filtered.count))")
                }
            }
            .searchable(text: $searchText, prompt: "Buscar exercício")
            .navigationTitle("Adicionar exercício")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func filterChip(title: String, group: MuscleGroup?) -> some View {
        let isSelected = selectedGroup == group
        return Button {
            selectedGroup = group
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
                .background(isSelected ? AppTheme.accent : AppTheme.cardBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
