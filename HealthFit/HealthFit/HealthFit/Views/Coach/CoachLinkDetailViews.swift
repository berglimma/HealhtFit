import SwiftUI

struct CoachLinkDetailView: View {
    let link: CoachLink
    @ObservedObject private var coach = CoachService.shared
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var mealPlanService: MealPlanService
    @State private var showPrescribeWorkout = false
    @State private var showPrescribeMeal = false
    @State private var showChat = false
    @State private var statusMessage: String?
    @State private var assignmentToEdit: CoachAssignedWorkout?
    @State private var assignmentPendingDeletion: CoachAssignedWorkout?
    @State private var isDeleting = false

    private var isCoach: Bool {
        authService.currentUser?.id == link.coachUid
    }

    private var assigned: [CoachAssignedWorkout] {
        coach.assignedWorkoutsByLink[link.id] ?? []
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Profissão", value: link.profession.title)
                LabeledContent("Status", value: link.status.displayLabel)
                LabeledContent(isCoach ? "Aluno" : "Profissional", value: isCoach ? link.studentName : link.coachName)
            }

            if link.status == .blockedPlan {
                Section {
                    Text("O aluno precisa do plano Fit ou superior para liberar fichas, dietas e chat.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isCoach {
                Section("Prescrever") {
                    if link.profession == .personal {
                        Button {
                            assignmentToEdit = nil
                            showPrescribeWorkout = true
                        } label: {
                            Label("Criar / enviar ficha de musculação", systemImage: "dumbbell.fill")
                        }
                        NavigationLink {
                            CoachStudentMetricsView(link: link)
                        } label: {
                            Label("Medidas, peso e relatório PDF", systemImage: "figure.stand")
                        }
                    }
                    if link.profession == .nutritionist {
                        Button {
                            showPrescribeMeal = true
                        } label: {
                            Label("Montar / enviar cardápio", systemImage: "fork.knife")
                        }
                    }
                }
            }

            if !assigned.isEmpty {
                Section {
                    ForEach(assigned) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.sheet.title).font(.subheadline.weight(.semibold))
                            Text("\(item.sheet.exercises.count) exercícios · \(item.sheet.targetGender?.rawValue ?? "—")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Atualizado \(item.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if isCoach {
                                Button(role: .destructive) {
                                    assignmentPendingDeletion = item
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                                Button {
                                    assignmentToEdit = item
                                    showPrescribeWorkout = true
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(AppTheme.accent)
                            }
                        }
                        .contextMenu {
                            if isCoach {
                                Button {
                                    assignmentToEdit = item
                                    showPrescribeWorkout = true
                                } label: {
                                    Label("Editar ficha", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    assignmentPendingDeletion = item
                                } label: {
                                    Label("Excluir ficha", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Fichas prescritas")
                } footer: {
                    if isCoach {
                        Text("Deslize para editar ou excluir. As alterações sincronizam com o aluno.")
                    }
                }
            }

            Section {
                Button {
                    guard link.status == .active else { return }
                    coach.ensureChatListening(linkId: link.id)
                    showChat = true
                } label: {
                    Label("Abrir chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .disabled(link.status != .active)
            }

            if let statusMessage {
                Text(statusMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(isCoach ? link.studentName : link.coachName)
        .onAppear {
            coach.ensureChatListening(linkId: link.id)
        }
        .sheet(isPresented: $showPrescribeWorkout, onDismiss: {
            assignmentToEdit = nil
        }) {
            NavigationStack {
                CoachPrescribeWorkoutView(
                    link: link,
                    editingAssignment: assignmentToEdit
                ) { ok in
                    let editing = assignmentToEdit != nil
                    statusMessage = ok
                        ? (editing ? "Ficha atualizada e sincronizada com o aluno." : "Ficha enviada e sincronizada com o aluno.")
                        : (coach.lastError ?? "Falha ao salvar.")
                    showPrescribeWorkout = false
                    assignmentToEdit = nil
                }
            }
        }
        .sheet(isPresented: $showPrescribeMeal) {
            NavigationStack {
                CoachPrescribeMealView(link: link) { ok in
                    statusMessage = ok ? "Cardápio enviado e sincronizado com o aluno." : (coach.lastError ?? "Falha ao enviar.")
                    showPrescribeMeal = false
                }
            }
        }
        .sheet(isPresented: $showChat) {
            NavigationStack {
                CoachChatView(link: link)
            }
        }
        .alert("Excluir ficha?", isPresented: deletionAlertBinding) {
            Button("Excluir", role: .destructive) {
                guard let item = assignmentPendingDeletion else { return }
                Task {
                    isDeleting = true
                    let ok = await coach.deleteAssignedWorkout(link: link, assignment: item)
                    isDeleting = false
                    statusMessage = ok
                        ? "Ficha removida do aluno."
                        : (coach.lastError ?? "Falha ao excluir.")
                    assignmentPendingDeletion = nil
                }
            }
            Button("Cancelar", role: .cancel) {
                assignmentPendingDeletion = nil
            }
        } message: {
            if let item = assignmentPendingDeletion {
                Text("“\(item.sheet.title)” será removida do app do aluno.")
            }
        }
        .disabled(isDeleting)
    }

    private var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { assignmentPendingDeletion != nil },
            set: { if !$0 { assignmentPendingDeletion = nil } }
        )
    }
}

struct CoachPrescribeWorkoutView: View {
    let link: CoachLink
    var editingAssignment: CoachAssignedWorkout? = nil
    var onFinished: (Bool) -> Void

    @ObservedObject private var coach = CoachService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var sheetId = UUID()
    @State private var title = ""
    @State private var description = ""
    @State private var selectedFocusGroups: Set<CustomWorkoutFocusGroup> = [.chest]
    @State private var exercises: [Exercise] = []
    @State private var targetGender: Gender = .male
    @State private var isPublishing = false
    @State private var showAddExercise = false
    @State private var showCustomExercise = false
    @State private var customName = ""
    @State private var customMuscleGroup: MuscleGroup = .chest
    @State private var customSets = 3
    @State private var customReps = 10
    @State private var didLoadEditing = false

    private var isEditing: Bool { editingAssignment != nil }

    var body: some View {
        Form {
            Section("Aluno") {
                Text(link.studentName)
                Text(isEditing
                     ? "Ao salvar, a ficha é atualizada no app do aluno."
                     : "A ficha aparece na musculação do aluno (plano Fit+).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Perfil da ficha") {
                Picker("Perfil", selection: $targetGender) {
                    Text("Masculino").tag(Gender.male)
                    Text("Feminino").tag(Gender.female)
                }
                .pickerStyle(.segmented)
            }

            Section {
                ForEach(CustomWorkoutFocusGroup.allCases) { group in
                    Toggle(isOn: binding(for: group)) {
                        Label(group.rawValue, systemImage: group.icon)
                    }
                }
            } header: {
                Text("Grupos (sugestão rápida)")
            } footer: {
                Text("Liga um grupo para incluir os exercícios do catálogo. Você também pode adicionar ou criar exercícios abaixo.")
            }

            Section("Informações") {
                TextField("Nome do treino", text: $title)
                TextField("Observação para o aluno", text: $description)
            }

            Section {
                Button {
                    showAddExercise = true
                } label: {
                    Label("Adicionar do catálogo", systemImage: "plus.circle.fill")
                }
                Button {
                    customName = ""
                    customMuscleGroup = .chest
                    customSets = 3
                    customReps = 10
                    showCustomExercise = true
                } label: {
                    Label("Criar exercício personalizado", systemImage: "square.and.pencil")
                }

                if exercises.isEmpty {
                    Text("Adicione exercícios do catálogo, crie um personalizado ou use os grupos acima.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($exercises) { $exercise in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.name).font(.subheadline.weight(.semibold))
                            Text(exercise.muscleGroup.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack {
                                Stepper("Séries \(exercise.sets)", value: $exercise.sets, in: 1...8)
                            }
                            HStack {
                                Stepper("Reps \(exercise.reps)", value: $exercise.reps, in: 1...30)
                            }
                        }
                    }
                    .onDelete { exercises.remove(atOffsets: $0) }
                }
            } header: {
                Text("Exercícios (\(exercises.count))")
            }
        }
        .navigationTitle(isEditing ? "Editar ficha" : "Prescrever ficha")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isPublishing ? "…" : (isEditing ? "Salvar" : "Enviar")) {
                    Task { await publish() }
                }
                .disabled(isPublishing || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || exercises.isEmpty)
            }
        }
        .sheet(isPresented: $showAddExercise) {
            AddExerciseDuringWorkoutView(
                excludeNames: Set(exercises.map(\.name))
            ) { template in
                exercises.append(WorkoutStore.copyExerciseForWorkout(template))
                updateDefaultTitleIfNeeded()
            }
        }
        .sheet(isPresented: $showCustomExercise) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Nome do exercício", text: $customName)
                        Picker("Grupo muscular", selection: $customMuscleGroup) {
                            ForEach(MuscleGroup.allCases) { group in
                                Label(group.rawValue, systemImage: group.icon).tag(group)
                            }
                        }
                        Stepper("Séries \(customSets)", value: $customSets, in: 1...8)
                        Stepper("Repetições \(customReps)", value: $customReps, in: 1...30)
                    } footer: {
                        Text("O exercício entra só nesta ficha do aluno.")
                    }
                }
                .navigationTitle("Exercício personalizado")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showCustomExercise = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Adicionar") {
                            addCustomExercise()
                            showCustomExercise = false
                        }
                        .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            loadInitialStateIfNeeded()
        }
    }

    private func loadInitialStateIfNeeded() {
        guard !didLoadEditing else { return }
        didLoadEditing = true
        if let editing = editingAssignment {
            let sheet = editing.sheet
            sheetId = sheet.id
            title = sheet.title
            description = sheet.description
            exercises = sheet.exercises
            targetGender = sheet.targetGender ?? sheet.resolvedProgramGender ?? .male
            selectedFocusGroups = Set(exercises.compactMap { WorkoutStore.focusGroup(for: $0) })
            if selectedFocusGroups.isEmpty {
                selectedFocusGroups = [.chest]
            }
        } else {
            if title.isEmpty { title = "Treino A — \(link.studentName)" }
            if exercises.isEmpty {
                appendExercises(from: selectedFocusGroups)
                updateDefaultTitleIfNeeded()
            }
        }
    }

    private func binding(for group: CustomWorkoutFocusGroup) -> Binding<Bool> {
        Binding(
            get: { selectedFocusGroups.contains(group) },
            set: { enabled in
                let previous = selectedFocusGroups
                if enabled { selectedFocusGroups.insert(group) }
                else { selectedFocusGroups.remove(group) }
                syncExercisesAfterSelectionChange(from: previous, to: selectedFocusGroups)
                updateDefaultTitleIfNeeded()
            }
        )
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
                // Mantém exercícios adicionados manualmente / personalizados sem foco de catálogo.
                return removed.contains(focus)
            }
        }

        for group in added {
            appendExercises(from: [group])
        }
    }

