import SwiftUI
import UIKit

struct CoachLinkDetailView: View {
    let link: CoachLink
    @ObservedObject private var coach = CoachService.shared
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var mealPlanService: MealPlanService
    @Environment(\.dismiss) private var dismiss
    @State private var showPrescribeWorkout = false
    @State private var showPrescribeMeal = false
    @State private var showChat = false
    @State private var statusMessage: String?
    @State private var assignmentToEdit: CoachAssignedWorkout?
    @State private var assignmentPendingDeletion: CoachAssignedWorkout?
    @State private var isDeleting = false
    @State private var showEndLinkConfirm = false
    @State private var isEndingLink = false

    private var liveLink: CoachLink {
        coach.myLinks.first(where: { $0.id == link.id }) ?? link
    }

    private var isCoach: Bool {
        authService.currentUser?.id == liveLink.coachUid
    }

    private var assigned: [CoachAssignedWorkout] {
        coach.assignedWorkoutsByLink[liveLink.id] ?? []
    }

    private var endLinkButtonTitle: String {
        if isCoach {
            return "Desvincular aluno"
        }
        switch liveLink.profession {
        case .personal: return "Excluir personal"
        case .nutritionist: return "Excluir nutricionista"
        }
    }

    private var endLinkConfirmMessage: String {
        if isCoach {
            return "O aluno \(liveLink.studentName) deixará de receber fichas, dietas e chat deste vínculo. As fichas já enviadas permanecem no aparelho do aluno."
        }
        switch liveLink.profession {
        case .personal:
            return "Você deixará de estar vinculado a \(liveLink.coachName). As fichas já recebidas permanecem nos seus treinos."
        case .nutritionist:
            return "Você deixará de estar vinculado a \(liveLink.coachName). O cardápio prescrito pode permanecer até você gerar outro."
        }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    DuoMemberAvatarView(
                        name: isCoach ? liveLink.studentName : liveLink.coachName,
                        photoURL: isCoach ? liveLink.studentPhotoURL : liveLink.coachPhotoURL,
                        size: 48
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isCoach ? liveLink.studentName : liveLink.coachName)
                            .font(.headline)
                        Text("\(liveLink.profession.title) · \(liveLink.status.displayLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if liveLink.status == .blockedPlan {
                Section {
                    Text("O aluno precisa do plano Fit ou superior para liberar fichas, dietas e chat.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isCoach, liveLink.isActiveLike {
                Section("Prescrever") {
                    if liveLink.profession == .personal {
                        Button {
                            assignmentToEdit = nil
                            showPrescribeWorkout = true
                        } label: {
                            Label("Criar / enviar ficha de musculação", systemImage: "dumbbell.fill")
                        }
                        NavigationLink {
                            CoachStudentMetricsView(link: liveLink)
                        } label: {
                            Label("Medidas, peso e relatório PDF", systemImage: "figure.stand")
                        }
                    }
                    if liveLink.profession == .nutritionist {
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
                            if isCoach, liveLink.isActiveLike {
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
                            if isCoach, liveLink.isActiveLike {
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
                    if isCoach, liveLink.isActiveLike {
                        Text("Deslize para editar ou excluir. As alterações sincronizam com o aluno.")
                    }
                }
            }

            Section {
                Button {
                    guard liveLink.status == .active else { return }
                    coach.ensureChatListening(linkId: liveLink.id)
                    showChat = true
                } label: {
                    Label("Abrir chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .disabled(liveLink.status != .active)
            }

            if liveLink.status != .ended {
                Section {
                    Button(role: .destructive) {
                        showEndLinkConfirm = true
                    } label: {
                        if isEndingLink {
                            ProgressView()
                        } else {
                            Label(endLinkButtonTitle, systemImage: "person.badge.minus")
                        }
                    }
                    .disabled(isEndingLink)
                } footer: {
                    Text(isCoach
                         ? "Remove o vínculo com este aluno no HealthFit Coach."
                         : "Remove o vínculo. Você poderá conectar outro profissional depois.")
                }
            }

            if let statusMessage {
                Text(statusMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(isCoach ? liveLink.studentName : liveLink.coachName)
        .onAppear {
            coach.ensureChatListening(linkId: liveLink.id)
        }
        .sheet(isPresented: $showPrescribeWorkout, onDismiss: {
            assignmentToEdit = nil
        }) {
            NavigationStack {
                CoachPrescribeWorkoutView(
                    link: liveLink,
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
                CoachPrescribeMealView(link: liveLink) { ok in
                    statusMessage = ok ? "Cardápio enviado e sincronizado com o aluno." : (coach.lastError ?? "Falha ao enviar.")
                    showPrescribeMeal = false
                }
            }
        }
        .sheet(isPresented: $showChat) {
            NavigationStack {
                CoachChatView(link: liveLink)
            }
        }
        .alert("Excluir ficha?", isPresented: deletionAlertBinding) {
            Button("Excluir", role: .destructive) {
                guard let item = assignmentPendingDeletion else { return }
                Task {
                    isDeleting = true
                    let ok = await coach.deleteAssignedWorkout(link: liveLink, assignment: item)
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
        .alert(endLinkButtonTitle, isPresented: $showEndLinkConfirm) {
            Button(endLinkButtonTitle, role: .destructive) {
                Task {
                    isEndingLink = true
                    let ok = await coach.endLink(liveLink)
                    isEndingLink = false
                    if ok {
                        dismiss()
                    } else {
                        statusMessage = coach.lastError ?? "Não foi possível encerrar o vínculo."
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(endLinkConfirmMessage)
        }
        .disabled(isDeleting || isEndingLink)
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
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var draft = ""

    private var liveLink: CoachLink {
        coach.myLinks.first(where: { $0.id == link.id }) ?? link
    }

    private var messages: [CoachChatMessage] {
        coach.chatMessages[liveLink.id] ?? []
    }

    private var currentUid: String? {
        authService.currentUser?.id
    }

    private var isCoachViewer: Bool {
        currentUid == liveLink.coachUid
    }

    private var peerName: String {
        isCoachViewer ? liveLink.studentName : liveLink.coachName
    }

    private var peerPhotoURL: String? {
        isCoachViewer ? liveLink.studentPhotoURL : liveLink.coachPhotoURL
    }

    private var canSend: Bool {
        liveLink.status == .active
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            peerHeader
            policyBanner

            if liveLink.status != .active {
                inactiveBanner
            }

            messagesArea
            composerBar
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fechar") { dismiss() }
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .onAppear {
            coach.ensureChatListening(linkId: liveLink.id)
            coach.acknowledgeDeliveredIfNeeded(linkId: liveLink.id)
            coach.markChatRead(linkId: liveLink.id)
        }
        .onChange(of: messages.count) { _, _ in
            coach.markChatRead(linkId: liveLink.id)
        }
    }

    // MARK: - Header

    private var peerHeader: some View {
        HStack(spacing: 12) {
            DuoMemberAvatarView(
                name: peerName,
                photoURL: peerPhotoURL,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(peerName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: liveLink.profession.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(8)
                .background(AppTheme.accent.opacity(0.15))
                .clipShape(Circle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            AppTheme.cardBackground
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppTheme.accent.opacity(0.12))
                        .frame(height: 1)
                }
        )
    }

    private var headerSubtitle: String {
        let role = isCoachViewer ? "Aluno" : liveLink.profession.title
        return "\(role) · \(liveLink.status.displayLabel)"
    }

    private var inactiveBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.caption)
            Text("Chat liberado com vínculo ativo e plano Fit+ do aluno.")
                .font(.caption)
        }
        .foregroundStyle(AppTheme.accentSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.accentSecondary.opacity(0.12))
    }

    private var policyBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock.badge.checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            Text(CoachChatPolicy.purposeNotice)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.cardBackground.opacity(0.85))
    }

    // MARK: - Messages

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if messages.isEmpty {
                        emptyState
                            .padding(.top, 48)
                    } else {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            if shouldShowDaySeparator(at: index) {
                                daySeparator(for: message.createdAt)
                            }
                            messageBubble(message, index: index)
                                .id(message.id)
                                .padding(.top, topSpacing(before: index))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.last?.id) { _, _ in
                scrollToBottom(proxy: proxy, animated: true)
            }
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
            }
            Text("Nenhuma mensagem ainda")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(isCoachViewer
                  ? "Envie orientações, ajustes de treino ou feedback para \(peerName)."
                  : "Tire dúvidas com seu \(liveLink.profession.title.lowercased()) \(peerName).")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity)
    }

    private func messageBubble(_ message: CoachChatMessage, index: Int) -> some View {
        let mine = message.senderUid == currentUid
        let showName = shouldShowSenderName(at: index, isMine: mine)
        let showAvatar = !mine && (index == 0 || messages[index - 1].senderUid != message.senderUid)

        return HStack(alignment: .bottom, spacing: 8) {
            if mine {
                Spacer(minLength: 52)
            } else if showAvatar {
                DuoMemberAvatarView(
                    name: message.senderName,
                    photoURL: peerPhotoURL,
                    size: 28
                )
            } else {
                Color.clear.frame(width: 28, height: 28)
            }

            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                if showName {
                    Text(message.senderName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 4)
                }

                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(mine ? Color(red: 0.08, green: 0.12, blue: 0.10) : AppTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        if mine {
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accent.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            AppTheme.cardBackground
                        }
                    }
                    .clipShape(bubbleShape(isMine: mine))
                    .overlay(
                        bubbleShape(isMine: mine)
                            .strokeBorder(
                                mine ? Color.clear : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                    )
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.text
                        } label: {
                            Label("Copiar", systemImage: "doc.on.doc")
                        }
                    }

                // Horário de envio sempre visível; ticks de recebimento em cada mensagem própria.
                HStack(spacing: 4) {
                    Text(message.createdAt, format: .dateTime.hour().minute())
                    if mine {
                        CoachMessageReceiptTicks(status: message.receiptStatus)
                    }
                }
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.9))
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 290, alignment: mine ? .trailing : .leading)

            if !mine {
                Spacer(minLength: 52)
            }
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }

    private func bubbleShape(isMine: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: isMine ? 18 : 5,
            bottomTrailingRadius: isMine ? 5 : 18,
            topTrailingRadius: 18,
            style: .continuous
        )
    }

    private func daySeparator(for date: Date) -> some View {
        Text(dayLabel(for: date))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(AppTheme.cardBackground.opacity(0.9))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    // MARK: - Composer

    private var composerBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    liveLink.status == .active ? "Escreva uma mensagem…" : "Chat indisponível",
                    text: $draft,
                    axis: .vertical
                )
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1...5)
                .focused($focused)
                .disabled(liveLink.status != .active)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            focused ? AppTheme.accent.opacity(0.45) : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )

                Button {
                    sendDraft()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(canSend ? Color(red: 0.08, green: 0.12, blue: 0.10) : AppTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(canSend ? AppTheme.accent : AppTheme.cardBackground)
                        )
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(canSend ? 0 : 0.08), lineWidth: 1)
                        )
                }
                .disabled(!canSend)
                .accessibilityLabel("Enviar")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.background.opacity(0.98))
        }
    }

    private func sendDraft() {
        let text = draft
        draft = ""
        focused = false
        Task {
            _ = await coach.sendChat(link: liveLink, text: text)
        }
    }

    // MARK: - Helpers

    private func shouldShowSenderName(at index: Int, isMine: Bool) -> Bool {
        guard !isMine else { return false }
        guard index > 0 else { return true }
        return messages[index - 1].senderUid != messages[index].senderUid
    }

    private func shouldShowDaySeparator(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return !Calendar.current.isDate(messages[index].createdAt, inSameDayAs: messages[index - 1].createdAt)
    }

    private func topSpacing(before index: Int) -> CGFloat {
        guard index > 0 else { return 4 }
        let previous = messages[index - 1]
        let current = messages[index]
        if previous.senderUid == current.senderUid,
           current.createdAt.timeIntervalSince(previous.createdAt) < 2 * 60 {
            return 3
        }
        return 10
    }

    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoje" }
        if calendar.isDateInYesterday(date) { return "Ontem" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let last = messages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
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
        .foregroundStyle(status == .read ? AppTheme.accent : AppTheme.textSecondary)
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
