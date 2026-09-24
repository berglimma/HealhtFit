import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class CoachService: ObservableObject {
    static let shared = CoachService()

    @Published private(set) var myProfile: CoachProfessionalProfile?
    @Published private(set) var myLinks: [CoachLink] = []
    @Published private(set) var myTrainingMethods: [CoachTrainingMethod] = []
    @Published private(set) var assignedWorkoutsByLink: [String: [CoachAssignedWorkout]] = [:]
    @Published private(set) var consultationsByLink: [String: [ConsultationBooking]] = [:]
    @Published private(set) var availabilityByCoachUid: [String: CoachAvailability] = [:]
    @Published private(set) var chatMessages: [String: [CoachChatMessage]] = [:]
    @Published private(set) var interestMessages: [CoachInterestMessage] = []
    @Published private(set) var isSyncing = false
    @Published var lastError: String?

    private weak var workoutStore: WorkoutStore?
    private weak var mealPlanService: MealPlanService?
    private weak var authService: AuthService?

    private var membershipListener: ListenerRegistration?
    private var linkListeners: [String: ListenerRegistration] = [:]
    private var workoutListeners: [String: ListenerRegistration] = [:]
    private var mealListeners: [String: ListenerRegistration] = [:]
    private var careListeners: [String: ListenerRegistration] = [:]
    private var consultationListeners: [String: ListenerRegistration] = [:]
    private var availabilityListeners: [String: ListenerRegistration] = [:]
    private var chatListeners: [String: ListenerRegistration] = [:]
    private var methodsListener: ListenerRegistration?
    private var interestMessagesListener: ListenerRegistration?
    /// Evita spam de notificação local para a mesma mensagem.
    private var notifiedCoachChatMessageIds: Set<String> = []
    /// Primeiro snapshot do listener não deve disparar notificação (histórico).
    private var chatListenerPrimed: Set<String> = []

    private init() {}

    func bind(
        authService: AuthService,
        workoutStore: WorkoutStore,
        mealPlanService: MealPlanService
    ) {
        self.authService = authService
        self.workoutStore = workoutStore
        self.mealPlanService = mealPlanService
    }

    var currentUid: String? { Auth.auth().currentUser?.uid }

    var isProfessionalAccount: Bool {
        guard let role = authService?.currentUser?.accountRole else { return false }
        return role.isPersonalProfessional || role.isNutritionProfessional
    }

    var activePersonalLink: CoachLink? {
        myLinks.first { $0.profession == .personal && ($0.status == .active || $0.status == .blockedPlan) }
    }

    var activeNutritionLink: CoachLink? {
        myLinks.first { $0.profession == .nutritionist && ($0.status == .active || $0.status == .blockedPlan) }
    }

    /// Preferência: vínculo de nutrição; senão personal ativo do aluno (coach dual).
    var activeCareLink: CoachLink? {
        if let nutri = activeNutritionLink { return nutri }
        guard let uid = currentUid else { return nil }
        return myLinks.first {
            $0.studentUid == uid && $0.isActiveLike
        }
    }

    var hasActiveCoachChat: Bool {
        myLinks.contains { $0.status == .active }
    }

    var studentCanUseCoachFeatures: Bool {
        SubscriptionService.shared.canAccess(.healthFitCoach)
    }

    // MARK: - Lifecycle

    func start() {
        guard let uid = currentUid else {
            stop()
            return
        }
        NutritionCareStore.shared.bind(userId: uid)
        Task {
            await hydrateConsentFromCloud(uid: uid)
            await refreshProfile(uid: uid)
            if isProfessionalAccount || myProfile != nil {
                await refreshProfessionalPhotoFromAppProfileIfNeeded()
            }
            // Se já aceitou no device mas ainda não está no Firebase, espelha.
            if CoachPreferences.hasConsent {
                await CoachFirestoreService.saveCoachConsentIfPossible()
            }
        }
        membershipListener?.remove()
        membershipListener = CoachFirestoreService.listenMemberships(uid: uid) { [weak self] docs in
            Task { @MainActor in
                await self?.applyMembershipSnapshots(docs)
                await self?.publishProfessionalReviewSnapshotsIfStudent()
            }
        }
        ensureInterestMessagesListening(studentUid: uid)
    }

    /// Aluno publica resumo cruzado para o profissional (IAssistente → revisão).
    func publishProfessionalReviewSnapshotsIfStudent() async {
        guard let uid = currentUid,
              let profile = authService?.currentUser,
              let mealPlanService,
              let workoutStore else { return }
        let studentLinks = myLinks.filter { $0.studentUid == uid && $0.isActiveLike }
        guard !studentLinks.isEmpty else { return }

        await DailyWellnessService.shared.ensureCurrentWeekLoaded()
        let wellness = Array(DailyWellnessService.shared.weekEntriesByDayKey.values)
        let sessions = workoutStore.sessionHistory

        for link in studentLinks {
            NutritionCareStore.shared.focus(linkId: link.id)
            let care = NutritionCareStore.shared.bundle
            let snapshot = ProfessionalReviewEngine.buildSnapshot(
                link: link,
                profile: profile,
                weeklyPlan: mealPlanService.weeklyPlan,
                wellnessEntries: wellness,
                sessions: sessions,
                careGoals: care.goals,
                checkIns: care.checkIns
            )
            try? await ProfessionalReviewFirestoreService.publishReview(snapshot)
        }
    }

    func stop() {
        membershipListener?.remove()
        membershipListener = nil
        methodsListener?.remove()
        methodsListener = nil
        interestMessagesListener?.remove()
        interestMessagesListener = nil
        linkListeners.values.forEach { $0.remove() }
        workoutListeners.values.forEach { $0.remove() }
        mealListeners.values.forEach { $0.remove() }
        careListeners.values.forEach { $0.remove() }
        consultationListeners.values.forEach { $0.remove() }
        availabilityListeners.values.forEach { $0.remove() }
        chatListeners.values.forEach { $0.remove() }
        linkListeners.removeAll()
        workoutListeners.removeAll()
        mealListeners.removeAll()
        careListeners.removeAll()
        consultationListeners.removeAll()
        availabilityListeners.removeAll()
        chatListeners.removeAll()
        myLinks = []
        myTrainingMethods = []
        assignedWorkoutsByLink = [:]
        consultationsByLink = [:]
        availabilityByCoachUid = [:]
        chatMessages = [:]
        interestMessages = []
        NutritionCareStore.shared.bind(userId: nil)
    }

    private func ensureInterestMessagesListening(studentUid: String) {
        interestMessagesListener?.remove()
        interestMessagesListener = CoachFirestoreService.listenInterestMessages(studentUid: studentUid) { [weak self] messages in
            Task { @MainActor in
                self?.interestMessages = messages
            }
        }
    }

    /// Restaura consentimento do Coach a partir do Firebase (novo device / reinstalação).
    private func hydrateConsentFromCloud(uid: String) async {
        guard !CoachPreferences.hasConsent else { return }
        let granted = await CoachFirestoreService.fetchCoachConsentGranted(uid: uid)
        CoachPreferences.applyFromCloud(granted: granted)
    }

    // MARK: - Profile

    func refreshProfile(uid: String? = nil) async {
        guard let uid = uid ?? currentUid else { return }
        do {
            myProfile = try await CoachFirestoreService.fetchProfile(uid: uid)
            if isProfessionalAccount || myProfile != nil {
                ensureMethodsListening(coachUid: uid)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func ensureMethodsListening(coachUid: String) {
        guard methodsListener == nil else { return }
        methodsListener = CoachFirestoreService.listenMethods(coachUid: coachUid) { [weak self] methods in
            Task { @MainActor in
                self?.myTrainingMethods = methods
            }
        }
    }

    // MARK: - Training methods

    @discardableResult
    func saveTrainingMethod(name: String, notes: String = "", existing: CoachTrainingMethod? = nil) async -> CoachTrainingMethod? {
        guard let uid = currentUid else {
            lastError = CoachFirestoreError.notSignedIn.errorDescription
            return nil
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Informe um nome para o método."
            return nil
        }
        let method = CoachTrainingMethod(
            id: existing?.id ?? UUID().uuidString,
            coachUid: uid,
            name: String(trimmed.prefix(80)),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: existing?.createdAt ?? .now,
            updatedAt: .now
        )
        do {
            try await CoachFirestoreService.saveMethod(method)
            if let idx = myTrainingMethods.firstIndex(where: { $0.id == method.id }) {
                myTrainingMethods[idx] = method
            } else {
                myTrainingMethods.append(method)
                myTrainingMethods.sort {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            }
            if let existing, existing.name != method.name {
                await propagateMethodRename(method)
            }
            return method
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func deleteTrainingMethod(_ method: CoachTrainingMethod, removeAssignedSheets: Bool = false) async -> Bool {
        guard let uid = currentUid, uid == method.coachUid else { return false }
        do {
            try await CoachFirestoreService.deleteMethod(coachUid: uid, methodId: method.id)
            myTrainingMethods.removeAll { $0.id == method.id }

            for link in myLinks where link.coachUid == uid && link.profession == .personal {
                let assignments = assignedWorkoutsByLink[link.id] ?? []
                for assignment in assignments where assignment.sheet.coachMethodId == method.id {
                    if removeAssignedSheets {
                        _ = await deleteAssignedWorkout(link: link, assignment: assignment)
                    } else {
                        var sheet = assignment.sheet
                        sheet.coachMethodId = nil
                        sheet.coachMethodName = nil
                        sheet.updatedAt = .now
                        _ = await publishWorkout(link: link, sheet: sheet)
                    }
                }
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func propagateMethodRename(_ method: CoachTrainingMethod) async {
        guard let uid = currentUid else { return }
        for link in myLinks where link.coachUid == uid && link.profession == .personal {
            let assignments = assignedWorkoutsByLink[link.id] ?? []
            for assignment in assignments where assignment.sheet.coachMethodId == method.id {
                var sheet = assignment.sheet
                guard sheet.coachMethodName != method.name else { continue }
                sheet.coachMethodName = method.name
                sheet.updatedAt = .now
                _ = await publishWorkout(link: link, sheet: sheet)
            }
        }
    }

    func saveProfessionalProfile(
        displayName: String,
        professions: [CoachProfession],
        cref: String?,
        crn: String?,
        city: String,
        stateCode: String,
        bio: String,
        specialties: [String],
        isDirectoryVisible: Bool
    ) async -> Bool {
        guard let user = authService?.currentUser else {
            lastError = CoachFirestoreError.notSignedIn.errorDescription
            return false
        }
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            lastError = "Informe o nome profissional."
            return false
        }
        let needsCREF = professions.contains(.personal)
        let needsCRN = professions.contains(.nutritionist)
        let trimmedCREF = cref?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedCRN = crn?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if needsCREF && trimmedCREF.isEmpty {
            lastError = "Informe o CREF para atuar como personal."
            return false
        }
        if needsCRN && trimmedCRN.isEmpty {
            lastError = "Informe o CRN para atuar como nutricionista."
            return false
        }
        if !needsCREF && !needsCRN {
            lastError = "Selecione ao menos uma profissão."
            return false
        }

        CoachPreferences.grantConsent()
        let photoURL = await Self.resolveCoachPhotoURL(userId: user.id) ?? myProfile?.photoURL
        let profile = CoachProfessionalProfile(
            uid: user.id,
            displayName: trimmedName,
            email: user.email,
            photoURL: photoURL,
            professions: professions,
            cref: needsCREF ? trimmedCREF : nil,
            crn: needsCRN ? trimmedCRN : nil,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            stateCode: stateCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            specialties: specialties,
            isDirectoryVisible: isDirectoryVisible,
            privacyAcknowledged: true,
            updatedAt: .now
        )
        do {
            try await CoachFirestoreService.saveProfile(profile)
            myProfile = profile
            ensureMethodsListening(coachUid: user.id)
            syncAccountRole(with: professions)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Alinha “Você é” no Perfil com as profissões do cadastro Coach.
    private func syncAccountRole(with professions: [CoachProfession]) {
        guard var user = authService?.currentUser else { return }
        let hasPersonal = professions.contains(.personal)
        let hasNutrition = professions.contains(.nutritionist)
        let role: UserAccountRole
        switch (hasPersonal, hasNutrition) {
        case (true, true): role = .personalAndNutritionist
        case (true, false): role = .personal
        case (false, true): role = .nutritionist
        case (false, false): return
        }
        guard user.accountRole != role else { return }
        user.accountRole = role
        authService?.updateProfile(user)
    }

    /// Remove o cadastro profissional do Coach (perfil na busca + vínculos como coach).
    func deleteProfessionalRegistration(resetAccountRoleToStudent: Bool = true) async -> Bool {
        guard let user = authService?.currentUser else {
            lastError = CoachFirestoreError.notSignedIn.errorDescription
            return false
        }
        guard isProfessionalAccount || myProfile != nil else {
            lastError = "Não há cadastro profissional para excluir."
            return false
        }

        let coachLinks = myLinks.filter { $0.coachUid == user.id && $0.status != .ended }
        for link in coachLinks {
            let ok = await endLink(link)
            if !ok {
                return false
            }
        }

        do {
            try await CoachFirestoreService.deleteProfile(uid: user.id)
            myProfile = nil

            if resetAccountRoleToStudent, user.accountRole != .student {
                var updated = user
                updated.accountRole = .student
                authService?.updateProfile(updated)
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Invite / accept

    func createStudentInvite(profession: CoachProfession, toName: String? = nil, toEmail: String? = nil, toUid: String? = nil) async -> CoachInvite? {
        guard let user = authService?.currentUser else { return nil }
        let activeCount = myLinks.filter { $0.coachUid == user.id && $0.isActiveLike }.count
        let maxStudents = myProfile?.maxStudents ?? CoachProfessionalProfile.defaultMaxStudents
        if activeCount >= maxStudents {
            lastError = CoachFirestoreError.limitReached.errorDescription
            return nil
        }
        let invite = CoachInvite(
            id: UUID().uuidString,
            code: CoachCodeGenerator.makeInviteCode(),
            fromUid: user.id,
            fromName: myProfile?.displayName
                ?? (user.greetingName.isEmpty ? user.name : user.greetingName),
            toUid: toUid,
            toName: toName,
            toEmail: toEmail,
            profession: profession,
            status: .pending,
            linkId: nil,
            createdAt: .now,
            expiresAt: Date().addingTimeInterval(7 * 24 * 3600)
        )
        do {
            try await CoachFirestoreService.createInvite(invite)
            return invite
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func acceptInvite(code: String) async -> Bool {
        guard let user = authService?.currentUser else { return false }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return false }
        do {
            guard let invite = try await CoachFirestoreService.fetchInvite(code: normalized),
                  invite.status == .pending,
                  invite.expiresAt > Date() else {
                lastError = "Convite inválido ou expirado."
                return false
            }
            let linkId = CoachCodeGenerator.makeLinkId(
                coachUid: invite.fromUid,
                studentUid: user.id,
                profession: invite.profession
            )
            let planOK = studentCanUseCoachFeatures
            async let studentPhoto = Self.resolveCoachPhotoURL(userId: user.id)
            async let coachPhoto = Self.resolveCoachPhotoURL(userId: invite.fromUid)
            let link = CoachLink(
                id: linkId,
                coachUid: invite.fromUid,
                coachName: invite.fromName,
                coachPhotoURL: await coachPhoto,
                studentUid: user.id,
                studentName: user.greetingName.isEmpty ? user.name : user.greetingName,
                studentPhotoURL: await studentPhoto,
                profession: invite.profession,
                status: planOK ? .active : .blockedPlan,
                memberUids: [invite.fromUid, user.id],
                createdAt: .now,
                updatedAt: .now,
                activatedAt: planOK ? .now : nil
            )
            try await CoachFirestoreService.saveLink(link)
            try await CoachFirestoreService.updateInviteStatus(
                inviteId: invite.id,
                status: .accepted,
                linkId: linkId,
                code: invite.code
            )
            applyProfileAutoFill(from: link)
            await syncDirectoryPersonalFlag()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Busca alunos no diretório do app (nome / apelido / e-mail).
    /// Prioriza quem está no mesmo país do profissional; depois outros países.
    func searchStudents(query: String) async -> [UserDirectoryEntry] {
        guard let uid = currentUid else { return [] }
        let preferCountry = authService?.currentUser?.countryCode
        do {
            return try await ProfileFirestoreService.searchUsers(
                query: query,
                excludingUserId: uid,
                limit: 25,
                preferCountryCode: preferCountry
            )
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    /// Personal envia mensagem motivacional a aluno sem personal (com código de convite).
    func sendMotivationalInterest(
        to student: UserDirectoryEntry,
        customText: String?
    ) async -> Bool {
        guard let user = authService?.currentUser else {
            lastError = CoachFirestoreError.notSignedIn.errorDescription
            return false
        }
        guard myProfile != nil || user.accountRole.isPersonalProfessional else {
            lastError = "Complete o perfil profissional antes de contatar alunos."
            return false
        }
        guard user.accountRole.isPersonalProfessional || myProfile?.professions.contains(.personal) == true else {
            lastError = "Somente personal trainer pode enviar mensagem de interesse a alunos."
            return false
        }
        if student.hasPersonalTrainer {
            lastError = "Este aluno já possui personal. Não enviamos mensagem de interesse."
            return false
        }
        if myLinks.contains(where: {
            $0.studentUid == student.uid && $0.profession == .personal && $0.isActiveLike
        }) {
            lastError = "Você já está vinculado a este aluno."
            return false
        }

        guard let invite = await createStudentInvite(
            profession: .personal,
            toName: student.shownName,
            toEmail: nil,
            toUid: student.uid
        ) else {
            return false
        }

        let coachName = myProfile?.displayName
            ?? (user.greetingName.isEmpty ? user.name : user.greetingName)
        let defaultText = """
        Olá, \(student.shownName)! Sou \(coachName), personal trainer no HealthFit.

        Vi seu perfil e gostaria de mostrar meu trabalho — posso te ajudar com fichas, acompanhamento e motivação. Se fizer sentido pra você, use o código \(invite.code) em HealthFit Coach → Entrar com código.
        """
        let trimmedCustom = customText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body = trimmedCustom.isEmpty ? defaultText : """
        \(trimmedCustom)

        — \(coachName) · código \(invite.code)
        """

        let message = CoachInterestMessage(
            fromCoachUid: user.id,
            fromCoachName: coachName,
            fromCoachPhotoURL: myProfile?.photoURL,
            toStudentUid: student.uid,
            text: String(body.prefix(CoachInterestMessage.maxLength)),
            inviteCode: invite.code,
            profession: .personal
        )

        do {
            try await CoachFirestoreService.sendInterestMessage(message)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func dismissInterestMessage(_ message: CoachInterestMessage) async {
        guard let uid = currentUid, message.toStudentUid == uid else { return }
        try? await CoachFirestoreService.updateInterestMessageStatus(
            studentUid: uid,
            messageId: message.id,
            status: .dismissed
        )
    }

    func acceptInterestMessage(_ message: CoachInterestMessage) async -> Bool {
        guard let code = message.inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty else {
            lastError = "Esta mensagem não tem código de convite."
            return false
        }
        let ok = await acceptInvite(code: code)
        if ok, let uid = currentUid {
            try? await CoachFirestoreService.updateInterestMessageStatus(
                studentUid: uid,
                messageId: message.id,
                status: .accepted
            )
        }
        return ok
    }

    private func syncDirectoryPersonalFlag() async {
        guard var user = authService?.currentUser else { return }
        // Garante flag pública alinhada ao vínculo Coach.
        if activePersonalLink != nil, !user.usesPersonalTrainer {
            user.usesPersonalTrainer = true
            if let name = activePersonalLink?.coachName, !name.isEmpty {
                user.personalTrainerName = name
            }
            authService?.updateProfile(user)
        } else {
            try? await ProfileFirestoreService.syncUserDirectory(user)
        }
    }

    func refreshLinkStatusesForPlan() async {
        guard let uid = currentUid else { return }
        let canUse = studentCanUseCoachFeatures
        for link in myLinks where link.studentUid == uid {
            var updated = link
            if canUse, link.status == .blockedPlan {
                updated.status = .active
                updated.activatedAt = .now
                updated.updatedAt = .now
                try? await CoachFirestoreService.saveLink(updated)
            } else if !canUse, link.status == .active {
                updated.status = .blockedPlan
                updated.updatedAt = .now
                try? await CoachFirestoreService.saveLink(updated)
            }
        }
    }

    /// Aluno ou profissional encerra o vínculo (ex.: excluir personal).
    func endLink(_ link: CoachLink) async -> Bool {
        guard let uid = currentUid, link.memberUids.contains(uid) else {
            lastError = "Sem permissão para encerrar este vínculo."
            return false
        }
        guard link.status != .ended else { return true }

        var updated = link
        updated.status = .ended
        updated.updatedAt = .now

        do {
            try await CoachFirestoreService.saveLink(updated)
            try await CoachFirestoreService.deleteMemberships(for: updated)

            myLinks.removeAll { $0.id == link.id }
            assignedWorkoutsByLink[link.id] = nil
            chatMessages[link.id] = nil

            linkListeners[link.id]?.remove()
            linkListeners.removeValue(forKey: link.id)
            workoutListeners[link.id]?.remove()
            workoutListeners.removeValue(forKey: link.id)
            mealListeners[link.id]?.remove()
            mealListeners.removeValue(forKey: link.id)
            chatListeners[link.id]?.remove()
            chatListeners.removeValue(forKey: link.id)

            if link.studentUid == uid {
                clearProfileAutoFill(for: link.profession)
                if link.profession == .personal {
                    await syncDirectoryPersonalFlag()
                }
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Prescribe workout

    func publishWorkout(link: CoachLink, sheet: WorkoutSheet) async -> Bool {
        guard let uid = currentUid, uid == link.coachUid else { return false }
        guard canPrescribeWorkouts(on: link) else {
            lastError = "Somente personal (ou Personal e Nutrição) pode enviar ficha de treino."
            return false
        }
        var prescribed = sheet
        prescribed.isCoachPrescribed = true
        prescribed.isUserCreated = true
        prescribed.coachLinkId = link.id
        prescribed.prescribedByUid = link.coachUid
        prescribed.prescribedByName = link.coachName
        prescribed.assignedTo = link.studentUid
        prescribed.updatedAt = .now

        let existing = assignedWorkoutsByLink[link.id]?.first {
            $0.id == sheet.id.uuidString || $0.sheet.id == sheet.id
        }

        let assignment = CoachAssignedWorkout(
            id: sheet.id.uuidString,
            linkId: link.id,
            coachUid: link.coachUid,
            coachName: link.coachName,
            studentUid: link.studentUid,
            sheet: prescribed,
            publishedAt: existing?.publishedAt ?? .now,
            updatedAt: .now,
            isActive: true
        )
        do {
            try await CoachFirestoreService.publishWorkout(assignment)
            var list = assignedWorkoutsByLink[link.id] ?? []
            if let idx = list.firstIndex(where: { $0.id == assignment.id }) {
                list[idx] = assignment
            } else {
                list.insert(assignment, at: 0)
            }
            assignedWorkoutsByLink[link.id] = list.sorted { $0.updatedAt > $1.updatedAt }
            mergeAssignedWorkoutsIntoStore()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func deleteAssignedWorkout(link: CoachLink, assignment: CoachAssignedWorkout) async -> Bool {
        guard let uid = currentUid, uid == link.coachUid else { return false }
        do {
            try await CoachFirestoreService.deleteWorkout(linkId: link.id, workoutId: assignment.id)
            var list = assignedWorkoutsByLink[link.id] ?? []
            list.removeAll { $0.id == assignment.id }
            assignedWorkoutsByLink[link.id] = list
            if let store = workoutStore {
                let sheetId = assignment.sheet.id
                if let local = store.workoutSheets.first(where: {
                    $0.id == sheetId || $0.id.uuidString == assignment.id
                }), local.isCoachPrescribed {
                    store.removeCoachPrescribedSheet(local)
                }
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Meal plan

    func publishMealPlan(link: CoachLink, weeklyPlan: [DailyMealPlan]) async -> Bool {
        guard let uid = currentUid, uid == link.coachUid else { return false }
        guard canPrescribeMeals(on: link) else {
            lastError = "Cadastre-se como nutricionista (CRN) para enviar cardápio."
            return false
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(weeklyPlan)
            let json = try JSONSerialization.jsonObject(with: data)
            guard let array = json as? [[String: Any]] else { return false }
            try await CoachFirestoreService.publishMealPlan(
                linkId: link.id,
                planJSON: ["weeklyPlan": array],
                coachUid: link.coachUid,
                coachName: link.coachName
            )
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Publica anamnese, questionários, metas e check-ins no vínculo de nutrição
    /// (ou no vínculo personal quando o coach também é nutricionista).
    func publishNutritionCare(link: CoachLink, from store: NutritionCareStore? = nil) async -> Bool {
        let careStore = store ?? NutritionCareStore.shared
        guard let uid = currentUid else { return false }
        guard canPrescribeMeals(on: link) else {
            lastError = "Acompanhamento nutricional requer cadastro de nutricionista."
            return false
        }
        // Garante que o store está no vínculo certo antes de serializar.
        careStore.focus(linkId: link.id)
        let name = authService?.currentUser?.greetingName.isEmpty == false
            ? (authService?.currentUser?.greetingName ?? link.coachName)
            : (authService?.currentUser?.name ?? link.coachName)
        do {
            let json = try careStore.encodedBundleJSON(for: link.id)
            try await CoachFirestoreService.publishNutritionCare(
                linkId: link.id,
                careJSON: ["bundle": json],
                actorUid: uid,
                actorName: name
            )
            if uid == link.studentUid {
                careStore.markGoalsSyncedWithCoach()
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Coach com personal + nutrição: cria vínculo de nutricionista para aluno que já tem só personal.
    @discardableResult
    func enableNutritionistLink(forExisting personalLink: CoachLink) async -> CoachLink? {
        guard let user = authService?.currentUser,
              user.id == personalLink.coachUid,
              personalLink.profession == .personal,
              personalLink.isActiveLike else {
            lastError = "Vínculo inválido."
            return nil
        }
        guard coachHasNutritionistProfession else {
            lastError = "Complete o cadastro com CRN para ativar nutrição neste aluno."
            return nil
        }
        // Só quem é personal E nutrição ativa o segundo vínculo a partir do personal.
        guard isDualProfessional else {
            lastError = "Somente Personal e Nutrição pode ativar cardápio em aluno de personal."
            return nil
        }
        if let existing = myLinks.first(where: {
            $0.coachUid == personalLink.coachUid
                && $0.studentUid == personalLink.studentUid
                && $0.profession == .nutritionist
                && $0.isActiveLike
        }) {
            return existing
        }

        let linkId = CoachCodeGenerator.makeLinkId(
            coachUid: personalLink.coachUid,
            studentUid: personalLink.studentUid,
            profession: .nutritionist
        )
        let link = CoachLink(
            id: linkId,
            coachUid: personalLink.coachUid,
            coachName: personalLink.coachName,
            coachPhotoURL: personalLink.coachPhotoURL,
            studentUid: personalLink.studentUid,
            studentName: personalLink.studentName,
            studentPhotoURL: personalLink.studentPhotoURL,
            profession: .nutritionist,
            status: personalLink.status,
            memberUids: personalLink.memberUids,
            createdAt: .now,
            updatedAt: .now,
            activatedAt: personalLink.activatedAt ?? .now
        )
        do {
            try await CoachFirestoreService.saveLink(link)
            upsertLink(link)
            return link
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    var coachHasNutritionistProfession: Bool {
        if myProfile?.professions.contains(.nutritionist) == true { return true }
        return authService?.currentUser?.accountRole.isNutritionProfessional == true
    }

    var coachHasPersonalProfession: Bool {
        if myProfile?.professions.contains(.personal) == true { return true }
        return authService?.currentUser?.accountRole.isPersonalProfessional == true
    }

    /// Personal e Nutrição: pode enviar ficha e cardápio.
    var isDualProfessional: Bool {
        coachHasPersonalProfession && coachHasNutritionistProfession
    }

    /// Cardápio: só no vínculo de nutrição (ou dual no aluno personal).
    func canPrescribeMeals(on link: CoachLink) -> Bool {
        guard link.isActiveLike, coachHasNutritionistProfession else { return false }
        if link.profession == .nutritionist { return true }
        // Dual: pode enviar cardápio também no vínculo personal do mesmo aluno.
        return isDualProfessional && link.profession == .personal
    }

    /// Treino: só no vínculo de personal. Nunca na função nutricionista.
    func canPrescribeWorkouts(on link: CoachLink) -> Bool {
        guard link.isActiveLike, coachHasPersonalProfession else { return false }
        return link.profession == .personal
    }

    // MARK: - Consultations

    func availability(for coachUid: String) -> CoachAvailability {
        availabilityByCoachUid[coachUid] ?? .empty(coachUid: coachUid)
    }

    func saveAvailability(_ availability: CoachAvailability) async -> Bool {
        guard let uid = currentUid, uid == availability.coachUid else { return false }
        do {
            var copy = availability
            copy.updatedAt = .now
            try await CoachFirestoreService.saveAvailability(copy)
            availabilityByCoachUid[uid] = copy
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Todos os compromissos ativos (propostos/confirmados) do profissional, em todos os vínculos.
    func allActiveConsultations(forCoachUid coachUid: String) -> [ConsultationBooking] {
        myLinks
            .filter { $0.coachUid == coachUid }
            .flatMap { consultationsByLink[$0.id] ?? [] }
            .filter { $0.status == .proposed || $0.status == .confirmed }
            .sorted { $0.startAt < $1.startAt }
    }

    func openConsultationSlots(
        for link: CoachLink,
        daysAhead: Int = 14,
        limit: Int = 48
    ) async -> [ConsultationOpenSlot] {
        let availability = availability(for: link.coachUid)
        // Conflita com qualquer aluno do mesmo profissional, não só o vínculo atual.
        let existing = allActiveConsultations(forCoachUid: link.coachUid)
        let from = Date()
        let to = Calendar.current.date(byAdding: .day, value: daysAhead, to: from) ?? from.addingTimeInterval(14 * 86400)
        let busy = await ConsultationCalendarService.busyIntervals(from: from, to: to)
        return ConsultationSlotEngine.openSlots(
            availability: availability,
            existing: existing,
            busyIntervals: busy,
            from: from,
            daysAhead: daysAhead,
            limit: limit
        )
    }

    func scheduleConsultation(
        link: CoachLink,
        startAt: Date,
        mode: ConsultationBookingMode,
        note: String,
        autoConfirmIfCoach _: Bool = true
    ) async -> ConsultationBooking? {
        guard let uid = currentUid else { return nil }
        guard link.isActiveLike else {
            lastError = "Vínculo precisa estar ativo para agendar."
            return nil
        }
        let availability = availability(for: link.coachUid)
        let duration = availability.slotDurationMinutes
        // Confirmada ao agendar (aluno ou profissional) — com lembretes automáticos.
        let status: ConsultationStatus = .confirmed
        var booking = ConsultationBooking.make(
            link: link,
            startAt: startAt,
            durationMinutes: duration,
            mode: mode,
            note: note,
            createdByUid: uid,
            status: status
        )
        do {
            if availability.syncToDeviceCalendar {
                if let eventId = await ConsultationCalendarService.syncBooking(booking, promptIfNeeded: true) {
                    booking.calendarEventId = eventId
                }
            }
            try await CoachFirestoreService.publishConsultation(booking)
            var list = consultationsByLink[link.id] ?? []
            list.removeAll { $0.id == booking.id }
            list.append(booking)
            consultationsByLink[link.id] = list.sorted { $0.startAt < $1.startAt }
            NotificationService.shared.requestAuthorization()
            NotificationService.shared.scheduleConsultationReminders(for: booking)
            // Avisa o outro lado via chat (gera push/local no destinatário).
            let peerIsCoach = uid == link.studentUid
            let who = peerIsCoach ? booking.studentName : booking.coachName
            let chatText = peerIsCoach
                ? "✅ \(who) agendou: \(booking.confirmedScheduleLabel)"
                : "✅ Consulta marcada: \(booking.confirmedScheduleLabel)"
            _ = await sendChat(link: link, text: chatText)
            return booking
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// Remarca data/hora, mantém lembretes e calendário atualizados.
    func rescheduleConsultation(_ booking: ConsultationBooking, newStartAt: Date) async -> ConsultationBooking? {
        guard let uid = currentUid else { return nil }
        guard uid == booking.coachUid || uid == booking.studentUid else { return nil }
        guard booking.isUpcoming else {
            lastError = "Só é possível remarcar consultas futuras."
            return nil
        }
        let duration = max(Int(booking.endAt.timeIntervalSince(booking.startAt) / 60), 15)
        var updated = booking
        updated.startAt = newStartAt
        updated.endAt = newStartAt.addingTimeInterval(TimeInterval(duration * 60))
        updated.status = .confirmed
        updated.updatedAt = .now
        do {
            if let eventId = await ConsultationCalendarService.syncBooking(updated, promptIfNeeded: true) {
                updated.calendarEventId = eventId
            }
            try await CoachFirestoreService.publishConsultation(updated)
            var list = consultationsByLink[booking.linkId] ?? []
            if let idx = list.firstIndex(where: { $0.id == booking.id }) {
                list[idx] = updated
            }
            consultationsByLink[booking.linkId] = list.sorted { $0.startAt < $1.startAt }
            NotificationService.shared.scheduleConsultationReminders(for: updated)
            if let link = myLinks.first(where: { $0.id == booking.linkId }) {
                let actor = uid == booking.studentUid ? booking.studentName : booking.coachName
                _ = await sendChat(
                    link: link,
                    text: "🔄 \(actor) remarcou a consulta para \(updated.shortScheduleLabel)."
                )
            }
            return updated
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// Cancela/exclui agendamento, remove lembretes e notifica o outro (profissional ou aluno).
    func cancelConsultation(_ booking: ConsultationBooking, notifyPeer: Bool = true) async -> Bool {
        guard let uid = currentUid else { return false }
        guard uid == booking.coachUid || uid == booking.studentUid else { return false }
        let ok = await updateConsultationStatus(booking, status: .cancelled)
        guard ok else { return false }
        NotificationService.shared.cancelConsultationReminders(bookingId: booking.id)
        if notifyPeer, let link = myLinks.first(where: { $0.id == booking.linkId }) {
            let isStudent = uid == booking.studentUid
            let actor = isStudent ? booking.studentName : booking.coachName
            let peerTitle = isStudent ? "Cancelamento pelo aluno" : "Cancelamento pelo profissional"
            let body = "❌ \(actor) cancelou a consulta de \(booking.shortScheduleLabel)."
            _ = await sendChat(link: link, text: body)
            // Notificação local no aparelho de quem cancelou (confirmação).
            NotificationService.shared.deliverConsultationStatusNotification(
                title: peerTitle,
                body: "Consulta de \(booking.shortScheduleLabel) cancelada.",
                linkId: link.id,
                bookingId: booking.id
            )
        }
        return true
    }

    func updateConsultationStatus(_ booking: ConsultationBooking, status: ConsultationStatus) async -> Bool {
        guard let uid = currentUid else { return false }
        guard uid == booking.coachUid || uid == booking.studentUid else { return false }
        var updated = booking
        updated.status = status
        updated.updatedAt = .now
        do {
            if status == .cancelled || status == .declined {
                await ConsultationCalendarService.removeBookingEvent(
                    bookingId: updated.id,
                    eventId: updated.calendarEventId
                )
                updated.calendarEventId = nil
                NotificationService.shared.cancelConsultationReminders(bookingId: updated.id)
            } else if status == .confirmed || status == .proposed {
                if let eventId = await ConsultationCalendarService.syncBooking(updated, promptIfNeeded: true) {
                    updated.calendarEventId = eventId
                }
                if status == .confirmed {
                    NotificationService.shared.scheduleConsultationReminders(for: updated)
                }
            }
            try await CoachFirestoreService.publishConsultation(updated)
            var list = consultationsByLink[booking.linkId] ?? []
            if let idx = list.firstIndex(where: { $0.id == booking.id }) {
                list[idx] = updated
            }
            consultationsByLink[booking.linkId] = list
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Chat

    func sendChat(link: CoachLink, text: String) async -> Bool {
        guard link.status == .active else {
            lastError = "Chat disponível apenas com vínculo ativo e plano Fit+."
            return false
        }
        guard let user = authService?.currentUser else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let message = CoachChatMessage(
            id: UUID().uuidString,
            linkId: link.id,
            senderUid: user.id,
            senderName: user.greetingName.isEmpty ? user.name : user.greetingName,
            text: String(trimmed.prefix(CoachChatMessage.maxLength)),
            createdAt: .now,
            expiresAt: CoachChatPolicy.expiresAt()
        )
        do {
            try await CoachFirestoreService.sendMessage(message)
            // Optimistic local append until listener catches up.
            var local = chatMessages[link.id] ?? []
            if !local.contains(where: { $0.id == message.id }) {
                local.append(message)
                chatMessages[link.id] = Self.filterActiveMessages(local)
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func ensureChatListening(linkId: String) {
        if chatListeners[linkId] == nil {
            chatListeners[linkId] = CoachFirestoreService.listenMessages(linkId: linkId) { [weak self] messages in
                Task { @MainActor in
                    guard let self else { return }
                    let active = Self.filterActiveMessages(messages)
                    self.notifyIncomingCoachChatIfNeeded(linkId: linkId, messages: active)
                    self.chatMessages[linkId] = active
                    self.acknowledgeDeliveredIfNeeded(linkId: linkId, messages: active)
                    await self.purgeExpiredMessages(linkId: linkId, from: messages)
                }
            }
        } else if let messages = chatMessages[linkId] {
            acknowledgeDeliveredIfNeeded(linkId: linkId, messages: messages)
        }
    }

    private func notifyIncomingCoachChatIfNeeded(linkId: String, messages: [CoachChatMessage]) {
        // Primeiro snapshot = histórico; não notifica.
        guard chatListenerPrimed.contains(linkId) else {
            chatListenerPrimed.insert(linkId)
            notifiedCoachChatMessageIds.formUnion(messages.map(\.id))
            return
        }
        guard let uid = currentUid else { return }
        let viewingThisChat = CoachNavigationRouter.shared.presentedChat?.linkId == linkId
        for message in messages where message.senderUid != uid {
            guard !notifiedCoachChatMessageIds.contains(message.id) else { continue }
            notifiedCoachChatMessageIds.insert(message.id)
            // Com o chat aberto e app em foreground, o bubble já mostra a mensagem.
            if viewingThisChat { continue }
            let preview = String(message.text.prefix(120))
            NotificationService.shared.deliverCoachChatNotification(
                title: message.senderName.isEmpty ? "HealthFit Coach" : message.senderName,
                body: preview,
                linkId: linkId,
                messageId: message.id
            )
        }
        if notifiedCoachChatMessageIds.count > 400 {
            notifiedCoachChatMessageIds = Set(notifiedCoachChatMessageIds.suffix(200))
        }
    }

    private static func filterActiveMessages(_ messages: [CoachChatMessage]) -> [CoachChatMessage] {
        CoachFirestoreService.sortedChatMessages(messages.filter { !$0.isExpired })
    }

    private func purgeExpiredMessages(linkId: String, from messages: [CoachChatMessage]) async {
        let expiredIds = messages.filter(\.isExpired).map(\.id)
        guard !expiredIds.isEmpty else { return }
        try? await CoachFirestoreService.deleteMessages(linkId: linkId, messageIds: expiredIds)
    }

    /// Marca mensagens recebidas como entregues (outro aparelho sincroniza os ticks).
    /// Processa em ordem cronológica para a indicação de recebimento ficar sequencial.
    func acknowledgeDeliveredIfNeeded(linkId: String, messages: [CoachChatMessage]? = nil) {
        guard let uid = currentUid else { return }
        let list = CoachFirestoreService.sortedChatMessages(messages ?? chatMessages[linkId] ?? [])
        let pending = list.filter { $0.senderUid != uid && $0.deliveredAt == nil }
        guard !pending.isEmpty else { return }
        Task {
            var cursor = Date()
            for message in pending.prefix(40) {
                // Avança 1 ms entre ticks para manter ordem visível se várias chegam juntas.
                cursor = max(cursor, message.createdAt).addingTimeInterval(0.001)
                try? await CoachFirestoreService.updateMessageReceipt(
                    linkId: linkId,
                    messageId: message.id,
                    deliveredAt: cursor
                )
            }
        }
    }

    /// Marca mensagens recebidas como lidas ao abrir o chat (em ordem).
    func markChatRead(linkId: String) {
        guard let uid = currentUid else { return }
        let list = CoachFirestoreService.sortedChatMessages(chatMessages[linkId] ?? [])
        let pending = list.filter { $0.senderUid != uid && $0.readAt == nil }
        guard !pending.isEmpty else { return }
        Task {
            var cursor = Date()
            for message in pending.prefix(40) {
                let delivered = message.deliveredAt ?? cursor
                cursor = max(cursor, delivered).addingTimeInterval(0.001)
                try? await CoachFirestoreService.updateMessageReceipt(
                    linkId: linkId,
                    messageId: message.id,
                    deliveredAt: delivered,
                    readAt: cursor
                )
            }
        }
    }

    // MARK: - Directory

    func searchCoaches(
        name: String? = nil,
        city: String?,
        stateCode: String?,
        profession: CoachProfession?
    ) async -> [CoachProfessionalProfile] {
        do {
            var results = try await CoachFirestoreService.searchDirectory(
                name: name,
                city: city,
                stateCode: stateCode,
                profession: profession
            )
            // Completa foto ausente a partir do diretório / Storage do perfil.
            for index in results.indices where (results[index].photoURL ?? "").isEmpty {
                if let url = await Self.resolveCoachPhotoURL(userId: results[index].uid) {
                    results[index].photoURL = url
                }
            }
            return results
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    /// Foto do perfil do app (userDirectory ou Storage).
    static func resolveCoachPhotoURL(userId: String) async -> String? {
        if let fromDirectory = try? await ProfileFirestoreService.fetchDirectoryEntry(userId: userId)?.photoURL,
           !fromDirectory.isEmpty {
            return fromDirectory
        }
        return await ProfilePhotoStorageService.downloadURLIfExists(userId: userId)
    }

    /// Propaga a foto de perfil do usuário atual para todos os vínculos Coach (aluno ou profissional).
    func refreshMyPhotoAcrossLinks(photoURL: String?) async {
        guard let uid = currentUid else { return }
        let normalized = photoURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextURL = (normalized?.isEmpty == false) ? normalized : nil

        await syncProfessionalProfilePhoto(photoURL: nextURL)

        var links = myLinks
        if links.isEmpty {
            links = await Self.fetchLinksForUser(uid: uid)
        }

        for link in links {
            var updated = link
            var changed = false
            if link.studentUid == uid, link.studentPhotoURL != nextURL {
                updated.studentPhotoURL = nextURL
                changed = true
            }
            if link.coachUid == uid, link.coachPhotoURL != nextURL {
                updated.coachPhotoURL = nextURL
                changed = true
            }
            guard changed else { continue }
            updated.updatedAt = .now
            try? await CoachFirestoreService.saveLink(updated)
        }
    }

    /// Atualiza a foto no cadastro profissional (busca regional + painel personal/nutri).
    func syncProfessionalProfilePhoto(photoURL: String?) async {
        guard let uid = currentUid else { return }
        let normalized = photoURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextURL = (normalized?.isEmpty == false) ? normalized : nil

        var profile = myProfile
        if profile == nil {
            profile = try? await CoachFirestoreService.fetchProfile(uid: uid)
        }
        guard var profile else { return }
        guard profile.photoURL != nextURL else {
            myProfile = profile
            return
        }
        profile.photoURL = nextURL
        profile.updatedAt = .now
        do {
            try await CoachFirestoreService.saveProfile(profile)
            myProfile = profile
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Garante que o perfil profissional use a foto atual do app (ao abrir o painel).
    func refreshProfessionalPhotoFromAppProfileIfNeeded() async {
        guard let uid = currentUid else { return }
        guard isProfessionalAccount || myProfile != nil else { return }
        let resolved = await Self.resolveCoachPhotoURL(userId: uid)
        await syncProfessionalProfilePhoto(photoURL: resolved)
    }

    private static func fetchLinksForUser(uid: String) async -> [CoachLink] {
        guard CoachFirestoreService.isAvailable else { return [] }
        do {
            let snap = try await Firestore.firestore()
                .collection("users").document(uid).collection("coachMemberships")
                .getDocuments()
            var links: [CoachLink] = []
            for doc in snap.documents {
                if let link = try await CoachFirestoreService.fetchLink(id: doc.documentID) {
                    links.append(link)
                }
            }
            return links
        } catch {
            return []
        }
    }

    // MARK: - Private sync

    private func applyMembershipSnapshots(_ docs: [QueryDocumentSnapshot]) async {
        let linkIds = docs.map(\.documentID)
        let linkIdSet = Set(linkIds)

        myLinks.removeAll { !linkIdSet.contains($0.id) }
        for key in assignedWorkoutsByLink.keys where !linkIdSet.contains(key) {
            assignedWorkoutsByLink.removeValue(forKey: key)
        }
        for key in chatMessages.keys where !linkIdSet.contains(key) {
            chatMessages.removeValue(forKey: key)
        }
        for key in consultationsByLink.keys where !linkIdSet.contains(key) {
            consultationsByLink.removeValue(forKey: key)
        }

        // Drop stale listeners
        for key in linkListeners.keys where !linkIds.contains(key) {
            linkListeners[key]?.remove()
            linkListeners.removeValue(forKey: key)
            workoutListeners[key]?.remove()
            workoutListeners.removeValue(forKey: key)
            mealListeners[key]?.remove()
            mealListeners.removeValue(forKey: key)
            careListeners[key]?.remove()
            careListeners.removeValue(forKey: key)
            consultationListeners[key]?.remove()
            consultationListeners.removeValue(forKey: key)
            chatListeners[key]?.remove()
            chatListeners.removeValue(forKey: key)
        }

        let activeCoachUids = Set(myLinks.map(\.coachUid))
        for key in availabilityListeners.keys where !activeCoachUids.contains(key) {
            availabilityListeners[key]?.remove()
            availabilityListeners.removeValue(forKey: key)
            availabilityByCoachUid.removeValue(forKey: key)
        }

        for linkId in linkIds {
            if linkListeners[linkId] == nil {
                linkListeners[linkId] = CoachFirestoreService.listenLink(id: linkId) { [weak self] link in
                    Task { @MainActor in
                        self?.upsertLink(link)
                    }
                }
            }
            if workoutListeners[linkId] == nil {
                workoutListeners[linkId] = CoachFirestoreService.listenAssignedWorkouts(linkId: linkId) { [weak self] items in
                    Task { @MainActor in
                        self?.assignedWorkoutsByLink[linkId] = items
                        self?.mergeAssignedWorkoutsIntoStore()
                    }
                }
            }
            if mealListeners[linkId] == nil {
                mealListeners[linkId] = CoachFirestoreService.listenMealPlan(linkId: linkId) { [weak self] data in
                    Task { @MainActor in
                        self?.applyCoachMealPlan(linkId: linkId, data: data)
                    }
                }
            }
            if careListeners[linkId] == nil {
                careListeners[linkId] = CoachFirestoreService.listenNutritionCare(linkId: linkId) { [weak self] data in
                    Task { @MainActor in
                        self?.applyNutritionCare(linkId: linkId, data: data)
                    }
                }
            }
            if consultationListeners[linkId] == nil {
                consultationListeners[linkId] = CoachFirestoreService.listenConsultations(linkId: linkId) { [weak self] items in
                    Task { @MainActor in
                        self?.consultationsByLink[linkId] = items
                    }
                }
            }
            if let link = myLinks.first(where: { $0.id == linkId }),
               availabilityListeners[link.coachUid] == nil {
                availabilityListeners[link.coachUid] = CoachFirestoreService.listenAvailability(coachUid: link.coachUid) { [weak self] availability in
                    Task { @MainActor in
                        if let availability {
                            self?.availabilityByCoachUid[link.coachUid] = availability
                        } else {
                            self?.availabilityByCoachUid[link.coachUid] = .empty(coachUid: link.coachUid)
                        }
                    }
                }
            }
            // Chat em tempo real para vínculos ativos (aluno e coach).
            ensureChatListening(linkId: linkId)
        }
    }

    private func upsertLink(_ link: CoachLink?) {
        guard let link else { return }
        if link.status == .ended {
            myLinks.removeAll { $0.id == link.id }
            return
        }
        if let idx = myLinks.firstIndex(where: { $0.id == link.id }) {
            myLinks[idx] = link
        } else {
            myLinks.append(link)
        }
        myLinks.sort { $0.updatedAt > $1.updatedAt }
        if link.studentUid == currentUid, link.isActiveLike {
            applyProfileAutoFill(from: link)
        }
        enrichMissingLinkPhotosIfNeeded(link)
    }

    /// Preenche fotos ausentes em vínculos antigos (criados antes da sincronização).
    private func enrichMissingLinkPhotosIfNeeded(_ link: CoachLink) {
        let needsStudent = (link.studentPhotoURL ?? "").isEmpty
        let needsCoach = (link.coachPhotoURL ?? "").isEmpty
        guard needsStudent || needsCoach else { return }

        Task {
            var updated = link
            var changed = false
            if needsStudent,
               let url = await Self.resolveCoachPhotoURL(userId: link.studentUid),
               !url.isEmpty {
                updated.studentPhotoURL = url
                changed = true
            }
            if needsCoach,
               let url = await Self.resolveCoachPhotoURL(userId: link.coachUid),
               !url.isEmpty {
                updated.coachPhotoURL = url
                changed = true
            }
            guard changed else { return }
            updated.updatedAt = .now
            try? await CoachFirestoreService.saveLink(updated)
        }
    }

    private func mergeAssignedWorkoutsIntoStore() {
        guard let store = workoutStore, let uid = currentUid else { return }
        // Only merge into the student device (or keep coach local copy too)
        let all = assignedWorkoutsByLink.values.flatMap { $0 }
        let relevant = all.filter { $0.studentUid == uid || $0.coachUid == uid }
        let activeIds = Set(relevant.filter(\.isActive).map(\.sheet.id))
        let knownLinkIds = Set(assignedWorkoutsByLink.keys)

        for item in relevant where item.isActive {
            var sheet = item.sheet
            sheet.isCoachPrescribed = true
            sheet.coachLinkId = item.linkId
            sheet.prescribedByUid = item.coachUid
            sheet.prescribedByName = item.coachName
            sheet.assignedTo = item.studentUid
            sheet.updatedAt = item.updatedAt
            if let existing = store.workoutSheets.first(where: { $0.id == sheet.id }) {
                if existing.updatedAt <= sheet.updatedAt {
                    store.applyCoachPrescribedSheet(sheet)
                }
            } else {
                store.addWorkoutSheet(sheet)
            }
        }

        // Remove fichas do Coach que o personal excluiu (sumiram do listener).
        let stale = store.workoutSheets.filter { sheet in
            guard sheet.isCoachPrescribed,
                  let linkId = sheet.coachLinkId,
                  knownLinkIds.contains(linkId) else { return false }
            return !activeIds.contains(sheet.id)
        }
        for sheet in stale {
            store.removeCoachPrescribedSheet(sheet)
        }
    }

    private func applyCoachMealPlan(linkId: String, data: [String: Any]?) {
        guard let data,
              let uid = currentUid,
              let link = myLinks.first(where: { $0.id == linkId }),
              link.studentUid == uid,
              link.status == .active,
              studentCanUseCoachFeatures,
              let raw = data["weeklyPlan"] else { return }
        do {
            let json = try JSONSerialization.data(withJSONObject: raw)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let plan = try decoder.decode([DailyMealPlan].self, from: json)
            mealPlanService?.applyCoachPrescribedPlan(plan, coachName: data["coachName"] as? String)
            if let name = data["coachName"] as? String, !name.isEmpty {
                applyNutritionistName(name)
            }
        } catch {
            #if DEBUG
            print("[Coach] meal plan decode: \(error)")
            #endif
        }
    }

    private func applyNutritionCare(linkId: String, data: [String: Any]?) {
        guard let data,
              myLinks.contains(where: { $0.id == linkId }),
              let bundleRaw = data["bundle"] as? [String: Any],
              let remote = NutritionCareStore.shared.decodeBundle(from: bundleRaw) else { return }
        NutritionCareStore.shared.applyRemote(linkId: linkId, remote: remote)
    }

    private func applyProfileAutoFill(from link: CoachLink) {
        guard var user = authService?.currentUser, link.studentUid == user.id else { return }
        var changed = false
        switch link.profession {
        case .personal:
            if !user.usesPersonalTrainer || user.personalTrainerName != link.coachName {
                user.usesPersonalTrainer = true
                user.personalTrainerName = link.coachName
                changed = true
            }
        case .nutritionist:
            if !user.usesNutritionist || user.nutritionistName != link.coachName {
                user.usesNutritionist = true
                user.nutritionistName = link.coachName
                changed = true
            }
        }
        if changed {
            authService?.updateProfile(user)
        }
    }

    private func clearProfileAutoFill(for profession: CoachProfession) {
        guard var user = authService?.currentUser else { return }
        switch profession {
        case .personal:
            user.usesPersonalTrainer = false
            user.personalTrainerName = ""
            user.personalTrainerEmail = ""
        case .nutritionist:
            user.usesNutritionist = false
            user.nutritionistName = ""
            user.nutritionistEmail = ""
        }
        authService?.updateProfile(user)
    }

    private func applyNutritionistName(_ name: String) {
        guard var user = authService?.currentUser else { return }
        user.usesNutritionist = true
        user.nutritionistName = name
        authService?.updateProfile(user)
    }
}