    private func appendExercises(from groups: Set<CustomWorkoutFocusGroup>) {
        let existingNames = Set(exercises.map(\.name))
        let additions = WorkoutStore.presetExercises(for: groups)
            .filter { !existingNames.contains($0.name) }
            .map { WorkoutStore.copyExerciseForWorkout($0) }
        exercises.append(contentsOf: additions)
    }

    private func addCustomExercise() {
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if exercises.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return
        }
        exercises.append(
            Exercise(
                name: name,
                sets: customSets,
                reps: customReps,
                muscleGroup: customMuscleGroup
            )
        )
        updateDefaultTitleIfNeeded()
    }

    private func updateDefaultTitleIfNeeded() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty || title.hasPrefix("Treino A") || title.hasPrefix("Treino —") || title.hasPrefix("Treino -") else {
            return
        }
        let joined = CustomWorkoutFocusGroup.allCases
            .filter { selectedFocusGroups.contains($0) }
            .map(\.rawValue)
            .joined(separator: " + ")
        if !joined.isEmpty {
            title = "Treino — \(joined)"
        } else if !exercises.isEmpty {
            title = "Treino — \(link.studentName)"
        }
    }

    private func publish() async {
        isPublishing = true
        defer { isPublishing = false }
        let sheet = WorkoutSheet(
            id: sheetId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            exercises: exercises,
            assignedTo: link.studentUid,
            isUserCreated: true,
            targetGender: targetGender,
            isCoachPrescribed: true,
            coachLinkId: link.id,
            prescribedByUid: link.coachUid,
            prescribedByName: link.coachName
        )
        let ok = await coach.publishWorkout(link: link, sheet: sheet)
        onFinished(ok)
    }
}

