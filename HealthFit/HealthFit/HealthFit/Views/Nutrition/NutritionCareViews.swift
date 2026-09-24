import SwiftUI

/// Aba do aluno em Nutrição: questionários, anamnese, metas e check-in.
struct NutritionCareHubView: View {
    @ObservedObject private var care = NutritionCareStore.shared
    @ObservedObject private var coach = CoachService.shared
    @EnvironmentObject private var authService: AuthService

    @State private var showAnamnesis = false
    @State private var showNewGoal = false
    @State private var showCheckIn = false
    @State private var selectedKind: NutritionQuestionnaireKind?
    @State private var isSyncing = false
    @State private var statusMessage: String?

    private var hasNutritionist: Bool {
        coach.activeNutritionLink != nil
            || authService.currentUser?.usesNutritionist == true
    }

    private var careLink: CoachLink? {
        coach.activeCareLink
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            anamnesisCard
            questionnairesSection
            goalsSection
            checkInSection

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
            }

            if hasNutritionist, let link = careLink {
                studentPhotoFlowCard(link: link)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .onAppear {
            care.bind(userId: authService.currentUser?.id)
            if let link = careLink {
                care.focus(linkId: link.id)
            } else if let uid = authService.currentUser?.id {
                care.focus(linkId: "local-\(uid)")
            }
        }
        .onChange(of: careLink?.id) { _, linkId in
            if let linkId {
                care.focus(linkId: linkId)
            }
        }
        .sheet(isPresented: $showAnamnesis) {
            NavigationStack {
                NutritionAnamnesisEditorView(isCoachMode: false)
            }
        }
        .sheet(item: $selectedKind) { kind in
            NavigationStack {
                NutritionQuestionnaireEditorView(kind: kind, isCoachMode: false)
            }
        }
        .sheet(isPresented: $showNewGoal) {
            NavigationStack {
                NutritionGoalEditorSheet(isCoachMode: false)
            }
        }
        .sheet(isPresented: $showCheckIn) {
            NavigationStack {
                NutritionCheckInSheet()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Acompanhamento")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(hasNutritionist
                 ? "Questionários, anamnese e metas sincronizam com seu nutricionista."
                 : "Preencha questionários e metas. Ao vincular um nutricionista, você pode sincronizar.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            if hasNutritionist {
                Button {
                    Task { await syncWithCoach() }
                } label: {
                    Label(isSyncing ? "Sincronizando…" : "Sincronizar com nutricionista", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: !isSyncing))
                .disabled(isSyncing)
            }
        }
    }

