import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var timerService: RestTimerService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var wellnessService: DailyWellnessService
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var evolutionService: BodyEvolutionService
    @EnvironmentObject var subscriptions: SubscriptionService
    @ObservedObject private var nutritionNotifPrefs = NutritionNotificationPreferences.shared
    @ObservedObject private var bleHeartRate = BluetoothHeartRateService.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountSheet = false
    @State private var showPhotoSourceDialog = false
    @State private var showProfileGalleryPicker = false
    @State private var showProfileCameraPicker = false
    @State private var showBackgroundSourceDialog = false
    @State private var showBackgroundGalleryPicker = false
    @State private var showBackgroundCameraPicker = false
    @State private var trainerName = ""
    @State private var trainerEmail = ""
    @State private var usesPersonalTrainer = false
    @State private var nutritionistName = ""
    @State private var nutritionistEmail = ""
    @State private var usesNutritionist = false
    @State private var displayName = ""
    @State private var sleepHoursInput: Double = 7
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
    @State private var showMeasurementsSavedAlert = false
    @State private var measurementsSaveError: String?
    @State private var measurementComparison: BodyMeasurementComparison?
    @State private var showMeasurementComparison = false
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -28, to: .now) ?? .now
    @State private var selectedCountryCode = CountryOption.defaultCode()
    @State private var selectedGender: Gender = .male
    @State private var tracksMenstrualCycle = false
    @State private var lastPeriodStart = Calendar.current.startOfDay(for: .now)
    @State private var cycleLengthDays = 28
    @State private var periodLengthDays = 5
    @State private var showLastPeriodSheet = false
    @State private var showBodyDataSavedAlert = false
    @State private var showEmptyMeasurementsAlert = false
    @State private var bodyDataSaveError: String?
    @State private var showSaveFailedAlert = false
    /// Phase 2 of profile content (heavy forms). First paint stays lean to avoid jetsam / UIDatePicker crashes.
    @State private var showSecondarySections = false
    @State private var showDateOfBirthSheet = false
    @State private var physicalAssessmentPDFURL: URL?
    @State private var showPhysicalAssessmentShare = false
    @State private var showPhysicalAssessmentEmptyAlert = false
    @State private var isGeneratingPhysicalAssessmentPDF = false
    @State private var showMeasurementsEditor = false

    var body: some View {
        NavigationStack {
            profileList
                .adaptiveContentWidth()
                .navigationTitle("Perfil")
                .scrollDismissesKeyboard(.interactively)
                // No keyboard toolbar on this List — avoids TabView+List toolbar race that can abort the process.
                .task { await handleProfileAppear() }
                .onChange(of: authService.currentUser?.id) { _, _ in
                    syncTrainerFields()
                    syncDisplayNameField()
                    syncBodyMeasurementFields()
                    syncBodyDataFields()
                }
                .onChange(of: measurementsSaveError) { _, error in
                    if error != nil { showSaveFailedAlert = true }
                }
                .onChange(of: bodyDataSaveError) { _, error in
                    if error != nil { showSaveFailedAlert = true }
                }
                .sheet(isPresented: $showDateOfBirthSheet) {
                    dateOfBirthPickerSheet
                }
                .sheet(isPresented: $showLastPeriodSheet) {
                    lastPeriodPickerSheet
                }
                .profilePhotoPickers(
                    showPhotoSourceDialog: $showPhotoSourceDialog,
                    showBackgroundSourceDialog: $showBackgroundSourceDialog,
                    showProfileGalleryPicker: $showProfileGalleryPicker,
                    showProfileCameraPicker: $showProfileCameraPicker,
                    showBackgroundGalleryPicker: $showBackgroundGalleryPicker,
                    showBackgroundCameraPicker: $showBackgroundCameraPicker,
                    hasBackgroundImage: authService.profileBackgroundImage != nil,
                    onProfileImage: { image in
                        authService.updateProfileImage(image)
                    },
                    onBackgroundImage: { image in
                        authService.updateProfileBackgroundImage(image)
                    },
                    onRemoveBackground: {
                        authService.updateProfileBackgroundImage(nil)
                    }
                )
                .profileAlertsAndSheets(
                    showLogoutAlert: $showLogoutAlert,
                    showMeasurementsSavedAlert: $showMeasurementsSavedAlert,
                    showBodyDataSavedAlert: $showBodyDataSavedAlert,
                    showEmptyMeasurementsAlert: $showEmptyMeasurementsAlert,
                    showSaveFailedAlert: $showSaveFailedAlert,
                    measurementsSaveError: measurementsSaveError,
                    bodyDataSaveError: bodyDataSaveError,
                    includesMenstrualCycleInSaveMessage: selectedGender == .female,
                    showMeasurementComparison: $showMeasurementComparison,
                    measurementComparison: measurementComparison,
                    cycleAdvice: measurementCycleAdvice,
                    showDeleteAccountSheet: $showDeleteAccountSheet,
                    usesPasswordProvider: authService.usesPasswordProvider,
                    usesAppleProvider: authService.usesAppleProvider,
                    onLogout: {
                        authService.logout(
                            workoutStore: workoutStore,
                            mealPlanService: mealPlanService,
                            wellnessService: wellnessService,
                            evolutionService: evolutionService
                        )
                    },
                    onClearSaveErrors: {
                        measurementsSaveError = nil
                        bodyDataSaveError = nil
                    }
                )
                .sheet(isPresented: $showMeasurementsEditor) {
                    measurementsEditorSheet
                }
                .sheet(isPresented: $showPhysicalAssessmentShare) {
                    if let physicalAssessmentPDFURL {
                        ActivityShareSheet(items: [physicalAssessmentPDFURL]) {
                            showPhysicalAssessmentShare = false
                        }
                    }
                }
                .overlay {
                    if isGeneratingPhysicalAssessmentPDF {
                        ZStack {
                            Color.black.opacity(0.25).ignoresSafeArea()
                            ProgressView("Gerando PDF…")
                                .padding(20)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .allowsHitTesting(true)
                    }
                }
                .alert("Medidas necessárias", isPresented: $showPhysicalAssessmentEmptyAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Preencha peso ou ao menos uma circunferência para exportar a avaliação em PDF.")
                }
        }
    }

    @ViewBuilder
    private var profileList: some View {
        List {
            if let user = authService.currentUser {
                // Phase 1 — always light / safe
                profileHeaderSection(for: user)
                subscriptionPlanSection
                displayNameSection(for: user)
                accountRoleSection(for: user)

                if showSecondarySections {
                    biotypeSection(for: user)
                    practicedModalitiesSection(for: user)
                    personalTrainerSection
                    nutritionistSection
                    healthIconSection
                    Section("Sono e Hidratação") {
                        wellnessSection(for: user)
                    }
                    Section("Energéticos e Pré-treino") {
                        energyDrinksSection
                    }
                    Section("Seus Dados") {
                        bodyDataSection(for: user)
                    }
                    Section("Medidas Corporais") {
                        bodyMeasurementsSection(for: user)
                    }
                    bodyEvolutionSection
                    integrationsSection
                    nutritionNotificationsSection
                    restTimerSection
                    aboutSection
                    Section("Legal") {
                        LegalLinksView(style: .list, showsSupportLink: true)
                    }
                    AppFeedbackFormSections()
                } else {
                    Section {
                        HStack {
                            ProgressView()
                                .tint(AppTheme.accent)
                            Text("Carregando seu perfil…")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }

                // Always last: language + leave / delete account
                languageSection
                accountActionsSection
            } else {
                Section {
                    Text("Sessão não disponível. Faça login novamente.")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private var dateOfBirthPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Data de nascimento",
                    selection: safeDateOfBirthBinding,
                    in: Self.safeDateOfBirthRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()

                Text("Idade: \(UserProfile.age(from: dateOfBirth)) anos · necessário entre \(UserProfile.minimumAgeYears) e \(UserProfile.maximumAgeYears)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Nascimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        dateOfBirth = Self.clampedDate(dateOfBirth)
                        showDateOfBirthSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            dateOfBirth = Self.clampedDate(dateOfBirth)
        }
    }

    private var lastPeriodPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Primeiro dia da última menstruação",
                    selection: $lastPeriodStart,
                    in: Self.lastPeriodDateRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()

                Text("Informe o primeiro dia de sangramento do ciclo mais recente.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Última menstruação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        lastPeriodStart = Calendar.current.startOfDay(for: lastPeriodStart)
                        showLastPeriodSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private static var lastPeriodDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let oldest = calendar.date(byAdding: .day, value: -400, to: today) ?? today
        return oldest...today
    }

    private var measurementCycleAdvice: MenstrualCycleMeasurementAdvice? {
        guard let user = authService.currentUser else { return nil }
        let hasChanges = measurementComparison?.hasChanges == true
        return user.bodyMeasurementCycleAdvice(
            measurementDate: measurementComparison?.current.measuredAt ?? .now,
            hasMeasurementChanges: hasChanges
        )
    }

    /// Clamped two-way binding so UIDatePicker never receives out-of-range values.
    private var safeDateOfBirthBinding: Binding<Date> {
        Binding(
            get: { Self.clampedDate(dateOfBirth) },
            set: { dateOfBirth = Self.clampedDate($0) }
        )
    }

    private var safeCountryCodeBinding: Binding<String> {
        Binding(
            get: { CountryOption.resolvedCode(selectedCountryCode) },
            set: { selectedCountryCode = CountryOption.resolvedCode($0) }
        )
    }

    private static var safeDateOfBirthRange: ClosedRange<Date> {
        let minDate = minimumDateOfBirth()
        let maxDate = maximumDateOfBirth()
        return minDate <= maxDate ? minDate...maxDate : maxDate...minDate
    }

    private static func clampedDate(_ date: Date, now: Date = .now) -> Date {
        let range = {
            let minDate = minimumDateOfBirth(now: now)
            let maxDate = maximumDateOfBirth(now: now)
            return minDate <= maxDate ? minDate...maxDate : maxDate...minDate
        }()
        return min(max(date, range.lowerBound), range.upperBound)
    }

    private var bodyEvolutionSection: some View {
        Section("Evolução Corporal") {
            NavigationLink {
                BodyEvolutionView()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Fotos e comparativo (30 dias)", systemImage: "camera.viewfinder")
                    Text(evolutionService.meta.statusLabel)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Fotos opcionais e privadas — só você acessa.")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
    }

    @MainActor
    private func handleProfileAppear() async {
        // Sync lightweight fields first (header / name) before any heavy List sections mount.
        syncTrainerFields()
        syncDisplayNameField()
        syncBodyDataFields()

        await Task.yield()
        try? await Task.sleep(nanoseconds: 80_000_000)

        syncWellnessFields()
        syncBodyMeasurementFields()
        showSecondarySections = true

        await Task.yield()
        try? await Task.sleep(nanoseconds: 120_000_000)

        syncPreWorkoutFromWorkouts()
        if let userId = authService.currentUser?.id {
            Task { await evolutionService.loadIfNeeded(userId: userId) }
        }
    }

    private var profilePlanPriceHint: String {
        if subscriptions.isProductAvailable(tier: .basic, period: .monthly) {
            return "A partir de \(subscriptions.displayPrice(for: .basic, period: .monthly))"
        }
        return "Ver planos"
    }

    private var subscriptionPlanSection: some View {
        Section("Assinatura") {
            NavigationLink {
                SubscriptionPlanView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(AppTheme.accentSecondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Meu plano")
                        Text(subscriptions.currentTier.displayName)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    if subscriptions.currentTier == .free {
                        Text(profilePlanPriceHint)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func profileHeaderSection(for user: UserProfile) -> some View {
        let profileImage = authService.profileImage
        let backgroundImage = authService.profileBackgroundImage
        Section {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    Button {
                        presentBackgroundPhotoSource()
                    } label: {
                        Group {
                            if let backgroundImage {
                                Image(uiImage: backgroundImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                LinearGradient(
                                    colors: [
                                        AppTheme.accent.opacity(0.55),
                                        AppTheme.accentSecondary.opacity(0.35),
                                        AppTheme.cardBackground
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .overlay {
                                    VStack(spacing: 6) {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.title2)
                                        Text("Toque para foto de fundo")
                                            .font(.caption2.weight(.medium))
                                    }
                                    .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                    }
                    .buttonStyle(ListSafeButtonStyle())

                    HStack(alignment: .bottom) {
                        Spacer()
                        Text(backgroundImage == nil ? "Fundo" : "Alterar fundo")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Capsule())
                            .padding(10)
                    }
                }

                HStack(alignment: .center, spacing: 14) {
                    Button {
                        presentProfilePhotoSource()
                    } label: {
                        ProfileAvatarView(
                            image: profileImage,
                            initial: String(user.greetingName.prefix(1).uppercased()),
                            countryFlag: user.countryFlagEmoji
                        )
                        .contentShape(Circle())
                    }
                    .buttonStyle(ListSafeButtonStyle())
                    .offset(y: -28)
                    .padding(.bottom, -28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.shownName)
                            .font(.headline)
                        Text(user.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(user.countryFlagEmoji) \(user.countryDisplayName)")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(profileImage == nil ? "Toque no avatar para foto" : "Toque no avatar para alterar")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)

                    let healthStatus = wellnessService.healthIconStatus()
                    PulsingHeartIconView(
                        size: 36,
                        glowColor: healthStatus.glowColor
                    )
                    .accessibilityLabel(healthStatus.title)
                    .accessibilityValue(wellnessService.healthIconDetailMessage())
                    .padding(.top, 8)

                    if profileImage != nil {
                        Button {
                            authService.updateProfileImage(nil)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(ListSafeButtonStyle())
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }

    private func presentProfilePhotoSource() {
        if PhotoCaptureAvailability.isCameraAvailable {
            showPhotoSourceDialog = true
        } else {
            showProfileGalleryPicker = true
        }
    }

    private func presentBackgroundPhotoSource() {
        if PhotoCaptureAvailability.isCameraAvailable {
            showBackgroundSourceDialog = true
        } else {
            showBackgroundGalleryPicker = true
        }
    }

    @ViewBuilder
    private func displayNameSection(for user: UserProfile) -> some View {
        Section("Como você gostaria de ser chamado?") {
            TextField("Seu apelido ou primeiro nome", text: $displayName)
                .textContentType(.nickname)
                .onChange(of: displayName) { _, _ in
                    saveDisplayName()
                }

            if !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               displayName.trimmingCharacters(in: .whitespacesAndNewlines) != user.name {
                Text("Nome completo: \(user.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Usado nas saudações, motivação e mensagens do app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func accountRoleSection(for _: UserProfile) -> some View {
        Section(L10n.Profile.accountRole) {
            AccountRolePicker(selection: accountRoleBinding)
            Text("Aluno treina com o app. Personal e nutricionista usam como profissionais — dá para marcar os dois.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var accountRoleBinding: Binding<UserAccountRole> {
        Binding(
            get: { authService.currentUser?.accountRole ?? .student },
            set: { updateAccountRole($0) }
        )
    }

    private func updateAccountRole(_ role: UserAccountRole) {
        guard var user = authService.currentUser, user.accountRole != role else { return }
        user.accountRole = role
        authService.updateProfile(user)
    }

    @ViewBuilder
    private func biotypeSection(for user: UserProfile) -> some View {
        Section("Biotipo") {
            AdaptiveBiotypeRow {
                ForEach(Biotype.allCases) { biotype in
                    BiotypeCard(
                        biotype: biotype,
                        isSelected: user.biotype == biotype
                    ) {
                        updateBiotype(biotype)
                    }
                }
            }
            .padding(.vertical, 4)

            BiotypeIdentificationHint(biotype: user.biotype)
        }
        .listRowBackground(AppTheme.cardBackground)
    }

    @ViewBuilder
    private func practicedModalitiesSection(for user: UserProfile) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Marque o que você pratica. A lista de treinos mostra só as modalidades ativas.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 10) {
                    Button("Marcar todas") {
                        updatePracticedModalitiesAll(true)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                    Button("Só musculação") {
                        updatePracticedModalitiesAll(false)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                    Spacer()

                    Text("\(user.practicedModalityCount) ativas")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(.vertical, 2)

            ForEach(PracticeModalityGroup.allCases) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.rawValue.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.top, 4)

                    ForEach(PracticeModalityOption.options(in: group)) { option in
                        practicedModalityToggleRow(
                            option: option,
                            isOn: user.practices(option.id)
                        ) {
                            togglePracticedModality(option.id)
                        }
                    }
                }
            }
        } header: {
            Text("Modalidades que pratico")
        } footer: {
            Text("Perfis novos ou sem preferência exibem todas as modalidades. É preciso manter ao menos uma marcada.")
                .font(.caption2)
        }
        .listRowBackground(AppTheme.cardBackground)
    }

    private func practicedModalityToggleRow(
        option: PracticeModalityOption,
        isOn: Bool,
        onToggle: @escaping () -> Void
    ) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(.body)
                    .foregroundStyle(isOn ? AppTheme.accent : AppTheme.textSecondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(option.detail)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? AppTheme.accent : AppTheme.textSecondary.opacity(0.5))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityValue(isOn ? "Ativa" : "Inativa")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    @ViewBuilder
    private var personalTrainerSection: some View {
        Section(L10n.Profile.personalTrainer) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Profile.hasPersonalTrainer)
                    .font(.subheadline.weight(.medium))
                Picker("Possui personal?", selection: $usesPersonalTrainer) {
                    Text(L10n.Common.no).tag(false)
                    Text(L10n.Common.yes).tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: usesPersonalTrainer) { _, enabled in
                    updatePersonalTrainerAvailability(enabled)
                }
            }

            if usesPersonalTrainer {
                TextField(L10n.Profile.trainerName, text: $trainerName)
                    .textContentType(.name)
                    .onChange(of: trainerName) { _, _ in
                        savePersonalTrainer()
                    }

                TextField(L10n.Profile.trainerEmail, text: $trainerEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: trainerEmail) { _, _ in
                        savePersonalTrainer()
                    }

                if authService.currentUser?.hasPersonalTrainer == true {
                    MailAccountRequiredNotice(audience: .trainer)
                } else {
                    Text("Cadastre o e-mail para enviar relatórios após cada treino. O envio usa o app Mail deste \(MailSetupGuidance.deviceName) — é preciso ter uma conta em \(MailSetupGuidance.settingsPath).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Sem personal cadastrado. A edição de nome e e-mail fica bloqueada.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var nutritionistSection: some View {
        Section(L10n.Profile.nutritionist) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Profile.hasNutritionist)
                    .font(.subheadline.weight(.medium))
                Picker("Possui nutricionista?", selection: $usesNutritionist) {
                    Text(L10n.Common.no).tag(false)
                    Text(L10n.Common.yes).tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: usesNutritionist) { _, enabled in
                    updateNutritionistAvailability(enabled)
                }
            }

            if usesNutritionist {
                TextField(L10n.Profile.nutritionistName, text: $nutritionistName)
                    .textContentType(.name)
                    .onChange(of: nutritionistName) { _, _ in
                        saveNutritionist()
                    }

                TextField(L10n.Profile.nutritionistEmail, text: $nutritionistEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: nutritionistEmail) { _, _ in
                        saveNutritionist()
                    }

                if authService.currentUser?.hasNutritionist == true {
                    MailAccountRequiredNotice(audience: .nutritionist)
                } else {
                    Text("Cadastre o e-mail para enviar o relatório de nutrição ao nutricionista. O envio usa o app Mail deste \(MailSetupGuidance.deviceName) — é preciso ter uma conta em \(MailSetupGuidance.settingsPath).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Sem nutricionista cadastrado. A edição de nome e e-mail fica bloqueada.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var healthIconSection: some View {
        Section("Ícone de Saúde") {
            let healthStatus = wellnessService.healthIconStatus()

            HStack(alignment: .top, spacing: 14) {
                PulsingHeartIconView(
                    size: 40,
                    glowColor: healthStatus.glowColor
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(healthStatus.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(healthStatus.glowColor)

                    Text(wellnessService.healthIconDetailMessage())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("O ícone do app na tela inicial usa a mesma cor.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var integrationsSection: some View {
        Section {
            HStack {
                Label("HealthKit", systemImage: "heart.text.square.fill")
                Spacer()
                Text(healthKitManager.isAuthorized ? "Conectado" : "Pendente")
                    .foregroundStyle(healthKitManager.isAuthorized ? .green : .orange)
                    .font(.caption)
            }

            HStack {
                Label("Apple Watch", systemImage: "applewatch")
                Spacer()
                Text("Sincronização ativa")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                BluetoothHeartRateSettingsView()
            } label: {
                HStack {
                    Label("Sensor Bluetooth", systemImage: "wave.3.right.circle.fill")
                    Spacer()
                    Text(bluetoothIntegrationSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Label("Notificações", systemImage: "bell.fill")
                Spacer()
                Text("Ativas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Integrações")
        } footer: {
            Text("Passos e calorias de outros relógios entram pelo Apple Saúde. Bluetooth é para batimentos ao vivo (cintas / sensores HR).")
        }
    }

    private var bluetoothIntegrationSubtitle: String {
        if bleHeartRate.isConnected {
            return bleHeartRate.connectedDevice?.displayName ?? "Conectado"
        }
        if bleHeartRate.preferredPeripheralId != nil {
            return "Salvo"
        }
        return "Conectar"
    }

    @ViewBuilder
    private var nutritionNotificationsSection: some View {
        Section {
            Toggle(
                "Notificações de suplementos",
                isOn: Binding(
                    get: { nutritionNotifPrefs.supplementRemindersEnabled },
                    set: { enabled in
                        if enabled { NotificationService.shared.requestAuthorization() }
                        nutritionNotifPrefs.supplementRemindersEnabled = enabled
                    }
                )
            )

            Toggle(
                "Notificações de alimentação",
                isOn: Binding(
                    get: { nutritionNotifPrefs.mealRemindersEnabled },
                    set: { enabled in
                        if enabled { NotificationService.shared.requestAuthorization() }
                        nutritionNotifPrefs.mealRemindersEnabled = enabled
                    }
                )
            )

            if nutritionNotifPrefs.mealRemindersEnabled {
                ForEach(MealType.allCases) { meal in
                    DatePicker(
                        meal.rawValue,
                        selection: Binding(
                            get: { nutritionNotifPrefs.mealDate(for: meal) },
                            set: { nutritionNotifPrefs.setMealTime(for: meal, date: $0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }

                Button("Restaurar horários padrão") {
                    nutritionNotifPrefs.resetToDefaults()
                }
                .font(.subheadline)
            }
        } header: {
            Text("Notificações de Nutrição")
        } footer: {
            Text("Suplementos: lembretes a cada 3h (06h–21h) para registrar o que tomou. Alimentação: alertas no horário que você cadastrar (café, lanches, almoço, jantar e ceia).")
        }
    }

    @ViewBuilder
    private var restTimerSection: some View {
        Section("Cronômetro de Descanso") {
            Stepper(
                "Descanso padrão: \(timerService.configuredRestSeconds)s",
                value: Binding(
                    get: { timerService.configuredRestSeconds },
                    set: { timerService.configure(restSeconds: $0, maxRest: timerService.maxRestSeconds, notifications: timerService.notificationEnabled) }
                ),
                in: 15...300,
                step: 15
            )

            Stepper(
                "Alerta após: \(timerService.maxRestSeconds)s",
                value: Binding(
                    get: { timerService.maxRestSeconds },
                    set: { timerService.configure(restSeconds: timerService.configuredRestSeconds, maxRest: $0, notifications: timerService.notificationEnabled) }
                ),
                in: 30...600,
                step: 30
            )

            Toggle("Notificações de descanso", isOn: Binding(
                get: { timerService.notificationEnabled },
                set: { timerService.configure(restSeconds: timerService.configuredRestSeconds, maxRest: timerService.maxRestSeconds, notifications: $0) }
            ))
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section("Sobre") {
            LabeledContent("App", value: "HealthFit")
            LabeledContent("Versão", value: AppInfo.appVersion)
        }
    }

    private var languageSection: some View {
        Section(L10n.Settings.language) {
            LanguagePickerControl(style: .listRow)
        }
    }

    @ViewBuilder
    private var accountActionsSection: some View {
        Section {
            Button("Sair da Conta", role: .destructive) {
                showLogoutAlert = true
            }

            Button("Excluir Conta", role: .destructive) {
                showDeleteAccountSheet = true
            }
        }
    }

    private func syncTrainerFields() {
        trainerName = authService.currentUser?.personalTrainerName ?? ""
        trainerEmail = authService.currentUser?.personalTrainerEmail ?? ""
        usesPersonalTrainer = authService.currentUser?.usesPersonalTrainer ?? false
        nutritionistName = authService.currentUser?.nutritionistName ?? ""
        nutritionistEmail = authService.currentUser?.nutritionistEmail ?? ""
        usesNutritionist = authService.currentUser?.usesNutritionist ?? false
    }

    private func syncDisplayNameField() {
        displayName = authService.currentUser?.displayName ?? ""
    }

    private func saveDisplayName() {
        guard var user = authService.currentUser else { return }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard user.displayName != trimmed else { return }
        user.displayName = trimmed
        authService.updateProfile(user)
    }

    @ViewBuilder
    private func wellnessSection(for user: UserProfile) -> some View {
        let displayedSleepHours = wellnessService.todaySleepHours ?? sleepHoursInput

        VStack(alignment: .leading, spacing: 12) {
            Text("Horas de sono (hoje)")
                .font(.subheadline.weight(.medium))

            HStack {
                Text(String(format: "%.1f h", displayedSleepHours))
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                if let assessment = wellnessService.todaySleepAssessment {
                    Label(assessment.title, systemImage: assessment.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(assessment.color)
                } else {
                    let preview = SleepAssessment.evaluate(hours: displayedSleepHours)
                    Label(preview.title, systemImage: preview.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(preview.color)
                }
            }

            Slider(
                value: Binding(
                    get: { wellnessService.todaySleepHours ?? sleepHoursInput },
                    set: { newValue in
                        sleepHoursInput = newValue
                        wellnessService.logSleep(hours: newValue)
                    }
                ),
                in: 0...12,
                step: 0.5
            )
                .tint(AppTheme.accent)

            if let assessment = wellnessService.todaySleepAssessment {
                Text(assessment.message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Text("Registre seu sono ao abrir o app ou ajuste o controle acima.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Água recomendada")
                    .font(.subheadline.weight(.medium))
                Text(compactTodayDateLabel)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            HStack {
                Label(
                    String(format: "%.1f L / dia", user.recommendedDailyWaterLiters),
                    systemImage: "drop.fill"
                )
                .foregroundStyle(.blue)
                Spacer()
                Text("\(user.recommendedDailyWaterML) ml")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Text("Cálculo: 35 ml por kg de peso corporal (\(String(format: "%.1f", user.weight)) kg). Equivale a cerca de \(user.recommendedWaterGlasses) copos (\(WaterServing.glassML) ml) ou \(user.recommendedWaterBottles) garrafas (\(WaterServing.bottleML) ml).")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            ProgressView(value: wellnessService.waterProgress(for: user))
                .tint(
                    wellnessService.hasMetWaterGoal(for: user)
                        ? AppTheme.accent
                        : .red
                )

            HStack {
                Text("\(wellnessService.todayEntry.waterIntakeMl) ml ingeridos")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        wellnessService.hasMetWaterGoal(for: user)
                            ? AppTheme.accent
                            : .red
                    )
                Spacer()
                Text(wellnessService.waterStatusMessage(for: user))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(
                        wellnessService.hasMetWaterGoal(for: user)
                            ? AppTheme.accent
                            : .red
                    )
                    .multilineTextAlignment(.trailing)
            }

            Stepper(
                "Copos (\(WaterServing.glassML) ml): \(wellnessService.todayEntry.waterIntakeMl / WaterServing.glassML)",
                value: Binding(
                    get: { wellnessService.todayEntry.waterIntakeMl / WaterServing.glassML },
                    set: { newCount in
                        wellnessService.updateWaterIntake(newCount * WaterServing.glassML)
                    }
                ),
                in: 0...WaterServing.maxDailyIntakeML / WaterServing.glassML,
                step: 1
            )

            Stepper(
                "Garrafas (\(WaterServing.bottleML) ml): \(wellnessService.todayEntry.waterIntakeMl / WaterServing.bottleML)",
                value: Binding(
                    get: { wellnessService.todayEntry.waterIntakeMl / WaterServing.bottleML },
                    set: { newCount in
                        wellnessService.updateWaterIntake(newCount * WaterServing.bottleML)
                    }
                ),
                in: 0...WaterServing.maxDailyIntakeML / WaterServing.bottleML,
                step: 1
            )

            HStack(spacing: 10) {
                Button("+1 copo") { wellnessService.addWater(WaterServing.glassML) }
                Button("+1 garrafa") { wellnessService.addWater(WaterServing.bottleML) }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 4)

        VStack(alignment: .leading, spacing: 10) {
            Toggle(
                isOn: Binding(
                    get: { wellnessService.todayEntry.isRestDay },
                    set: { isRestDay in
                        if isRestDay {
                            wellnessService.markRestDay(
                                assistantContext: restDayAssistantContext(for: user)
                            )
                        } else {
                            wellnessService.clearRestDay()
                        }
                    }
                )
            ) {
                Label("Hoje é dia de descanso", systemImage: "bed.double.fill")
                    .font(.subheadline.weight(.medium))
            }
            .tint(AppTheme.accent)

            Text(
                wellnessService.todayEntry.isRestDay
                    ? "Descanso registrado — o IAssistente envia orientações sobre recuperação e hipertrofia."
                    : "Marque a qualquer hora. Meditação não substitui um dia off de treino pesado."
            )
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private func restDayAssistantContext(for user: UserProfile) -> HealthAssistantContext {
        HealthAssistantContext(
            user: user,
            waterIntakeMl: wellnessService.todayEntry.waterIntakeMl,
            sleepHours: wellnessService.todayEntry.sleepHours,
            weeklyWorkoutCount: 0,
            hoursSinceLastWorkout: nil,
            todayWorkoutSessions: [],
            recentWorkoutSessions: workoutStore.sessionHistory,
            dailyCalorieTarget: user.dailyCalorieTarget,
            basalMetabolicRate: user.basalMetabolicRate,
            estimatedTDEE: user.estimatedTDEE,
            caloricDeficit: user.caloricDeficit,
            sweetConsumption: mealPlanService.customMenuSelection.sweetConsumption,
            lactoseTolerance: mealPlanService.customMenuSelection.lactoseTolerance,
            hasMealPlan: false,
            todayMealsCompleted: 0,
            todayMealsTotal: 0,
            weekMealsCompleted: 0,
            weekMealsTotal: 0,
            todayCaloriesConsumed: 0,
            todayHealthKitActiveCalories: 0,
            supplementsLoggedToday: wellnessService.todaySupplementIntakes.count,
            isTodayRestDay: true,
            consecutiveTrainingDays: WeeklyProgressAnalyzer.consecutiveTrainingDays(
                in: workoutStore.sessionHistory
            )
        )
    }

    /// Compact `dd/MM` for today’s wellness day (updates when `todayEntry` rolls over).
    private var compactTodayDateLabel: String {
        let parser = DateFormatter()
        parser.calendar = Calendar.current
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        let date = parser.date(from: wellnessService.todayEntry.dayKey) ?? Date()
        let display = DateFormatter()
        display.locale = Locale(identifier: "pt_BR")
        display.dateFormat = "dd/MM"
        return display.string(from: date)
    }

    private func syncWellnessFields() {
        if let hours = wellnessService.todaySleepHours {
            sleepHoursInput = hours
        }
    }

    private func syncPreWorkoutFromWorkouts() {
        wellnessService.applyPreWorkoutFromWorkouts(trackedWorkoutSessions)
    }

    private var trackedWorkoutSessions: [WorkoutSession] {
        var sessions = workoutStore.sessionHistory
        if let activeSession = workoutStore.activeSession {
            sessions.append(activeSession)
        }
        return sessions
    }

    private var todayPreWorkoutEntries: [PreWorkoutSessionEntry] {
        WorkoutReportBuilder.todayPreWorkoutEntries(from: trackedWorkoutSessions)
    }

    @ViewBuilder
    private var energyDrinksSection: some View {
        let energyCount = wellnessService.todayEntry.energyDrinksCount
        let preWorkoutCount = wellnessService.todayEntry.preWorkoutCount

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quantos energéticos você bebe durante o dia?")
                    .font(.subheadline.weight(.medium))

                HStack {
                    Label(
                        energyCount == 0 ? "Nenhum" : "\(energyCount) hoje",
                        systemImage: "bolt.fill"
                    )
                    .font(.title3.bold())
                    .foregroundStyle(energyCount > 1 ? .orange : AppTheme.accent)

                    Spacer()

                    Text(energyCount == 1 ? "1 unidade" : "\(energyCount) unidades")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Stepper(
                    value: Binding(
                        get: { wellnessService.todayEntry.energyDrinksCount },
                        set: { wellnessService.updateEnergyDrinksCount($0) }
                    ),
                    in: 0...10,
                    step: 1
                ) {
                    Text("Energéticos hoje")
                }

                if energyCount > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Alerta OMS", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text(SupplementGuidance.whoEnergyDrinkWarning)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else if energyCount == 0 {
                    Text("Ótimo! Menos cafeína ajuda no sono e na recuperação muscular.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Text("Consumo moderado. Evite energéticos à noite para não prejudicar o sono.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Quantos pré-treinos você tomou hoje?")
                    .font(.subheadline.weight(.medium))

                HStack {
                    Label(
                        preWorkoutCount == 0 ? "Nenhum" : "\(preWorkoutCount) hoje",
                        systemImage: "flame.fill"
                    )
                    .font(.title3.bold())
                    .foregroundStyle(preWorkoutCount > 1 ? .orange : AppTheme.accentSecondary)

                    Spacer()

                    Text(preWorkoutCount == 1 ? "1 dose" : "\(preWorkoutCount) doses")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Stepper(
                    value: Binding(
                        get: { wellnessService.todayEntry.preWorkoutCount },
                        set: { wellnessService.updatePreWorkoutCount($0) }
                    ),
                    in: 0...5,
                    step: 1
                ) {
                    Text("Pré-treino hoje")
                }

                if !todayPreWorkoutEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Registrado ao iniciar treino")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)

                        ForEach(todayPreWorkoutEntries) { entry in
                            HStack(spacing: 8) {
                                Image(systemName: entry.tookPreWorkout ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(entry.tookPreWorkout ? AppTheme.accent : AppTheme.textSecondary)

                                Text(entry.workoutTitle)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Text(entry.tookPreWorkout ? "Sim, tomei" : "Não tomei")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(entry.tookPreWorkout ? AppTheme.accent : AppTheme.textSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text("Ao iniciar um treino, sua resposta sobre pré-treino aparecerá aqui.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if preWorkoutCount > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Alerta de pré-treino", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text(SupplementGuidance.preWorkoutDailyLimitWarning)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if preWorkoutCount == 1 {
                    Text("Consumo dentro do limite diário recomendado.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Text(SupplementGuidance.preWorkoutCaffeineLimit.capitalized + ".")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if wellnessService.tookPreWorkoutAndEnergyDrinkToday {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Alerta de cafeína", systemImage: "exclamationmark.octagon.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                    Text(SupplementGuidance.preWorkoutAndEnergyDrinkWarning)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.vertical, 4)
    }

    private func updatePersonalTrainerAvailability(_ enabled: Bool) {
        guard var user = authService.currentUser else { return }
        if !enabled {
            trainerName = ""
            trainerEmail = ""
            user.personalTrainerName = ""
            user.personalTrainerEmail = ""
        }
        guard user.usesPersonalTrainer != enabled
                || user.personalTrainerName != trainerName
                || user.personalTrainerEmail != trainerEmail else { return }
        user.usesPersonalTrainer = enabled
        authService.updateProfile(user)
    }

    private func togglePracticedModality(_ modalityID: String) {
        guard var user = authService.currentUser else { return }
        let currentlyOn = user.practices(modalityID)
        user.setPractices(modalityID, enabled: !currentlyOn)
        authService.updateProfile(user)
    }

    private func updatePracticedModalitiesAll(_ enabled: Bool) {
        guard var user = authService.currentUser else { return }
        user.setPracticesAll(enabled)
        authService.updateProfile(user)
    }

    private func updateNutritionistAvailability(_ enabled: Bool) {
        guard var user = authService.currentUser else { return }
        if !enabled {
            nutritionistName = ""
            nutritionistEmail = ""
            user.nutritionistName = ""
            user.nutritionistEmail = ""
        }
        guard user.usesNutritionist != enabled
                || user.nutritionistName != nutritionistName
                || user.nutritionistEmail != nutritionistEmail else { return }
        user.usesNutritionist = enabled
        authService.updateProfile(user)
    }

    private func savePersonalTrainer() {
        guard usesPersonalTrainer else { return }
        guard var user = authService.currentUser else { return }
        let name = trainerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = trainerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard user.personalTrainerName != name
                || user.personalTrainerEmail != email
                || !user.usesPersonalTrainer else { return }
        user.usesPersonalTrainer = true
        user.personalTrainerName = name
        user.personalTrainerEmail = email
        authService.updateProfile(user)
    }

    private func saveNutritionist() {
        guard usesNutritionist else { return }
        guard var user = authService.currentUser else { return }
        let name = nutritionistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = nutritionistEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard user.nutritionistName != name
                || user.nutritionistEmail != email
                || !user.usesNutritionist else { return }
        user.usesNutritionist = true
        user.nutritionistName = name
        user.nutritionistEmail = email
        authService.updateProfile(user)
    }

    private func syncBodyDataFields() {
        guard let user = authService.currentUser else { return }
        weightText = String(format: "%.1f", user.weight)
        heightText = String(format: "%.0f", user.height)
        dateOfBirth = Self.clampedDateOfBirth(from: user)
        selectedCountryCode = CountryOption.resolvedCode(user.countryCode)
        selectedGender = user.gender
        tracksMenstrualCycle = user.menstrualCycle.tracksCycle
        lastPeriodStart = user.menstrualCycle.lastPeriodStart
            ?? Calendar.current.startOfDay(for: .now)
        cycleLengthDays = user.menstrualCycle.cycleLengthDays
        periodLengthDays = user.menstrualCycle.periodLengthDays
    }

    /// Youngest allowed birth date (must be ≥ minimumAgeYears) — aligned with `UserProfile.isValidDateOfBirth`.
    private static func maximumDateOfBirth(now: Date = .now) -> Date {
        Calendar.current.date(byAdding: .year, value: -UserProfile.minimumAgeYears, to: now)
            ?? now.addingTimeInterval(-Double(UserProfile.minimumAgeYears) * 365.25 * 24 * 3600)
    }

    /// Oldest allowed birth date (≤ maximumAgeYears) — same bounds as validation.
    private static func minimumDateOfBirth(now: Date = .now) -> Date {
        Calendar.current.date(byAdding: .year, value: -UserProfile.maximumAgeYears, to: now)
            ?? now.addingTimeInterval(-Double(UserProfile.maximumAgeYears) * 365.25 * 24 * 3600)
    }

    private static func clampedDateOfBirth(from user: UserProfile, now: Date = .now) -> Date {
        let raw: Date = {
            if let dob = user.dateOfBirth {
                return dob
            }
            let safeAge = min(max(user.age, UserProfile.minimumAgeYears), UserProfile.maximumAgeYears)
            return Calendar.current.date(byAdding: .year, value: -safeAge, to: now)
                ?? maximumDateOfBirth(now: now)
        }()
        return clampedDate(raw, now: now)
    }

    private var isBodyDataValid: Bool {
        guard let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")),
              let height = Double(heightText.replacingOccurrences(of: ",", with: ".")) else { return false }
        return weight >= 30 && weight <= 300
            && height >= 100 && height <= 250
            && UserProfile.isValidDateOfBirth(dateOfBirth)
    }

    @ViewBuilder
    private func bodyDataSection(for user: UserProfile) -> some View {
        Text("Esses dados alimentam o cálculo de calorias e o cardápio em Nutrição. A data de nascimento é obrigatória.")
            .font(.caption)
            .foregroundStyle(.secondary)

        if !user.hasValidDateOfBirth {
            Label("Informe a data de nascimento para continuar", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        }

        MetricField(label: "Peso", unit: "kg", text: $weightText)
        MetricField(label: "Altura", unit: "cm", text: $heightText)

        // DatePicker outside the List (sheet) — in-row UIDatePicker has crashed SwiftUI when DOB was out of range.
        Button {
            dateOfBirth = Self.clampedDate(dateOfBirth)
            showDateOfBirthSheet = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data de nascimento *")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dateOfBirth.formatted(date: .long, time: .omitted))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Idade: \(UserProfile.age(from: dateOfBirth)) anos")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "calendar")
                    .foregroundStyle(AppTheme.accent)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ListSafeButtonStyle())

        VStack(alignment: .leading, spacing: 6) {
            Text("País")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("País", selection: safeCountryCodeBinding) {
                ForEach(CountryOption.catalog) { country in
                    Text("\(country.flagEmoji)  \(country.name)").tag(country.code)
                }
            }
            .pickerStyle(.menu)
        }

        VStack(alignment: .leading, spacing: 6) {
            Text("Sexo")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Sexo", selection: $selectedGender) {
                ForEach(Gender.allCases) { gender in
                    Text(gender.rawValue).tag(gender)
                }
            }
            .pickerStyle(.segmented)
        }

        if selectedGender == .female {
            menstrualCycleSection
        }

        LabeledContent("IMC", value: String(format: "%.1f", previewBMI(for: user)))
        LabeledContent("Metabolismo Basal", value: "\(previewBMR(for: user)) kcal")
        LabeledContent("Meta Calórica", value: "\(previewCalorieTarget(for: user)) kcal")

        Button {
            saveBodyData()
        } label: {
            Label("Salvar dados", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(ListSafeButtonStyle())
        .tint(AppTheme.accent)
        .disabled(!isBodyDataValid)
    }

    @ViewBuilder
    private var menstrualCycleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $tracksMenstrualCycle) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Acompanhar ciclo menstrual")
                    Text("Opcional e privado — só na sua conta.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.accent)

            if tracksMenstrualCycle {
                Button {
                    lastPeriodStart = min(max(lastPeriodStart, Self.lastPeriodDateRange.lowerBound), Self.lastPeriodDateRange.upperBound)
                    showLastPeriodSheet = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Primeiro dia da última menstruação")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(lastPeriodStart.formatted(date: .long, time: .omitted))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        Spacer()
                        Image(systemName: "calendar")
                            .foregroundStyle(Color(red: 0.86, green: 0.45, blue: 0.58))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(ListSafeButtonStyle())

                Button {
                    lastPeriodStart = Calendar.current.startOfDay(for: .now)
                } label: {
                    Label("A menstruação começou hoje", systemImage: "drop.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ListSafeButtonStyle())
                .foregroundStyle(Color(red: 0.86, green: 0.45, blue: 0.58))

                Stepper(value: $cycleLengthDays, in: MenstrualCycleProfile.minCycleLength...MenstrualCycleProfile.maxCycleLength) {
                    Text("Duração do ciclo: \(cycleLengthDays) dias")
                }

                Stepper(value: $periodLengthDays, in: MenstrualCycleProfile.minPeriodLength...MenstrualCycleProfile.maxPeriodLength) {
                    Text("Duração do fluxo: \(periodLengthDays) dias")
                }

                if let snapshot = MenstrualCycleCalendar.snapshot(currentFormMenstrualCycle()) {
                    let next = MenstrualCycleCalendar.nextPeriodStart(from: snapshot)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Agora: \(snapshot.phase.displayName) · dia \(snapshot.cycleDay) de \(snapshot.cycleLengthDays)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Próxima menstruação estimada: \(next.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        if snapshot.phase.isUnfavorableForBodyMeasurements {
                            Text("Nesta fase o corpo retém mais líquido — evite usar as medidas para comparar evolução.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.accentSecondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func previewProfile(from user: UserProfile) -> UserProfile {
        var preview = user
        if let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")) {
            preview.weight = weight
        }
        if let height = Double(heightText.replacingOccurrences(of: ",", with: ".")) {
            preview.height = height
        }
        preview.applyDateOfBirth(dateOfBirth)
        preview.countryCode = CountryOption.resolvedCode(selectedCountryCode)
        preview.gender = selectedGender
        preview.menstrualCycle = currentFormMenstrualCycle()
        return preview
    }

    private func currentFormMenstrualCycle() -> MenstrualCycleProfile {
        guard selectedGender == .female else { return .inactive }
        return MenstrualCycleProfile(
            tracksCycle: tracksMenstrualCycle,
            lastPeriodStart: tracksMenstrualCycle ? Calendar.current.startOfDay(for: lastPeriodStart) : nil,
            cycleLengthDays: cycleLengthDays,
            periodLengthDays: periodLengthDays
        ).clamped()
    }

    private func previewBMI(for user: UserProfile) -> Double {
        previewProfile(from: user).bmi
    }

    private func previewBMR(for user: UserProfile) -> Int {
        previewProfile(from: user).basalMetabolicRate
    }

    private func previewCalorieTarget(for user: UserProfile) -> Int {
        previewProfile(from: user).dailyCalorieTarget
    }

    private func currentFormMeasurements(measuredAt: Date = .now) -> BodyMeasurements {
        BodyMeasurements(
            neckCm: parseMeasurement(neckText),
            shouldersCm: parseMeasurement(shouldersText),
            chestCm: parseMeasurement(chestText),
            rightArmCm: parseMeasurement(rightArmText),
            leftArmCm: parseMeasurement(leftArmText),
            waistCm: parseMeasurement(waistText),
            abdomenCm: parseMeasurement(abdomenText),
            hipCm: parseMeasurement(hipText),
            rightThighCm: parseMeasurement(rightThighText),
            leftThighCm: parseMeasurement(leftThighText),
            rightCalfCm: parseMeasurement(rightCalfText),
            leftCalfCm: parseMeasurement(leftCalfText),
            measuredAt: measuredAt
        )
    }

    private func saveBodyData() {
        guard var user = authService.currentUser,
              let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")),
              let height = Double(heightText.replacingOccurrences(of: ",", with: ".")),
              isBodyDataValid else {
            if !UserProfile.isValidDateOfBirth(dateOfBirth) {
                bodyDataSaveError = "A data de nascimento é obrigatória (\(UserProfile.minimumAgeYears) a \(UserProfile.maximumAgeYears) anos)."
            }
            return
        }

        user.weight = weight
        user.height = height
        user.applyDateOfBirth(dateOfBirth)
        user.countryCode = CountryOption.resolvedCode(selectedCountryCode)
        user.gender = selectedGender
        user.menstrualCycle = currentFormMenstrualCycle()
        user.prepareMenstrualCycleForPersistence()
        if selectedGender != .female {
            tracksMenstrualCycle = false
        }

        // Medidas corporais são opcionais aqui; se houver valores no formulário, persiste também.
        applyMeasurementFields(to: &user)

        authService.updateProfile(user)
        mealPlanService.regeneratePlanIfNeeded(for: user)
        ProfileDataReminderService.shared.markBodyDataUpdated(for: user.id)
        showBodyDataSavedAlert = true
    }

    /// Aplica os campos de circunferência atuais ao perfil (sem alertas).
    private func applyMeasurementFields(to user: inout UserProfile) {
        let previousSnapshot = user.bodyMeasurements
        let shouldGenerateComparison = BodyMeasurements.isEligibleForPeriodComparison(
            previous: previousSnapshot
        )

        let measurements = currentFormMeasurements()

        // Só atualiza measuredAt/medidas se houver algum valor ou já existia aferição.
        guard measurements.hasAnyValue || previousSnapshot.hasAnyValue else { return }

        if shouldGenerateComparison && previousSnapshot.hasAnyValue {
            user.previousBodyMeasurements = previousSnapshot
        }
        if measurements.hasAnyValue {
            user.recordBodyMeasurementEvaluation(measurements)
        } else {
            user.bodyMeasurements = measurements
        }

        if shouldGenerateComparison,
           let comparison = BodyMeasurementComparison.make(
            previous: previousSnapshot,
            current: measurements
           ) {
            measurementComparison = comparison
            // O alerta de dados salvos tem prioridade; o comparativo pode ser aberto depois.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showMeasurementComparison = true
            }
        }
    }

    private func syncBodyMeasurementFields() {
        let m = authService.currentUser?.bodyMeasurements ?? .empty
        neckText = formatMeasurementField(m.neckCm)
        shouldersText = formatMeasurementField(m.shouldersCm)
        chestText = formatMeasurementField(m.chestCm)
        rightArmText = formatMeasurementField(m.rightArmCm)
        leftArmText = formatMeasurementField(m.leftArmCm)
        waistText = formatMeasurementField(m.waistCm)
        abdomenText = formatMeasurementField(m.abdomenCm)
        hipText = formatMeasurementField(m.hipCm)
        rightThighText = formatMeasurementField(m.rightThighCm)
        leftThighText = formatMeasurementField(m.leftThighCm)
        rightCalfText = formatMeasurementField(m.rightCalfCm)
        leftCalfText = formatMeasurementField(m.leftCalfCm)
    }

    private func formatMeasurementField(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    private func parseMeasurement(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), value > 0, value < 500 else { return nil }
        return value
    }

    @ViewBuilder
    private func bodyMeasurementsSection(for user: UserProfile) -> some View {
        Text("Informe as circunferências em centímetros. Os campos vazios não entram no relatório.")
            .font(.caption)
            .foregroundStyle(.secondary)

        if let advice = user.bodyMeasurementCycleAdvice(
            hasMeasurementChanges: user.latestMeasurementComparison?.hasChanges == true
        ) {
            MenstrualCycleAdviceCard(advice: advice)
        }

        if let measuredAt = user.bodyMeasurements.measuredAt {
            Text("Última atualização: \(measuredAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(AppTheme.accent)
        }

        if let comparison = user.latestMeasurementComparison,
           comparison.periodDays >= BodyMeasurements.comparisonIntervalDays {
            Button {
                measurementComparison = comparison
                showMeasurementComparison = true
            } label: {
                Label(
                    "Ver comparativo de \(comparison.periodDays) dia(s)",
                    systemImage: "arrow.left.arrow.right"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(ListSafeButtonStyle())
        } else if let measuredAt = user.bodyMeasurements.measuredAt {
            let days = BodyMeasurements.daysBetween(measuredAt)
            let remaining = max(BodyMeasurements.comparisonIntervalDays - days, 0)
            if remaining > 0 {
                Text("Comparativo disponível após \(remaining) dia(s), quando você atualizar as medidas.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        if currentFormMeasurements().hasAnyValue {
            Text(measurementsSummaryLine)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }

        VStack(spacing: 0) {
            Button {
                showMeasurementsEditor = true
            } label: {
                Label("Inserir medidas", systemImage: "ruler.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accent)

            Rectangle()
                .fill(Color.primary.opacity(0.22))
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, -20)

            Button {
                exportPhysicalAssessmentPDF()
            } label: {
                Label("Exportar avaliação PDF", systemImage: "doc.richtext.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accentSecondary)
            .disabled(isGeneratingPhysicalAssessmentPDF)
            .opacity(isGeneratingPhysicalAssessmentPDF ? 0.55 : 1)
        }
        .frame(maxWidth: .infinity)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private var measurementsSummaryLine: String {
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
        if filled.isEmpty { return "" }
        return filled.joined(separator: " · ")
    }

    private var measurementsEditorSheet: some View {
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
                saveBodyMeasurements()
                showMeasurementsEditor = false
            },
            onClose: {
                showMeasurementsEditor = false
            }
        )
    }

    private func exportPhysicalAssessmentPDF() {
        guard !isGeneratingPhysicalAssessmentPDF else { return }
        guard var user = authService.currentUser else { return }
        let measurements = currentFormMeasurements(measuredAt: user.bodyMeasurements.measuredAt ?? .now)
        guard measurements.hasAnyValue || user.weight > 0 else {
            showPhysicalAssessmentEmptyAlert = true
            return
        }
        user.gender = selectedGender
        if let parsedWeight = parseMeasurement(weightText) {
            user.weight = parsedWeight
        }
        let exportMeasurements = measurements.hasAnyValue ? measurements : user.bodyMeasurements
        isGeneratingPhysicalAssessmentPDF = true
        PhysicalAssessmentPDFBuilder.prepareForExport()
        Task {
            let url = await Task.detached(priority: .userInitiated) {
                PhysicalAssessmentPDFBuilder.writeTemporaryPDF(
                    profile: user,
                    measurements: exportMeasurements
                )
            }.value
            await MainActor.run {
                isGeneratingPhysicalAssessmentPDF = false
                guard let url else {
                    showPhysicalAssessmentEmptyAlert = true
                    return
                }
                physicalAssessmentPDFURL = url
                showPhysicalAssessmentShare = true
            }
        }
    }

    private func saveBodyMeasurements() {
        guard var user = authService.currentUser else { return }

        let measurements = currentFormMeasurements()
        guard measurements.hasAnyValue else {
            showEmptyMeasurementsAlert = true
            return
        }

        let previousSnapshot = user.bodyMeasurements
        let shouldGenerateComparison = BodyMeasurements.isEligibleForPeriodComparison(
            previous: previousSnapshot
        )

        applyMeasurementFields(to: &user)
        authService.updateProfile(user)
        ProfileDataReminderService.shared.markBodyDataUpdated(for: user.id)

        if shouldGenerateComparison,
           BodyMeasurementComparison.make(
            previous: previousSnapshot,
            current: user.bodyMeasurements
           ) != nil {
            // applyMeasurementFields já agenda o sheet do comparativo.
        } else {
            showMeasurementsSavedAlert = true
        }
    }

    private func updateBiotype(_ biotype: Biotype) {
        guard var user = authService.currentUser, user.biotype != biotype else { return }
        user.biotype = biotype
        authService.updateProfile(user)
        mealPlanService.regeneratePlanIfNeeded(for: user)
        ProfileDataReminderService.shared.markBodyDataUpdated(for: user.id)
    }
}

private struct ProfileAvatarView: View {
    let image: UIImage?
    let initial: String
    var countryFlag: String = "🏳️"

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(AppTheme.gradientPrimary)
                    Text(initial)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

            Image(systemName: "camera.fill")
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(6)
                .background(AppTheme.accent)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.background, lineWidth: 2))
        }
        .overlay(alignment: .topLeading) {
            Text(countryFlag)
                .font(.system(size: 20))
                .offset(x: -4, y: -6)
        }
    }
}

private struct BodyMeasurementComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    let comparison: BodyMeasurementComparison
    var cycleAdvice: MenstrualCycleMeasurementAdvice? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Comparativo de \(comparison.periodDays) dia(s)")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Após atualizar as medidas, estas são as que variaram no período.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    if let cycleAdvice {
                        MenstrualCycleAdviceCard(advice: cycleAdvice)
                    }

                    if let from = comparison.previous.measuredAt,
                       let to = comparison.current.measuredAt {
                        Text("\(from.formatted(date: .abbreviated, time: .omitted)) → \(to.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    if comparison.changes.isEmpty {
                        Text("Nenhuma medida variou entre as duas aferições.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(comparison.changes) { change in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(change.label)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text("\(BodyMeasurements.formatCm(change.previous)) → \(BodyMeasurements.formatCm(change.current))")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Spacer()
                                    Text(BodyMeasurements.formatDelta(change.delta))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(change.delta < 0 ? .green : (change.delta > 0 ? .orange : AppTheme.textSecondary))
                                }
                                .padding()
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Comparativo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}


// MARK: - Profile presentation helpers (keep ProfileView.body type-checkable)

private extension View {
    func profilePhotoPickers(
        showPhotoSourceDialog: Binding<Bool>,
        showBackgroundSourceDialog: Binding<Bool>,
        showProfileGalleryPicker: Binding<Bool>,
        showProfileCameraPicker: Binding<Bool>,
        showBackgroundGalleryPicker: Binding<Bool>,
        showBackgroundCameraPicker: Binding<Bool>,
        hasBackgroundImage: Bool,
        onProfileImage: @escaping (UIImage) -> Void,
        onBackgroundImage: @escaping (UIImage) -> Void,
        onRemoveBackground: @escaping () -> Void
    ) -> some View {
        self
            .confirmationDialog(
                "Foto do perfil",
                isPresented: showPhotoSourceDialog,
                titleVisibility: .visible
            ) {
                if PhotoCaptureAvailability.isCameraAvailable {
                    Button("Câmera") {
                        DispatchQueue.main.async { showProfileCameraPicker.wrappedValue = true }
                    }
                }
                Button("Galeria") {
                    DispatchQueue.main.async { showProfileGalleryPicker.wrappedValue = true }
                }
                Button("Cancelar", role: .cancel) {}
            }
            .confirmationDialog(
                "Foto de fundo",
                isPresented: showBackgroundSourceDialog,
                titleVisibility: .visible
            ) {
                if PhotoCaptureAvailability.isCameraAvailable {
                    Button("Câmera") {
                        DispatchQueue.main.async { showBackgroundCameraPicker.wrappedValue = true }
                    }
                }
                Button("Galeria") {
                    DispatchQueue.main.async { showBackgroundGalleryPicker.wrappedValue = true }
                }
                if hasBackgroundImage {
                    Button("Remover fundo", role: .destructive, action: onRemoveBackground)
                }
                Button("Cancelar", role: .cancel) {}
            }
            .sheet(isPresented: showProfileGalleryPicker) {
                LibraryImagePicker { image in
                    showProfileGalleryPicker.wrappedValue = false
                    guard let image else { return }
                    onProfileImage(image)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: showProfileCameraPicker) {
                CameraImagePicker { image in
                    showProfileCameraPicker.wrappedValue = false
                    guard let image else { return }
                    onProfileImage(image)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: showBackgroundGalleryPicker) {
                LibraryImagePicker { image in
                    showBackgroundGalleryPicker.wrappedValue = false
                    guard let image else { return }
                    onBackgroundImage(image)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: showBackgroundCameraPicker) {
                CameraImagePicker { image in
                    showBackgroundCameraPicker.wrappedValue = false
                    guard let image else { return }
                    onBackgroundImage(image)
                }
                .ignoresSafeArea()
            }
    }

    func profileAlertsAndSheets(
        showLogoutAlert: Binding<Bool>,
        showMeasurementsSavedAlert: Binding<Bool>,
        showBodyDataSavedAlert: Binding<Bool>,
        showEmptyMeasurementsAlert: Binding<Bool>,
        showSaveFailedAlert: Binding<Bool>,
        measurementsSaveError: String?,
        bodyDataSaveError: String?,
        includesMenstrualCycleInSaveMessage: Bool,
        showMeasurementComparison: Binding<Bool>,
        measurementComparison: BodyMeasurementComparison?,
        cycleAdvice: MenstrualCycleMeasurementAdvice?,
        showDeleteAccountSheet: Binding<Bool>,
        usesPasswordProvider: Bool,
        usesAppleProvider: Bool,
        onLogout: @escaping () -> Void,
        onClearSaveErrors: @escaping () -> Void
    ) -> some View {
        self
            .alert("Sair da conta?", isPresented: showLogoutAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Sair", role: .destructive, action: onLogout)
            }
            .alert("Medidas salvas", isPresented: showMeasurementsSavedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("As medidas corporais foram salvas e sincronizadas com o Firebase. Elas entram no relatório enviado ao personal. Para mandar o e-mail, o app Mail precisa estar configurado neste \(MailSetupGuidance.deviceName) (\(MailSetupGuidance.settingsPath)).")
            }
            .alert("Dados salvos", isPresented: showBodyDataSavedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(includesMenstrualCycleInSaveMessage
                     ? "Peso, altura, data de nascimento, sexo e ciclo menstrual foram sincronizados com a sua conta."
                     : "Peso, altura, data de nascimento e sexo foram sincronizados com a sua conta.")
            }
            .alert("Medidas necessárias", isPresented: showEmptyMeasurementsAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Por favor, preencha as medidas para salvar.")
            }
            .sheet(isPresented: showMeasurementComparison) {
                if let comparison = measurementComparison {
                    BodyMeasurementComparisonView(comparison: comparison, cycleAdvice: cycleAdvice)
                }
            }
            .alert("Não foi possível salvar", isPresented: showSaveFailedAlert) {
                Button("OK", role: .cancel, action: onClearSaveErrors)
            } message: {
                Text(measurementsSaveError ?? bodyDataSaveError ?? "")
            }
            .sheet(isPresented: showDeleteAccountSheet) {
                DeleteAccountSheet(
                    requiresPassword: usesPasswordProvider,
                    requiresAppleReauthentication: usesAppleProvider
                )
            }
    }
}

private struct MenstrualCycleAdviceCard: View {
    let advice: MenstrualCycleMeasurementAdvice

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(advice.title, systemImage: "drop.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accentSecondary)
            Text("\(advice.phaseLabel) · dia \(advice.cycleDay) do ciclo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(advice.message)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accentSecondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Evita o atraso/long-press típico de `Button` dentro de `List` (UITableView).
private struct ListSafeButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded { configuration.trigger() }
            )
    }
}

/// Editor isolado: ScrollView + campos largos + FocusState (Form/List no Perfil travava o teclado numérico).
private struct BodyMeasurementsEditorSheet: View {
    enum Field: Hashable {
        case neck, shoulders, chest, rightArm, leftArm
        case waist, abdomen, hip
        case rightThigh, leftThigh, rightCalf, leftCalf
    }

    @Binding var neckText: String
    @Binding var shouldersText: String
    @Binding var chestText: String
    @Binding var rightArmText: String
    @Binding var leftArmText: String
    @Binding var waistText: String
    @Binding var abdomenText: String
    @Binding var hipText: String
    @Binding var rightThighText: String
    @Binding var leftThighText: String
    @Binding var rightCalfText: String
    @Binding var leftCalfText: String
    var onSave: () -> Void
    var onClose: () -> Void

    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Digite as circunferências em centímetros. Campos vazios não entram no relatório nem no PDF.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    group("Superior") {
                        field("Pescoço", text: $neckText, focus: .neck)
                        field("Ombros", text: $shouldersText, focus: .shoulders)
                        field("Peito", text: $chestText, focus: .chest)
                        field("Braço direito", text: $rightArmText, focus: .rightArm)
                        field("Braço esquerdo", text: $leftArmText, focus: .leftArm)
                    }

                    group("Tronco") {
                        field("Cintura", text: $waistText, focus: .waist)
                        field("Abdômen", text: $abdomenText, focus: .abdomen)
                        field("Quadril", text: $hipText, focus: .hip)
                    }

                    group("Inferior") {
                        field("Coxa direita", text: $rightThighText, focus: .rightThigh)
                        field("Coxa esquerda", text: $leftThighText, focus: .leftThigh)
                        field("Panturrilha direita", text: $rightCalfText, focus: .rightCalf)
                        field("Panturrilha esquerda", text: $leftCalfText, focus: .leftCalf)
                    }

                    Button {
                        focusedField = nil
                        onSave()
                    } label: {
                        Label("Salvar medidas", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Medidas corporais")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        focusedField = nil
                        onClose()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Foca o primeiro campo após a ficha estabilizar (evita race com animação do sheet).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if focusedField == nil {
                        focusedField = .neck
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func field(_ title: String, text: Binding<String>, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: focus)
                    .padding(12)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("cm")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)
            }
        }
    }
}