struct CoachPrescribeMealView: View {
    let link: CoachLink
    var onFinished: (Bool) -> Void

    @ObservedObject private var coach = CoachService.shared
    @EnvironmentObject private var mealPlanService: MealPlanService
    @Environment(\.dismiss) private var dismiss

    @State private var calorieTarget = 2200
    @State private var goal: FitnessGoal = .muscleGain
    @State private var sweetLevel: SweetConsumptionLevel = .moderate
    @State private var lactose: LactoseTolerance = .tolerant
    @State private var selectedTemplateIDs: [MealType: UUID] = [:]
    @State private var draftPlan: [DailyMealPlan] = []
    @State private var isPublishing = false
    @State private var mode: Mode = .builder

    private enum Mode: String, CaseIterable, Identifiable {
        case builder = "Montar"
        case local = "Plano local"
        var id: String { rawValue }
    }

    var body: some View {
        Form {
            Section {
                Picker("Origem", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("O aluno recebe o cardápio em Nutrição automaticamente (Fit+).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if mode == .local {
                Section("Plano neste aparelho") {
                    Text("\(mealPlanService.weeklyPlan.count) dia(s) prontos para enviar")
                    if mealPlanService.weeklyPlan.isEmpty {
                        Text("Monte um cardápio em Nutrição ou use a aba Montar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section("Meta do aluno") {
                    Stepper("Calorias/dia: \(calorieTarget)", value: $calorieTarget, in: 1200...4500, step: 50)
                    Picker("Objetivo", selection: $goal) {
                        ForEach(FitnessGoal.allCases) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    Picker("Doces", selection: $sweetLevel) {
                        ForEach(SweetConsumptionLevel.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Lactose", selection: $lactose) {
                        ForEach(LactoseTolerance.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Refeições (toque para trocar)") {
                    ForEach(MealType.allCases) { mealType in
                        let options = MealCatalog.templates(
                            for: mealType,
                            sweetLevel: sweetLevel,
                            goal: goal,
                            lactoseTolerance: lactose
                        )
                        if let selected = selectedTemplate(for: mealType, in: options) {
                            Picker(mealType.rawValue, selection: binding(for: mealType, fallback: selected.id)) {
                                ForEach(options) { template in
                                    Text("\(template.name) · \(template.calories) kcal").tag(template.id)
                                }
                            }
                        }
                    }
                }

                if !draftPlan.isEmpty {
                    Section("Prévia (Segunda)") {
                        let day = draftPlan[0]
                        Text("\(day.totalCalories) kcal · \(day.totalProtein)g proteína")
                            .font(.subheadline.weight(.semibold))
                        ForEach(day.meals) { meal in
                            HStack {
                                Text(meal.mealType.shortLabel)
                                Spacer()
                                Text(meal.name)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("Prescrever cardápio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isPublishing ? "…" : "Enviar") {
                    Task { await publish() }
                }
                .disabled(isPublishing || planToPublish.isEmpty)
            }
        }
        .onAppear { ensureDefaults(); rebuildDraft() }
        .onChange(of: calorieTarget) { _, _ in rebuildDraft() }
        .onChange(of: goal) { _, _ in ensureDefaults(); rebuildDraft() }
        .onChange(of: sweetLevel) { _, _ in ensureDefaults(); rebuildDraft() }
        .onChange(of: lactose) { _, _ in ensureDefaults(); rebuildDraft() }
        .onChange(of: selectedTemplateIDs) { _, _ in rebuildDraft() }
    }

    private var planToPublish: [DailyMealPlan] {
        mode == .local ? mealPlanService.weeklyPlan : draftPlan
    }

    private func binding(for mealType: MealType, fallback: UUID) -> Binding<UUID> {
        Binding(
            get: { selectedTemplateIDs[mealType] ?? fallback },
            set: { selectedTemplateIDs[mealType] = $0 }
        )
    }

    private func selectedTemplate(for mealType: MealType, in options: [MealTemplate]) -> MealTemplate? {
        if let id = selectedTemplateIDs[mealType],
           let match = options.first(where: { $0.id == id }) ?? MealCatalog.template(id: id) {
            return match
        }
        return options.first
    }

    private func ensureDefaults() {
        for mealType in MealType.allCases {
            let options = MealCatalog.templates(
                for: mealType,
                sweetLevel: sweetLevel,
                goal: goal,
                lactoseTolerance: lactose
            )
            guard let first = options.first else { continue }
            if let current = selectedTemplateIDs[mealType],
               options.contains(where: { $0.id == current }) {
                continue
            }
            selectedTemplateIDs[mealType] = first.id
        }
    }

    private func rebuildDraft() {
        let days = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]
        let proteins = goal == .muscleGain ? 2 : 1
        draftPlan = days.map { day in
            let meals: [Meal] = MealType.allCases.compactMap { mealType in
                let options = MealCatalog.templates(
                    for: mealType,
                    sweetLevel: sweetLevel,
                    goal: goal,
                    lactoseTolerance: lactose
                )
                guard let template = selectedTemplate(for: mealType, in: options) else { return nil }
                let target = max(Int(Double(calorieTarget) * mealType.calorieShare), 120)
                return template.scaled(to: target, proteinMultiplier: proteins)
            }
            return DailyMealPlan(
                dayOfWeek: day,
                options: [
                    MealPlanOption(
                        name: "Prescrição Coach",
                        subtitle: "Enviado por \(link.coachName)",
                        meals: meals
                    )
                ]
            )
        }
    }

    private func publish() async {
        isPublishing = true
        defer { isPublishing = false }
        let ok = await coach.publishMealPlan(link: link, weeklyPlan: planToPublish)
        onFinished(ok)
    }
}

struct CoachChatView: View {
    let link: CoachLink
    @ObservedObject private var coach = CoachService.shared
    @EnvironmentObject private var authService: AuthService
    @State private var draft = ""
    @FocusState private var focused: Bool

    private var messages: [CoachChatMessage] {
        coach.chatMessages[link.id] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            if link.status != .active {
                Text("Chat liberado com vínculo ativo e plano Fit+ do aluno.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            let mine = message.senderUid == authService.currentUser?.id
                            HStack {
                                if mine { Spacer(minLength: 40) }
                                VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
                                    Text(message.text)
                                        .font(.subheadline)
                                        .foregroundStyle(mine ? .black : AppTheme.textPrimary)
                                        .padding(10)
                                        .background(mine ? AppTheme.accent : AppTheme.cardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    HStack(spacing: 4) {
                                        Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                                        if mine {
                                            CoachMessageReceiptTicks(status: message.receiptStatus)
                                        }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                if !mine { Spacer(minLength: 40) }
                            }
                            .id(message.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                    coach.markChatRead(linkId: link.id)
                }
                .onChange(of: messages.map(\.id)) { _, _ in
                    coach.markChatRead(linkId: link.id)
                }
            }

            HStack(spacing: 8) {
                TextField("Mensagem", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused)
                Button {
                    Task {
                        let text = draft
                        draft = ""
                        _ = await coach.sendChat(link: link, text: text)
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(AppTheme.accent)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || link.status != .active)
            }
            .padding(12)
            .background(AppTheme.cardBackground)
        }
        .navigationTitle("Chat Coach")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            coach.ensureChatListening(linkId: link.id)
            coach.acknowledgeDeliveredIfNeeded(linkId: link.id)
            coach.markChatRead(linkId: link.id)
        }
    }
}

private struct CoachMessageReceiptTicks: View {
    let status: CoachChatMessage.ReceiptStatus

    var body: some View {
        HStack(spacing: -3) {
            Image(systemName: "checkmark")
            if status != .sent {
                Image(systemName: "checkmark")
            }
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(status == .read ? AppTheme.accent : Color.secondary)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch status {
        case .sent: return "Enviada"
        case .delivered: return "Entregue"
        case .read: return "Lida"
        }
    }
}

/// Personal: ver/editar peso, altura e circunferências do aluno + exportar PDF no app.
struct CoachStudentMetricsView: View {
    let link: CoachLink

    @EnvironmentObject private var authService: AuthService
    @State private var student: UserProfile?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var statusMessage: String?
    @State private var loadError: String?

    @State private var weightText = ""
    @State private var heightText = ""
    @State private var neckText = ""
    @State private var shouldersText = ""
    @State private var chestText = ""
    @State private var rightArmText = ""
    @State private var leftArmText = ""
    @State private var waistText = ""
    @State private var abdomenText = ""
    @State private var hipText = ""
    @State private var rightThighText = ""
    @State private var leftThighText = ""
    @State private var rightCalfText = ""
    @State private var leftCalfText = ""

    @State private var showMeasurementsEditor = false
    @State private var isGeneratingPDF = false
    @State private var pdfURL: URL?
    @State private var showPDFShare = false
    @State private var showEmptyPDFAlert = false
    @State private var showSavedAlert = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Carregando medidas…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError, student == nil {
                ContentUnavailableView(
                    "Não foi possível carregar",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                formContent
            }
        }
        .navigationTitle(link.studentName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadStudent() }
        .sheet(isPresented: $showMeasurementsEditor) {
            BodyMeasurementsEditorSheet(
                neckText: $neckText,
                shouldersText: $shouldersText,
                chestText: $chestText,
                rightArmText: $rightArmText,
                leftArmText: $leftArmText,
                waistText: $waistText,
                abdomenText: $abdomenText,
                hipText: $hipText,
                rightThighText: $rightThighText,
                leftThighText: $leftThighText,
                rightCalfText: $rightCalfText,
                leftCalfText: $leftCalfText,
                onSave: {
                    showMeasurementsEditor = false
                    Task { await save(includeMeasurements: true) }
                },
                onClose: { showMeasurementsEditor = false }
            )
        }
        .sheet(isPresented: $showPDFShare, onDismiss: { pdfURL = nil }) {
            if let pdfURL {
                ActivityShareSheet(items: [pdfURL]) {
                    showPDFShare = false
                }
            }
        }
        .alert("Salvo", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Peso, altura e medidas do aluno foram atualizados.")
        }
        .alert("Sem dados para o PDF", isPresented: $showEmptyPDFAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Informe ao menos o peso ou alguma circunferência antes de exportar.")
        }
    }

    private var formContent: some View {
        Form {
            Section {
                LabeledContent("Aluno", value: link.studentName)
                if let measuredAt = student?.bodyMeasurements.measuredAt {
                    LabeledContent(
                        "Última aferição",
                        value: measuredAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }

            Section("Peso e altura") {
                HStack {
                    Text("Peso (kg)")
                    Spacer()
                    TextField("0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
                HStack {
                    Text("Altura (cm)")
                    Spacer()
                    TextField("0", text: $heightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
            }

            Section("Circunferências") {
                Text(measurementsSummary.isEmpty ? "Nenhuma medida preenchida" : measurementsSummary)
                    .font(.subheadline)
                    .foregroundStyle(measurementsSummary.isEmpty ? .secondary : AppTheme.textPrimary)
                Button {
                    showMeasurementsEditor = true
                } label: {
                    Label("Editar medidas corporais", systemImage: "ruler")
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            }

            Section {
                Button {
                    Task { await save(includeMeasurements: true) }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Salvar no perfil do aluno", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSaving || student == nil)

                Button {
                    exportPDF()
                } label: {
                    if isGeneratingPDF {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Exportar relatório em PDF", systemImage: "doc.richtext")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isGeneratingPDF || student == nil)
            }
        }
    }

    private var measurementsSummary: String {
        let filled = [
            ("Pescoço", neckText),
            ("Ombros", shouldersText),
            ("Peito", chestText),
            ("Cintura", waistText),
            ("Abdômen", abdomenText),
            ("Quadril", hipText)
        ]
        .filter { !$0.1.trimmingCharacters(in: .whitespaces).isEmpty }
        .prefix(4)
        .map { "\($0.0) \($0.1)" }
        return filled.joined(separator: " · ")
    }

    private func loadStudent() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            guard let profile = try await ProfileFirestoreService.fetchProfile(userId: link.studentUid) else {
                loadError = "O aluno ainda não tem perfil sincronizado no Firebase."
                return
            }
            apply(profile)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func apply(_ profile: UserProfile) {
        student = profile
        weightText = formatField(profile.weight)
        heightText = formatField(profile.height)
        let m = profile.bodyMeasurements
        neckText = formatOptional(m.neckCm)
        shouldersText = formatOptional(m.shouldersCm)
        chestText = formatOptional(m.chestCm)
        rightArmText = formatOptional(m.rightArmCm)
        leftArmText = formatOptional(m.leftArmCm)
        waistText = formatOptional(m.waistCm)
        abdomenText = formatOptional(m.abdomenCm)
        hipText = formatOptional(m.hipCm)
        rightThighText = formatOptional(m.rightThighCm)
        leftThighText = formatOptional(m.leftThighCm)
        rightCalfText = formatOptional(m.rightCalfCm)
        leftCalfText = formatOptional(m.leftCalfCm)
    }

    private func save(includeMeasurements: Bool) async {
        guard var profile = student else { return }
        isSaving = true
        statusMessage = nil
        defer { isSaving = false }

        if let weight = parseNumber(weightText), weight > 0 {
            profile.weight = weight
        }
        if let height = parseNumber(heightText), height > 0 {
            profile.height = height
        }

        let coachName = authService.currentUser?.shownName
            ?? authService.currentUser?.name
            ?? link.coachName
        if !coachName.isEmpty {
            profile.usesPersonalTrainer = true
            profile.personalTrainerName = coachName
        }

        if includeMeasurements {
            let measurements = currentMeasurements()
            if measurements.hasAnyValue || profile.bodyMeasurements.hasAnyValue {
                let previous = profile.bodyMeasurements
                if BodyMeasurements.isEligibleForPeriodComparison(previous: previous),
                   previous.hasAnyValue {
                    profile.previousBodyMeasurements = previous
                }
                if measurements.hasAnyValue {
                    profile.recordBodyMeasurementEvaluation(measurements)
                }
            }
        }

        profile.updatedAt = .now
        do {
            try await ProfileFirestoreService.saveProfile(profile)
            apply(profile)
            showSavedAlert = true
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func exportPDF() {
        guard !isGeneratingPDF else { return }
        guard var profile = student else { return }

        if let weight = parseNumber(weightText), weight > 0 {
            profile.weight = weight
        }
        if let height = parseNumber(heightText), height > 0 {
            profile.height = height
        }
        let coachName = authService.currentUser?.shownName
            ?? authService.currentUser?.name
            ?? link.coachName
        if !coachName.isEmpty {
            profile.personalTrainerName = coachName
        }

        let formMeasurements = currentMeasurements(measuredAt: profile.bodyMeasurements.measuredAt ?? .now)
        let exportMeasurements = formMeasurements.hasAnyValue ? formMeasurements : profile.bodyMeasurements
        guard exportMeasurements.hasAnyValue || profile.weight > 0 else {
            showEmptyPDFAlert = true
            return
        }

        isGeneratingPDF = true
        PhysicalAssessmentPDFBuilder.prepareForExport()
        Task {
            let url = await Task.detached(priority: .userInitiated) {
                PhysicalAssessmentPDFBuilder.writeTemporaryPDF(
                    profile: profile,
                    measurements: exportMeasurements
                )
            }.value
            await MainActor.run {
                isGeneratingPDF = false
                guard let url else {
                    showEmptyPDFAlert = true
                    return
                }
                pdfURL = url
                showPDFShare = true
            }
        }
    }

    private func currentMeasurements(measuredAt: Date = .now) -> BodyMeasurements {
        BodyMeasurements(
            neckCm: parseNumber(neckText),
            shouldersCm: parseNumber(shouldersText),
            chestCm: parseNumber(chestText),
            rightArmCm: parseNumber(rightArmText),
            leftArmCm: parseNumber(leftArmText),
            waistCm: parseNumber(waistText),
            abdomenCm: parseNumber(abdomenText),
            hipCm: parseNumber(hipText),
            rightThighCm: parseNumber(rightThighText),
            leftThighCm: parseNumber(leftThighText),
            rightCalfCm: parseNumber(rightCalfText),
            leftCalfCm: parseNumber(leftCalfText),
            measuredAt: measuredAt
        )
    }

    private func formatField(_ value: Double) -> String {
        value <= 0 ? "" : formatOptional(value)
    }

    private func formatOptional(_ value: Double?) -> String {
        guard let value, value > 0 else { return "" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    private func parseNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), value > 0, value < 500 else { return nil }
        return value
    }
}