    private func studentPhotoFlowCard(link: CoachLink) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Foto da refeição para o nutricionista")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Fluxo: você envia → nutri vê só hoje → ao abrir, a foto é apagada.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Label("1. Escolha ou tire a foto da refeição", systemImage: "1.circle.fill")
                Label("2. Envie com o nome da refeição", systemImage: "2.circle.fill")
                Label("3. Nutricionista abre uma vez na Revisão IAssistente", systemImage: "3.circle.fill")
                Label("4. Foto apagada após visualização", systemImage: "4.circle.fill")
            }
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)

            NavigationLink {
                StudentDailyMealPhotoShareView(link: link)
            } label: {
                Label("Enviar foto da refeição (só hoje)", systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(AppTheme.coachNutrition)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.coachNutrition.opacity(0.35), lineWidth: 1)
        )
    }

    private var anamnesisCard: some View {
        Button { showAnamnesis = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "clipboard.fill")
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Anamnese completa")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(care.bundle.anamnesis.completionPercent)% preenchida")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .buttonStyle(.plain)
    }

    private var questionnairesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Questionários de saúde")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(NutritionQuestionnaireKind.allCases) { kind in
                let response = care.response(for: kind)
                Button { selectedKind = kind } label: {
                    HStack(spacing: 12) {
                        Image(systemName: kind.icon)
                            .foregroundStyle(AppTheme.accentSecondary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(kind.detail)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(response.isComplete ? "OK" : "\(response.answeredCount)/\(kind.questions.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(response.isComplete ? AppTheme.accent : AppTheme.textSecondary)
                    }
                    .padding(12)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Metas e objetivos")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button { showNewGoal = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            }

            if care.bundle.goals.isEmpty {
                Text("Crie metas (ex.: reduzir açúcar, beber 3 L de água). Com nutricionista, sincronize para acompanhamento.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(care.bundle.goals) { goal in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(goal.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text(goal.status.title)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.accent)
                        }
                        if !goal.detail.isEmpty {
                            Text(goal.detail)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        HStack {
                            Text(goal.author == .coach ? "Prescrita pelo nutri" : "Sua meta")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                            if goal.syncedWithCoach {
                                Label("Sincronizada", systemImage: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                    .padding(12)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contextMenu {
                        Button("Concluir") {
                            var g = goal
                            g.status = .completed
                            care.updateGoal(g)
                        }
                        Button("Pausar") {
                            var g = goal
                            g.status = .paused
                            care.updateGoal(g)
                        }
                        Button("Excluir", role: .destructive) {
                            care.deleteGoal(id: goal.id)
                        }
                    }
                }
            }
        }
    }

    private var checkInSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Check-in nutricional")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button("Registrar") { showCheckIn = true }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            ForEach(care.bundle.checkIns.prefix(5)) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Adesão \(item.adherence)/5 · Fome \(item.hunger)/5 · Energia \(item.energy)/5")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    if let w = item.weightKg {
                        Text(String(format: "%.1f kg", w))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(12)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func syncWithCoach() async {
        guard let link = careLink else { return }
        isSyncing = true
        defer { isSyncing = false }
        care.focus(linkId: link.id)
        let ok = await coach.publishNutritionCare(link: link)
        statusMessage = ok
            ? "Enviado ao nutricionista."
            : (coach.lastError ?? "Falha ao sincronizar.")
    }
}

// MARK: - Anamnesis editor

struct NutritionAnamnesisEditorView: View {
    var isCoachMode: Bool

    @ObservedObject private var care = NutritionCareStore.shared
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var draft = NutritionAnamnesis.empty

    var body: some View {
        Form {
            Section("Queixa e histórico") {
                labeledField("Queixa principal", text: $draft.chiefComplaint)
                labeledField("Histórico médico", text: $draft.medicalHistory)
                labeledField("Medicamentos", text: $draft.medications)
                labeledField("Alergias", text: $draft.allergies)
                labeledField("Cirurgias", text: $draft.surgeries)
                labeledField("Histórico familiar", text: $draft.familyHistory)
            }
            Section("Digestão e hábitos") {
                labeledField("Questões digestivas", text: $draft.digestiveIssues)
                labeledField("Função intestinal", text: $draft.bowelFunction)
                Stepper(value: $draft.waterIntakeLiters, in: 0.5...6, step: 0.25) {
                    Text(String(format: "Água: %.2f L/dia", draft.waterIntakeLiters))
                }
                labeledField("Álcool", text: $draft.alcoholUse)
                labeledField("Tabagismo", text: $draft.smoking)
                labeledField("Atividade física", text: $draft.physicalActivity)
            }
            Section("Sono, estresse e ciclo") {
                Stepper(value: $draft.sleepHours, in: 3...12, step: 0.5) {
                    Text(String(format: "Sono: %.1f h", draft.sleepHours))
                }
                Stepper("Estresse: \(draft.stressLevel)/10", value: $draft.stressLevel, in: 1...10)
                labeledField("Notas menstruais / hormonais", text: $draft.menstrualNotes)
            }
            Section("Alimentação") {
                labeledField("Aversões alimentares", text: $draft.foodAversions)
                labeledField("Frequência de comer fora", text: $draft.eatingOutFrequency)
                labeledField("Suplementos em uso", text: $draft.supplementsInUse)
                labeledField("Dietas anteriores", text: $draft.previousDiets)
                labeledField("Observações", text: $draft.notes)
            }
        }
        .navigationTitle(isCoachMode ? "Anamnese do aluno" : "Anamnese")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") { save() }
            }
        }
        .onAppear { draft = care.bundle.anamnesis }
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: text, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    private func save() {
        let user = authService.currentUser
        care.saveAnamnesis(
            draft,
            actorUid: user?.id,
            actorName: user?.greetingName.isEmpty == false ? user?.greetingName : user?.name
        )
        dismiss()
    }
}

// MARK: - Questionnaire editor

struct NutritionQuestionnaireEditorView: View {
    let kind: NutritionQuestionnaireKind
    var isCoachMode: Bool

    @ObservedObject private var care = NutritionCareStore.shared
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [String: String] = [:]

    var body: some View {
        Form {
            Section {
                Text(kind.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Perguntas") {
                ForEach(kind.questions) { question in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(question.prompt)
                            .font(.subheadline.weight(.semibold))
                        TextField("Resposta", text: binding(for: question.id), axis: .vertical)
                            .lineLimit(2...4)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") { save() }
            }
        }
        .onAppear {
            answers = care.response(for: kind).answers
        }
    }

    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { answers[id] ?? "" },
            set: { answers[id] = $0 }
        )
    }

    private func save() {
        var response = care.response(for: kind)
        response.answers = answers
        response.updatedAt = .now
        response.completedByUid = authService.currentUser?.id
        response.completedByName = authService.currentUser?.greetingName
        care.upsertQuestionnaire(response)
        dismiss()
    }
}

// MARK: - Goal sheet

struct NutritionGoalEditorSheet: View {
    var isCoachMode: Bool
    var onSaved: (() -> Void)? = nil

    @ObservedObject private var care = NutritionCareStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var detail = ""
    @State private var hasDeadline = false
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now

    var body: some View {
        Form {
            Section("Meta") {
                TextField("Título", text: $title)
                TextField("Detalhes", text: $detail, axis: .vertical)
                    .lineLimit(3...6)
                Toggle("Prazo", isOn: $hasDeadline)
                if hasDeadline {
                    DatePicker("Data alvo", selection: $deadline, displayedComponents: .date)
                }
            }
        }
        .navigationTitle(isCoachMode ? "Prescrever meta" : "Nova meta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let goal = NutritionGoal.make(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            targetDate: hasDeadline ? deadline : nil,
            author: isCoachMode ? .coach : .student,
            synced: isCoachMode
        )
        care.addGoal(goal)
        onSaved?()
        dismiss()
    }
}

// MARK: - Check-in sheet

struct NutritionCheckInSheet: View {
    @ObservedObject private var care = NutritionCareStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var weightText = ""
    @State private var adherence = 3
    @State private var hunger = 3
    @State private var energy = 3
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Hoje") {
                TextField("Peso (kg)", text: $weightText)
                    .keyboardType(.decimalPad)
                Stepper("Adesão ao cardápio: \(adherence)/5", value: $adherence, in: 1...5)
                Stepper("Fome: \(hunger)/5", value: $hunger, in: 1...5)
                Stepper("Energia: \(energy)/5", value: $energy, in: 1...5)
                TextField("Observações", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle("Check-in")
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

    private func save() {
        let weight = Double(weightText.replacingOccurrences(of: ",", with: "."))
        care.addCheckIn(.make(
            weightKg: weight,
            adherence: adherence,
            hunger: hunger,
            energy: energy,
            notes: notes
        ))
        dismiss()
    }
}

// MARK: - Coach panel for a nutrition link

struct CoachNutritionCarePanelView: View {
    let link: CoachLink

    @ObservedObject private var care = NutritionCareStore.shared
    @ObservedObject private var coach = CoachService.shared
    @EnvironmentObject private var authService: AuthService

    @State private var showAnamnesis = false
    @State private var showGoal = false
    @State private var selectedKind: NutritionQuestionnaireKind?
    @State private var isPublishing = false
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section {
                Text("Mesmo conteúdo da aba Nutrição → Acompanhar do aluno. Preencha anamnese, questionários e metas; publique para sincronizar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Aluno", value: link.studentName)
            }

            Section("Anamnese") {
                NavigationLink {
                    NutritionAnamnesisEditorView(isCoachMode: true)
                } label: {
                    Label("Ver / preencher anamnese (\(care.bundle.anamnesis.completionPercent)%)", systemImage: "clipboard.fill")
                }
            }

            Section("Questionários") {
                ForEach(NutritionQuestionnaireKind.allCases) { kind in
                    let response = care.response(for: kind)
                    NavigationLink {
                        NutritionQuestionnaireEditorView(kind: kind, isCoachMode: true)
                    } label: {
                        Label("\(kind.title) · \(response.answeredCount)/\(kind.questions.count)", systemImage: kind.icon)
                    }
                }
            }

            Section("Metas prescritas") {
                ForEach(care.bundle.goals.filter { $0.author == .coach || $0.syncedWithCoach }) { goal in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.title).font(.subheadline.weight(.semibold))
                        if !goal.detail.isEmpty {
                            Text(goal.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(goal.status.title).font(.caption2).foregroundStyle(AppTheme.accent)
                    }
                }
                Button {
                    showGoal = true
                } label: {
                    Label("Criar meta para o paciente", systemImage: "plus.circle.fill")
                }
            }

            Section("Check-ins recentes") {
                if care.bundle.checkIns.isEmpty {
                    Text("Ainda sem check-ins do aluno.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(care.bundle.checkIns.prefix(10)) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                            Text("Adesão \(item.adherence) · Fome \(item.hunger) · Energia \(item.energy)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let w = item.weightKg {
                                Text(String(format: "%.1f kg", w)).font(.caption)
                            }
                            if !item.notes.isEmpty {
                                Text(item.notes).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    Task { await publish() }
                } label: {
                    Label(isPublishing ? "Publicando…" : "Publicar acompanhamento no vínculo", systemImage: "icloud.and.arrow.up")
                }
                .disabled(isPublishing)

                if let statusMessage {
                    Text(statusMessage).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Acompanhamento")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGoal) {
            NavigationStack {
                NutritionGoalEditorSheet(isCoachMode: true)
            }
        }
        .onAppear {
            care.bind(userId: authService.currentUser?.id)
            care.focus(linkId: link.id)
        }
        .onChange(of: link.id) { _, newId in
            care.focus(linkId: newId)
        }
    }

    private func publish() async {
        isPublishing = true
        defer { isPublishing = false }
        care.focus(linkId: link.id)
        let ok = await coach.publishNutritionCare(link: link)
        statusMessage = ok ? "Acompanhamento publicado para o aluno." : (coach.lastError ?? "Falha ao publicar.")
    }
}
