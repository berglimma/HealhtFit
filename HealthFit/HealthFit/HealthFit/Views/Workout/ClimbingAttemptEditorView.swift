import SwiftUI

/// Registro de uma via durante a sessão de escalada.
struct ClimbingAttemptEditorView: View {
    let setup: ClimbingSetup
    let onSave: (ClimbingAttempt) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var routeName = ""
    @State private var discipline: ClimbingDiscipline
    @State private var gradeSystem: ClimbingGradeSystem
    @State private var gradeLabel: String
    @State private var style: ClimbingAscentStyle = .redpoint
    @State private var falls = 0
    @State private var notes = ""

    init(setup: ClimbingSetup, onSave: @escaping (ClimbingAttempt) -> Void) {
        self.setup = setup
        self.onSave = onSave
        _discipline = State(initialValue: setup.discipline)
        _gradeSystem = State(initialValue: setup.gradeSystem)
        _gradeLabel = State(
            initialValue: setup.targetGrade?.label
                ?? ClimbingGrade.defaultGrade(for: setup.discipline).label
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Via") {
                    TextField("Nome da via", text: $routeName)

                    Picker("Tipo", selection: $discipline) {
                        ForEach(ClimbingDiscipline.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                }

                Section("Grau") {
                    Picker("Sistema", selection: $gradeSystem) {
                        ForEach(ClimbingGradeSystem.allCases) { system in
                            Text(system.rawValue).tag(system)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: gradeSystem) { _, newValue in
                        // A escala muda junto com o sistema; volta para um grau válido.
                        if !newValue.ladder.contains(gradeLabel) {
                            gradeLabel = ClimbingGrade.defaultGrade(for: discipline).label
                        }
                    }

                    Picker("Grau", selection: $gradeLabel) {
                        ForEach(gradeSystem.ladder, id: \.self) { label in
                            Text(label).tag(label)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 110)
                }

                Section("Resultado") {
                    Picker("Estilo", selection: $style) {
                        ForEach(ClimbingAscentStyle.allCases) { item in
                            Label(item.rawValue, systemImage: item.icon).tag(item)
                        }
                    }
                    Stepper("Quedas: \(falls)", value: $falls, in: 0...50)
                    Text(styleHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Observações") {
                    TextField("Beta, sensação, condição da rocha…", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Registrar via")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                }
            }
        }
    }

    private var styleHint: String {
        switch style {
        case .onsight: return "Encadenou de primeira, sem informação prévia da via."
        case .flash: return "Encadenou de primeira, mas já tinha o beta."
        case .redpoint: return "Encadenou depois de trabalhar a via."
        case .topRope: return "Subiu com a corda por cima."
        case .failed: return "Não completou — conta na taxa de sucesso como tentativa."
        }
    }

    private func save() {
        // Onsight e flash não admitem queda por definição.
        let resolvedFalls = style == .onsight || style == .flash ? 0 : falls

        onSave(
            ClimbingAttempt(
                routeName: routeName,
                discipline: discipline,
                grade: ClimbingGrade(system: gradeSystem, label: gradeLabel),
                style: style,
                falls: resolvedFalls,
                notes: notes
            )
        )
        dismiss()
    }
}
