import SwiftUI

private enum WorkoutSection: String, CaseIterable, Identifiable {
    case strength
    case home
    case cardio
    case meditation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: return L10n.Workout.strength
        case .home: return L10n.Workout.home
        case .cardio: return L10n.Workout.cardio
        case .meditation: return L10n.Workout.meditation
        }
    }
}

struct WorkoutListView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var subscriptions: SubscriptionService
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var trainingNutritionSync: TrainingNutritionSyncService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showCreateWorkout = false
    @State private var createTargetGender: Gender = .male
    @State private var sheetToEdit: WorkoutSheet?
    @State private var sheetPendingDeletion: WorkoutSheet?
    @State private var selectedSection: WorkoutSection = .strength
    @State private var paywallFeature: AppFeature?

    private var availableSections: [WorkoutSection] {
        let user = authService.currentUser
        return WorkoutSection.allCases.filter { section in
            guard let user else { return true }
            switch section {
            case .strength: return user.practices(PracticeModalityID.strength)
            case .home: return user.practices(PracticeModalityID.home)
            case .cardio: return user.practicesAnyCardio
            case .meditation: return user.practices(PracticeModalityID.meditation)
            }
        }
    }

    private var visibleCardioExercises: [CardioExercise] {
        guard let user = authService.currentUser else {
            return CardioExercise.catalog
        }
        // Lista vazia no perfil = “todas”; senão só as marcadas (pode ficar só Luta).
        if user.practicedModalityIDs.isEmpty {
            return CardioExercise.catalog
        }
        var list = user.practicedCardioExercises
        // Esteira é nova: se o usuário já pratica Corrida ou bike ergométrica, mostra o card.
        if let esteira = CardioExercise.catalog.first(where: \.isTreadmill),
           !list.contains(where: \.isTreadmill),
           user.practicesCardio(named: "Corrida")
            || user.practicesCardio(named: "Bicicleta ergométrica")
            || user.practicesCardio(named: "Caminhada") {
            // Insere após Corrida quando existir.
            if let idx = list.firstIndex(where: { $0.name == "Corrida" }) {
                list.insert(esteira, at: idx + 1)
            } else {
                list.insert(esteira, at: 0)
            }
        }
        return list
    }

    /// Sem usuário ou preferência “todas” → Luta aparece; senão respeita o toggle do perfil.
    private var showsFightCard: Bool {
        authService.currentUser?.practicesFight ?? true
    }

    private var hasHiddenCardioModalities: Bool {
        let hiddenCardio = CardioExercise.catalog.count - visibleCardioExercises.count
        return hiddenCardio > 0 || !showsFightCard
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let duoName = workoutStore.activeDuoTeamName ?? workoutStore.activeDuoTeamId {
                        let mods = workoutStore.activeDuoTeamModalities
                        let modsLabel = mods.isEmpty
                            ? "modalidades do grupo"
                            : mods.map(\.rawValue).joined(separator: ", ")
                        HStack(spacing: 10) {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(AppTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Treino em equipe ativo")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("“\(duoName)” · conta só: \(modsLabel)")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Button("Desligar") {
                                workoutStore.clearDuoTeamWorkoutContext()
                            }
                            .font(.caption.weight(.semibold))
                        }
                        .padding(12)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if availableSections.count > 1 {
                        sectionPicker
                    }

                    // Global minimized banner lives on MainTabView; avoid a duplicate card here.

                    // Se musculação e cardio não estão nas modalidades, o card duo fica no topo
                    // (nas seções de musculação/cardio o card já aparece dentro da lista).
                    if !availableSections.contains(.strength), !availableSections.contains(.cardio) {
                        DuoTeamCard()
                    }

                    if availableSections.isEmpty {
                        emptyModalitiesHint
                    } else {
                        switch resolvedSelectedSection {
                        case .strength:
                            strengthSection
                        case .home:
                            homeSection
                        case .cardio:
                            cardioSection
                        case .meditation:
                            meditationSection
                        }
                    }
                }
                .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .adaptiveContentWidth()
            }
            .background(AppTheme.background)
            .navigationTitle("Treinos")
            .onAppear { alignSelectedSectionWithPreferences() }
            .onChange(of: authService.currentUser?.practicedModalityIDs) { _, _ in
                alignSelectedSectionWithPreferences()
            }
            .sheet(item: $paywallFeature) { feature in
                PaywallView(highlight: feature)
                    .environmentObject(subscriptions)
            }
            .navigationDestination(for: WorkoutSheet.self) { sheet in
                WorkoutDetailView(sheet: sheet)
            }
            .navigationDestination(for: Gender.self) { gender in
                GenderWorkoutHubView(gender: gender) { targetGender in
                    createTargetGender = targetGender
                    showCreateWorkout = true
                }
            }
            .navigationDestination(for: HomeWorkoutHubRoute.self) { _ in
                HomeWorkoutHubView()
            }
            .navigationDestination(for: MobilityWorkoutHubRoute.self) { _ in
                MobilityWorkoutHubView()
            }
            .navigationDestination(for: CardioExercise.self) { exercise in
                CardioSetupView(exercise: exercise)
                    .onAppear { discardAlignedMealPlanForOtherWorkout() }
            }
            .navigationDestination(for: SwimmingLogbookRoute.self) { _ in
                SwimmingLogbookView()
                    .onAppear { discardAlignedMealPlanForOtherWorkout() }
            }
            .navigationDestination(for: BikeLogbookRoute.self) { _ in
                BikeLogbookView()
                    .onAppear { discardAlignedMealPlanForOtherWorkout() }
            }
            .navigationDestination(for: SurfKiteLogbookRoute.self) { route in
                SurfKiteLogbookView(initialKitesurfOnly: route.kitesurfOnly)
                    .onAppear { discardAlignedMealPlanForOtherWorkout() }
            }
            .navigationDestination(for: ClimbingLogbookRoute.self) { _ in
                ClimbingLogbookView()
                    .onAppear { discardAlignedMealPlanForOtherWorkout() }
            }
            .navigationDestination(for: ClimbingMapRoute.self) { _ in
                ClimbingMapView()
            }
            .navigationDestination(for: FightHubRoute.self) { _ in
                FightHubView()
                    .onAppear { discardAlignedMealPlanForOtherWorkout() }
            }
            .navigationDestination(for: MeditationTopic.self) { topic in
                MeditationSetupView(topic: topic)
                    .onAppear { discardAlignedMealPlanForOtherWorkout() }
            }
            .navigationDestination(for: GuidedLevelRoute.self) { route in
                GuidedWorkoutCategoryView(
                    title: route.level.pluralTitle,
                    subtitle: route.level.subtitle,
                    accent: route.level.accentColor,
                    templates: GuidedWorkoutCatalog.templates(for: route.level),
                    gender: route.gender
                )
            }
            .navigationDestination(for: GuidedFocusRoute.self) { route in
                GuidedWorkoutCategoryView(
                    title: route.focus.shortTitle,
                    subtitle: route.focus.subtitle,
                    accent: route.focus.accentColor,
                    templates: GuidedWorkoutCatalog.templates(for: route.focus),
                    gender: route.gender
                )
            }
            .sheet(isPresented: $showCreateWorkout) {
                CreateWorkoutView(initialTargetGender: createTargetGender)
            }
            .sheet(item: $sheetToEdit) { sheet in
                CreateWorkoutView(editingSheet: sheet)
            }
            .alert("Excluir treino?", isPresented: deletionAlertBinding) {
                Button("Excluir", role: .destructive) {
                    if let sheet = sheetPendingDeletion {
                        workoutStore.deleteWorkoutSheet(sheet)
                    }
                    sheetPendingDeletion = nil
                }
                Button("Cancelar", role: .cancel) {
                    sheetPendingDeletion = nil
                }
            } message: {
                if let sheet = sheetPendingDeletion {
                    Text("“\(sheet.title)” será removido permanentemente.")
                }
            }
        }
    }

    private var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { sheetPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    sheetPendingDeletion = nil
                }
            }
        )
    }

    private var sectionPicker: some View {
        Picker("Seção", selection: $selectedSection) {
            ForEach(availableSections) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
    }

    private var resolvedSelectedSection: WorkoutSection {
        if availableSections.contains(selectedSection) {
            return selectedSection
        }
        return availableSections.first ?? .strength
    }

    private func alignSelectedSectionWithPreferences() {
        if !availableSections.contains(selectedSection),
           let first = availableSections.first {
            selectedSection = first
        }
    }

    private var emptyModalitiesHint: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Nenhuma modalidade ativa", systemImage: "figure.run.circle")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text("Em Perfil, marque as modalidades que você pratica para montar a lista de treinos.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var homeSection: some View {
        VStack(spacing: 16) {
            Text("Treinos com peso corporal — sem academia")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            NavigationLink(value: HomeWorkoutHubRoute()) {
                HomeProgramHeroCard(
                    recommendedCount: workoutStore.homeStandardWorkoutSheets.count
                )
            }
            .buttonStyle(.plain)

            Text("Cada ficha inclui demos em vídeo/GIF dos exercícios durante o treino.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var strengthSection: some View {
        VStack(spacing: 16) {
            DuoTeamCard()

            Text("Escolha o programa")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            NavigationLink(value: Gender.male) {
                GenderProgramHeroCard(
                    gender: .male,
                    recommendedCount: workoutStore.maleStandardWorkoutSheets.count,
                    customCount: workoutStore.customWorkoutSheets(for: .male).count
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: Gender.female) {
                GenderProgramHeroCard(
                    gender: .female,
                    recommendedCount: workoutStore.femaleStandardWorkoutSheets.count,
                    customCount: workoutStore.customWorkoutSheets(for: .female).count
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: MobilityWorkoutHubRoute()) {
                MobilityProgramHeroCard(
                    recommendedCount: workoutStore.mobilityStandardWorkoutSheets.count
                )
            }
            .buttonStyle(.plain)

            Text("Mobilidade ajuda a preparar articulações para agachamento, terra, supino e desenvolvimento.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cardioSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DuoTeamCard()

            Text("Escolha um exercício e defina a intensidade")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            Text("Diários de natação, bike e surf/kite ficam dentro de cada modalidade.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            // Lista em coluna única — mesmo formato hero da musculação (altura 180).
            ForEach(visibleCardioExercises) { exercise in
                cardioExerciseEntry(exercise)
            }

            if showsFightCard {
                fightCardEntry
            }

            if hasHiddenCardioModalities {
                Text("Outras modalidades de cardio ficam em Perfil → Modalidades que pratico.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func cardioExerciseEntry(_ exercise: CardioExercise) -> some View {
        let lockedTier = lockedPlan(for: exercise)
        if let lockedTier, let feature = PlanAccessRules.requiredFeature(for: exercise) {
            Button {
                paywallFeature = feature
            } label: {
                CardioExerciseCard(exercise: exercise, lockedByPlan: lockedTier)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: exercise) {
                CardioExerciseCard(exercise: exercise)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var fightCardEntry: some View {
        let feature = AppFeature.advancedModalities
        if subscriptions.canAccess(feature) {
            NavigationLink(value: FightHubRoute()) {
                FightProgramHeroCard()
            }
            .buttonStyle(.plain)
        } else {
            Button {
                paywallFeature = feature
            } label: {
                FightProgramHeroCard(lockedByPlan: FeatureGate.minimumPlan(for: feature))
            }
            .buttonStyle(.plain)
        }
    }

    private func lockedPlan(for exercise: CardioExercise) -> PlanTier? {
        guard let feature = PlanAccessRules.requiredFeature(for: exercise) else { return nil }
        guard !subscriptions.canAccess(feature) else { return nil }
        return FeatureGate.minimumPlan(for: feature)
    }

    private var meditationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Escolha um tópico e a duração da sessão")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(MeditationTopic.catalog) { topic in
                NavigationLink(value: topic) {
                    MeditationTopicCard(topic: topic)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func discardAlignedMealPlanForOtherWorkout() {
        trainingNutritionSync.clearAlignedPlan(using: mealPlanService)
    }
}

struct HomeWorkoutHubRoute: Hashable {}
struct MobilityWorkoutHubRoute: Hashable {}

struct HomeProgramHeroCard: View {
    let recommendedCount: Int

    private let accent = Color(red: 0.35, green: 0.72, blue: 0.55)

    var body: some View {
        WorkoutProgramHeroCard(
            title: L10n.Workout.homeTitle,
            subtitle: "Full body, core, HIIT, pernas e superiores com demos",
            accent: accent,
            imageName: "WorkoutProgramHome",
            systemImage: "house.fill",
            coverColors: [accent, accent.opacity(0.55)],
            eyebrow: "SEM EQUIPAMENTOS",
            eyebrowSystemImage: "house.fill",
            footerLabels: [(icon: "star.fill", text: "\(recommendedCount) fichas recomendadas")]
        )
    }
}

struct HomeWorkoutHubView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var recommendedSheets: [WorkoutSheet] {
        workoutStore.homeStandardWorkoutSheets
    }

    private let accent = Color(red: 0.35, green: 0.72, blue: 0.55)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hubHeader

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recomendados")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Fichas de peso corporal com demonstrações durante o treino")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(recommendedSheets) { sheet in
                            NavigationLink(value: sheet) {
                                WorkoutSheetCard(sheet: sheet, iconSystemName: "house.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle("Treine em Casa")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hubHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "house.fill")
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("TREINE EM CASA")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(recommendedSheets.count) fichas · peso corporal · demos em vídeo")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct MobilityProgramHeroCard: View {
    let recommendedCount: Int

    private let accent = Color(red: 0.45, green: 0.65, blue: 0.95)

    var body: some View {
        WorkoutProgramHeroCard(
            title: L10n.Workout.mobility,
            subtitle: "Aquecimento e pós-treino com demos",
            accent: accent,
            imageName: "WorkoutProgramMobility",
            systemImage: "figure.flexibility",
            coverColors: [accent, accent.opacity(0.55)],
            eyebrow: "PARA MUSCULAÇÃO",
            eyebrowSystemImage: "figure.flexibility",
            footerLabels: [(icon: "star.fill", text: "\(recommendedCount) fichas recomendadas")]
        )
    }
}

struct MobilityWorkoutHubView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedRecentSession: WorkoutSession?

    private var recommendedSheets: [WorkoutSheet] {
        workoutStore.mobilityStandardWorkoutSheets
    }

    private var recentCompletedSessions: [WorkoutSession] {
        workoutStore.recentCompletedSessions(for: .mobility)
    }

    private let accent = Color(red: 0.45, green: 0.65, blue: 0.95)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hubHeader

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recomendados")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Duas rotinas: aquecimento geral e pós-treino, com GIFs na execução")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(recommendedSheets) { sheet in
                            NavigationLink(value: sheet) {
                                WorkoutSheetCard(sheet: sheet, iconSystemName: "figure.flexibility")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                RecentCompletedWorkoutsSection(
                    sessions: recentCompletedSessions,
                    selectedSession: $selectedRecentSession
                )
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle("Mobilidade")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedRecentSession) { session in
            WorkoutSummaryView(
                session: session,
                onFinish: { selectedRecentSession = nil }
            )
        }
    }

    private var hubHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.flexibility")
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("MOBILIDADE")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(recommendedSheets.count) fichas · preparo para carga · demos em GIF")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct GenderProgramHeroCard: View {
    let gender: Gender
    let recommendedCount: Int
    let customCount: Int

    private var title: String {
        gender == .female ? L10n.Workout.female : L10n.Workout.male
    }

    private var subtitle: String {
        gender == .female
            ? "Glúteos, pernas, postura e core"
            : "Peito, costas, pernas e ombros"
    }

    private var imageName: String {
        gender == .female ? "WorkoutProgramFemale" : "WorkoutProgramMale"
    }

    private var accent: Color {
        gender == .female ? Color(red: 0.86, green: 0.45, blue: 0.58) : AppTheme.accent
    }

    var body: some View {
        WorkoutProgramHeroCard(
            title: title,
            subtitle: subtitle,
            accent: accent,
            imageName: imageName,
            systemImage: "dumbbell.fill",
            coverColors: [accent, accent.opacity(0.55)],
            footerLabels: [
                (icon: "star.fill", text: "\(recommendedCount) recomendados"),
                (icon: "person.crop.circle", text: "\(customCount) personalizados")
            ]
        )
    }
}

struct GenderWorkoutHubView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let gender: Gender
    var onCreateCustom: (Gender) -> Void

    @State private var sheetToEdit: WorkoutSheet?
    @State private var sheetPendingDeletion: WorkoutSheet?
    @State private var selectedRecentSession: WorkoutSession?
    @State private var showScanWorkout = false

    private var title: String {
        gender == .female ? "Programa Feminino" : "Programa Masculino"
    }

    private var accent: Color {
        gender == .female ? Color(red: 0.86, green: 0.45, blue: 0.58) : AppTheme.accent
    }

    private var recommendedSheets: [WorkoutSheet] {
        workoutStore.recommendedStandardWorkouts(for: gender)
    }

    private var customSheets: [WorkoutSheet] {
        workoutStore.customWorkoutSheets(for: gender)
    }

    private var recentCompletedSessions: [WorkoutSession] {
        workoutStore.recentCompletedSessions(for: MusculacaoProgram(gender))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hubHeader

                workoutGroupSection(
                    title: "Personalizados",
                    subtitle: "Treinos criados para este programa",
                    sheets: customSheets,
                    emptyMessage: "Nenhum personalizado ainda. Toque em + para criar ou importe uma ficha (câmera, foto ou PDF)."
                )

                GuidedWorkoutSections(gender: gender)

                workoutGroupSection(
                    title: "Recomendados",
                    subtitle: recommendedSubtitle,
                    sheets: recommendedSheets
                )

                RecentCompletedWorkoutsSection(
                    sessions: recentCompletedSessions,
                    selectedSession: $selectedRecentSession
                )
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            _ = workoutStore.refreshRecommendedRotationIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        showScanWorkout = true
                    } label: {
                        Image(systemName: "doc.text.viewfinder")
                            .foregroundStyle(AppTheme.accent)
                    }
                    .accessibilityLabel("Escanear ficha de treino")

                    Button {
                        onCreateCustom(gender)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                    .accessibilityLabel("Criar ficha personalizada")
                }
            }
        }
        .sheet(isPresented: $showScanWorkout) {
            ScanWorkoutSheetView(targetGender: gender)
        }
        .sheet(item: $sheetToEdit) { sheet in
            CreateWorkoutView(editingSheet: sheet)
        }
        .sheet(item: $selectedRecentSession) { session in
            WorkoutSummaryView(
                session: session,
                onFinish: { selectedRecentSession = nil }
            )
        }
        .alert("Excluir treino?", isPresented: deletionAlertBinding) {
            Button("Excluir", role: .destructive) {
                if let sheet = sheetPendingDeletion {
                    workoutStore.deleteWorkoutSheet(sheet)
                }
                sheetPendingDeletion = nil
            }
            Button("Cancelar", role: .cancel) {
                sheetPendingDeletion = nil
            }
        } message: {
            if let sheet = sheetPendingDeletion {
                Text("“\(sheet.title)” será removido permanentemente.")
            }
        }
    }

    private var hubHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: gender == .female ? "figure.strengthtraining.traditional" : "dumbbell.fill")
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(gender == .female ? "FEMININO" : "MASCULINO")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(recommendedSheets.count) recomendados · \(customSheets.count) personalizados")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var recommendedSubtitle: String {
        let days = RecommendedWorkoutCatalog.daysUntilNextRotation()
        let base = "Fichas do programa \(gender == .female ? "feminino" : "masculino")"
        if days >= RecommendedWorkoutCatalog.rotationIntervalDays {
            return "\(base) · novas opções a cada 30 dias"
        }
        return "\(base) · novas opções em \(days) dia\(days == 1 ? "" : "s")"
    }

    private var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { sheetPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    sheetPendingDeletion = nil
                }
            }
        )
    }

    private func workoutGroupSection(
        title: String,
        subtitle: String,
        sheets: [WorkoutSheet],
        emptyMessage: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if sheets.isEmpty, let emptyMessage {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sheets) { sheet in
                        workoutSheetRow(sheet)
                    }
                }
            }
        }
    }

    private func workoutSheetRow(_ sheet: WorkoutSheet) -> some View {
        NavigationLink(value: sheet) {
            WorkoutSheetCard(
                sheet: sheet,
                showsPersonalBadge: workoutStore.canModify(sheet)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if workoutStore.canModify(sheet) {
                Button {
                    sheetToEdit = sheet
                } label: {
                    Label("Editar", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    sheetPendingDeletion = sheet
                } label: {
                    Label("Excluir", systemImage: "trash")
                }
            }
        }
    }
}

struct RecentCompletedWorkoutsSection: View {
    let sessions: [WorkoutSession]
    @Binding var selectedSession: WorkoutSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Últimos treinos")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Até 4 sessões concluídas neste programa")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if sessions.isEmpty {
                Text("Nenhum treino realizado ainda.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sessions) { session in
                        Button {
                            selectedSession = session
                        } label: {
                            RecentWorkoutSessionCard(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct RecentWorkoutSessionCard: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.workoutTitle)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 12) {
                    Label("\(Int(session.duration / 60)) min", systemImage: "clock")
                    if session.caloriesBurned > 0 {
                        Label("\(Int(session.caloriesBurned)) kcal", systemImage: "flame")
                    }
                    if session.totalExercises > 0 {
                        Label(
                            "\(session.completedExercises)/\(session.totalExercises)",
                            systemImage: "list.bullet"
                        )
                    }
                }
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct WorkoutSheetCard: View {
    let sheet: WorkoutSheet
    var showsPersonalBadge = false
    var iconSystemName: String?

    private var resolvedIcon: String {
        if let iconSystemName { return iconSystemName }
        if sheet.createdByAssistant { return "bubble.left.and.bubble.right.fill" }
        if sheet.title.lowercased().hasPrefix("casa") { return "house.fill" }
        if sheet.title.lowercased().hasPrefix("mobilidade") { return "figure.flexibility" }
        return "dumbbell.fill"
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: resolvedIcon)
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(sheet.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    if sheet.createdByAssistant {
                        Text("IAssistente")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 0.35, green: 0.55, blue: 0.95))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.15))
                            .clipShape(Capsule())
                    } else if showsPersonalBadge {
                        Text("Personalizado")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.accent.opacity(0.15))
                            .clipShape(Capsule())
                    } else if sheet.title.lowercased().hasPrefix("casa") {
                        Text("Treine em Casa")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 0.35, green: 0.72, blue: 0.55))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.35, green: 0.72, blue: 0.55).opacity(0.15))
                            .clipShape(Capsule())
                    } else if sheet.title.lowercased().hasPrefix("mobilidade") {
                        Text("Mobilidade")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 0.45, green: 0.65, blue: 0.95))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.45, green: 0.65, blue: 0.95).opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(sheet.description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Label("\(sheet.totalExercises) exercícios", systemImage: "list.bullet")
                    Label("~\(sheet.estimatedDuration / 60) min", systemImage: "clock")
                }
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct ActiveWorkoutBanner: View {
    let session: WorkoutSession
    var currentExerciseName: String? = nil
    var onResume: (() -> Void)? = nil
    var onEnd: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onResume?()
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Treino em andamento: \(session.workoutTitle)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        if let currentExerciseName, !currentExerciseName.isEmpty {
                            Text(currentExerciseName)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text("\(session.completedExercises)/\(session.totalExercises)")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.accent)
                    Image(systemName: "arrow.up.right.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onResume == nil)
            .accessibilityHint("Retomar treino em andamento")

            if let onEnd {
                Button("Encerrar", action: onEnd)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.trailing, 14)
                    .accessibilityHint("Encerrar treino em andamento")
            }
        }
        .background(AppTheme.accent.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
