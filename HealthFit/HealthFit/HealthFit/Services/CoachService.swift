import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class CoachService: ObservableObject {
    static let shared = CoachService()

    @Published private(set) var myProfile: CoachProfessionalProfile?
    @Published private(set) var myLinks: [CoachLink] = []
    @Published private(set) var assignedWorkoutsByLink: [String: [CoachAssignedWorkout]] = [:]
    @Published private(set) var chatMessages: [String: [CoachChatMessage]] = [:]
    @Published private(set) var isSyncing = false
    @Published var lastError: String?

    private weak var workoutStore: WorkoutStore?
    private weak var mealPlanService: MealPlanService?
    private weak var authService: AuthService?

    private var membershipListener: ListenerRegistration?
    private var linkListeners: [String: ListenerRegistration] = [:]
    private var workoutListeners: [String: ListenerRegistration] = [:]
    private var mealListeners: [String: ListenerRegistration] = [:]
    private var chatListeners: [String: ListenerRegistration] = [:]

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
        Task { await refreshProfile(uid: uid) }
        membershipListener?.remove()
        membershipListener = CoachFirestoreService.listenMemberships(uid: uid) { [weak self] docs in
            Task { @MainActor in
                await self?.applyMembershipSnapshots(docs)
            }
        }
    }

    func stop() {
        membershipListener?.remove()
        membershipListener = nil
        linkListeners.values.forEach { $0.remove() }
        workoutListeners.values.forEach { $0.remove() }
        mealListeners.values.forEach { $0.remove() }
        chatListeners.values.forEach { $0.remove() }
        linkListeners.removeAll()
        workoutListeners.removeAll()
        mealListeners.removeAll()
        chatListeners.removeAll()
        myLinks = []
        assignedWorkoutsByLink = [:]
        chatMessages = [:]
    }

    // MARK: - Profile

    func refreshProfile(uid: String? = nil) async {
        guard let uid = uid ?? currentUid else { return }
        do {
            myProfile = try await CoachFirestoreService.fetchProfile(uid: uid)
        } catch {
            lastError = error.localizedDescription
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
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Invite / accept

    func createStudentInvite(profession: CoachProfession, toName: String? = nil, toEmail: String? = nil) async -> CoachInvite? {
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
            toUid: nil,
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
            let link = CoachLink(
                id: linkId,
                coachUid: invite.fromUid,
                coachName: invite.fromName,
                coachPhotoURL: nil,
                studentUid: user.id,
                studentName: user.greetingName.isEmpty ? user.name : user.greetingName,
                studentPhotoURL: nil,
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
            return true
        } catch {
            lastError = error.localizedDescription
            return false
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

    // MARK: - Prescribe workout

    func publishWorkout(link: CoachLink, sheet: WorkoutSheet) async -> Bool {
        guard let uid = currentUid, uid == link.coachUid else { return false }
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
            createdAt: .now
        )
        do {
            try await CoachFirestoreService.sendMessage(message)
            // Optimistic local append until listener catches up.
            var local = chatMessages[link.id] ?? []
            if !local.contains(where: { $0.id == message.id }) {
                local.append(message)
                chatMessages[link.id] = local
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
                    self?.chatMessages[linkId] = messages
                    self?.acknowledgeDeliveredIfNeeded(linkId: linkId, messages: messages)
                }
            }
        } else if let messages = chatMessages[linkId] {
            acknowledgeDeliveredIfNeeded(linkId: linkId, messages: messages)
        }
    }

    /// Marca mensagens recebidas como entregues (outro aparelho sincroniza os ticks).
    func acknowledgeDeliveredIfNeeded(linkId: String, messages: [CoachChatMessage]? = nil) {
        guard let uid = currentUid else { return }
        let list = messages ?? chatMessages[linkId] ?? []
        let pending = list.filter { $0.senderUid != uid && $0.deliveredAt == nil }
        guard !pending.isEmpty else { return }
        Task {
            let now = Date()
            for message in pending.prefix(40) {
                try? await CoachFirestoreService.updateMessageReceipt(
                    linkId: linkId,
                    messageId: message.id,
                    deliveredAt: now
                )
            }
        }
    }

    /// Marca mensagens recebidas como lidas ao abrir o chat.
    func markChatRead(linkId: String) {
        guard let uid = currentUid else { return }
        let list = chatMessages[linkId] ?? []
        let pending = list.filter { $0.senderUid != uid && $0.readAt == nil }
        guard !pending.isEmpty else { return }
        Task {
            let now = Date()
            for message in pending.prefix(40) {
                try? await CoachFirestoreService.updateMessageReceipt(
                    linkId: linkId,
                    messageId: message.id,
                    deliveredAt: message.deliveredAt ?? now,
                    readAt: now
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

    // MARK: - Private sync

    private func applyMembershipSnapshots(_ docs: [QueryDocumentSnapshot]) async {
        let linkIds = docs.map(\.documentID)
        // Drop stale listeners
        for key in linkListeners.keys where !linkIds.contains(key) {
            linkListeners[key]?.remove()
            linkListeners.removeValue(forKey: key)
            workoutListeners[key]?.remove()
            workoutListeners.removeValue(forKey: key)
            mealListeners[key]?.remove()
            mealListeners.removeValue(forKey: key)
            chatListeners[key]?.remove()
            chatListeners.removeValue(forKey: key)
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
            // Chat em tempo real para vínculos ativos (aluno e coach).
            if chatListeners[linkId] == nil {
                chatListeners[linkId] = CoachFirestoreService.listenMessages(linkId: linkId) { [weak self] messages in
                    Task { @MainActor in
                        self?.chatMessages[linkId] = messages
                    }
                }
            }
        }
    }

    private func upsertLink(_ link: CoachLink?) {
        guard let link else { return }
        if let idx = myLinks.firstIndex(where: { $0.id == link.id }) {
            myLinks[idx] = link
        } else {
            myLinks.append(link)
        }
        myLinks.sort { $0.updatedAt > $1.updatedAt }
        if link.studentUid == currentUid {
            applyProfileAutoFill(from: link)
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
            mealPlanService?.applyCoachPrescribedPlan(plan)
            if let name = data["coachName"] as? String, !name.isEmpty {
                applyNutritionistName(name)
            }
        } catch {
            #if DEBUG
            print("[Coach] meal plan decode: \(error)")
            #endif
        }
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

    private func applyNutritionistName(_ name: String) {
        guard var user = authService?.currentUser else { return }
        user.usesNutritionist = true
        user.nutritionistName = name
        authService?.updateProfile(user)
    }
}
