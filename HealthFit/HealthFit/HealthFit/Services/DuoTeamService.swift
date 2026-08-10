import Combine
import Foundation
import FirebaseFirestore
import UIKit

@MainActor
final class DuoTeamService: ObservableObject {
    static let shared = DuoTeamService()

    @Published private(set) var teams: [DuoTeam] = []
    @Published private(set) var sentInvites: [DuoTeamInvite] = []
    @Published private(set) var receivedInvites: [DuoTeamInvite] = []
    @Published private(set) var messagesByTeam: [String: [DuoChatMessage]] = [:]
    @Published var lastError: String?
    @Published private(set) var isLoading = false

    private var boundUserId: String?
    private var boundUserName: String = "Atleta"
    private var boundCountryCode: String?
    private var boundPhotoURL: String?
    private var listeners: [String: ListenerRegistration] = [:]
    private var inboxListener: ListenerRegistration?
    private var deliveringInboxIds: Set<String> = []

    private enum ScopedKey {
        static let teams = "duo_teams"
        static let invites = "duo_invites"
        static let notifiedPendingInvites = "duo_notified_pending_invites"
    }

    private init() {}

    var hasPrivacyConsent: Bool { DuoTeamPrivacy.hasAcknowledged }

    func acknowledgePrivacy() {
        DuoTeamPrivacy.acknowledge()
    }

    func bind(
        userId: String?,
        userName: String?,
        countryCode: String? = nil,
        photoURL: String? = nil
    ) {
        tearDownListeners()
        boundUserId = userId
        if let userName {
            let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { boundUserName = trimmed }
        }
        if let countryCode {
            let trimmed = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            boundCountryCode = trimmed.isEmpty ? nil : trimmed
        }
        if let photoURL {
            boundPhotoURL = photoURL
        }
        loadLocal()
        guard userId != nil else {
            teams = []
            sentInvites = []
            receivedInvites = []
            boundCountryCode = nil
            boundPhotoURL = nil
            return
        }
    }

    func loadIfNeeded() async {
        guard let userId = boundUserId else { return }
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        if let entry = try? await ProfileFirestoreService.fetchMemberPublicProfile(userId: userId) {
            if !entry.shownName.isEmpty { boundUserName = entry.shownName }
            if let code = entry.countryCode, !code.isEmpty {
                boundCountryCode = code
            }
            if let photo = entry.photoURL, !photo.isEmpty {
                boundPhotoURL = photo
            }
        }

        // Cada etapa é isolada: falha em convites não bloqueia as equipes.
        do {
            let localTeams = teams
            let remoteTeams = try await DuoTeamFirestoreService.fetchTeams(forUserId: userId)
            teams = await mergeTeamsPreferringCloud(local: localTeams, remote: remoteTeams)
        } catch {
            print("[HealthFit] Duo teams sync: \(error.localizedDescription)")
            lastError = "Não foi possível sincronizar as equipes com o banco."
        }

        do {
            let remoteInvites = try await DuoTeamFirestoreService.fetchInvitesSent(byUserId: userId)
            if !remoteInvites.isEmpty {
                sentInvites = remoteInvites
            }
        } catch {
            print("[HealthFit] Duo invites sent sync: \(error.localizedDescription)")
        }

        do {
            receivedInvites = try await DuoTeamFirestoreService.fetchPendingInvites(forUserId: userId)
                .filter { !$0.isExpired && $0.status == .pending }
            notifyNewPendingInvitesIfNeeded(receivedInvites, userId: userId)
        } catch {
            print("[HealthFit] Duo pending invites sync: \(error.localizedDescription)")
        }

        await deliverInboxNotificationsIfNeeded(userId: userId)
        startInboxListenerIfNeeded(userId: userId)

        await refreshMyMemberProfileAcrossTeams()
        persistLocal()
    }

    /// Atualiza convites (recebidos/enviados), remove expirados e limpa a lista.
    func refreshInvites() async {
        guard let userId = boundUserId else { return }
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let remoteSent = try await DuoTeamFirestoreService.fetchInvitesSent(byUserId: userId)
            if !remoteSent.isEmpty {
                sentInvites = remoteSent
            }
        } catch {
            print("[HealthFit] Duo refresh sent invites: \(error.localizedDescription)")
        }

        do {
            let remoteReceived = try await DuoTeamFirestoreService.fetchPendingInvites(forUserId: userId)
            receivedInvites = remoteReceived.filter { !$0.isExpired && $0.status == .pending }
        } catch {
            print("[HealthFit] Duo refresh received invites: \(error.localizedDescription)")
        }

        await purgeExpiredInvites(userId: userId)
        persistLocal()
    }

    /// Pull-to-refresh da tela Dupla / equipe.
    func refreshAll() async {
        await loadIfNeeded()
        await purgeExpiredInvites(userId: boundUserId)
    }

    private func purgeExpiredInvites(userId: String?) async {
        guard let userId else { return }

        let expiredReceived = receivedInvites.filter(\.isExpired)
        for invite in expiredReceived {
            try? await DuoTeamFirestoreService.deletePendingInvite(forUserId: userId, inviteId: invite.id)
            try? await DuoTeamFirestoreService.deleteJoinAccess(forUserId: userId, teamId: invite.teamId)
        }
        if !expiredReceived.isEmpty {
            receivedInvites.removeAll { $0.isExpired }
        }

        // Enviados: marca expirados localmente e some da lista pendente.
        var sentChanged = false
        for index in sentInvites.indices where sentInvites[index].status == .pending && sentInvites[index].isExpired {
            sentInvites[index].status = .expired
            sentChanged = true
            var updated = sentInvites[index]
            updated.status = .expired
            try? await DuoTeamFirestoreService.saveInvite(updated)
            if let toUid = updated.toUid, !toUid.isEmpty {
                try? await DuoTeamFirestoreService.deletePendingInvite(forUserId: toUid, inviteId: updated.id)
                try? await DuoTeamFirestoreService.deleteJoinAccess(forUserId: toUid, teamId: updated.teamId)
            }
        }
        if sentChanged {
            // Dispara @Published.
            sentInvites = sentInvites
        }
    }

    func clearAllLocalData() {
        tearDownListeners()
        if let uid = boundUserId {
            UserScopedDefaults.remove(logicalKey: ScopedKey.teams, uid: uid, legacyKey: nil)
            UserScopedDefaults.remove(logicalKey: ScopedKey.invites, uid: uid, legacyKey: nil)
        }
        DuoTeamPrivacy.reset()
        teams = []
        sentInvites = []
        receivedInvites = []
        messagesByTeam = [:]
        boundUserId = nil
        boundCountryCode = nil
        boundPhotoURL = nil
    }

    func searchAppUsers(query: String) async -> [UserDirectoryEntry] {
        lastError = nil
        do {
            return try await ProfileFirestoreService.searchUsers(
                query: query,
                excludingUserId: boundUserId
            )
        } catch {
            print("[HealthFit] Duo user search: \(error.localizedDescription)")
            lastError = "Não foi possível buscar usuários. Verifique a conexão e se as regras do Firestore estão publicadas."
            return []
        }
    }

    /// Garante que o usuário logado aparece no diretório de busca.
    func ensureDirectorySynced(profile: UserProfile?) async {
        guard let profile else { return }
        do {
            try await ProfileFirestoreService.syncUserDirectory(profile, photoURL: boundPhotoURL)
        } catch {
            print("[HealthFit] Duo directory sync: \(error.localizedDescription)")
            lastError = "Não foi possível publicar seu perfil no diretório de busca."
        }
    }

    // MARK: - Create / invite / join

    func createTeam(name: String, modalities: [DuoTeamModality]) async -> DuoTeam? {
        guard hasPrivacyConsent else {
            lastError = "Confirme o aviso de privacidade antes de continuar."
            return nil
        }
        guard let userId = boundUserId else {
            lastError = "Faça login para criar uma equipe."
            return nil
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Informe um nome para a dupla/equipe."
            return nil
        }
        let selected = modalities.filter { $0 != .mixed }
        guard !selected.isEmpty else {
            lastError = "Selecione pelo menos uma modalidade para o grupo."
            return nil
        }

        let team = DuoTeam(
            id: UUID().uuidString,
            name: trimmed,
            modalities: selected,
            createdByUid: userId,
            createdByName: boundUserName,
            members: [
                makeSelfMember(uid: userId)
            ],
            createdAt: .now,
            updatedAt: .now,
            privacyAcknowledged: true
        )
        teams.insert(team, at: 0)
        persistLocal()
        do {
            try await DuoTeamFirestoreService.saveTeam(team)
            let system = DuoChatMessage(
                id: UUID().uuidString,
                teamId: team.id,
                senderUid: userId,
                senderName: "HealthFit",
                text: "Equipe criada. O chat é só para marcar atividades físicas; mensagens expiram em 12h. Sem localização em tempo real.",
                kind: .system,
                createdAt: .now,
                proposedAt: nil
            )
            try await DuoTeamFirestoreService.saveMessage(system)
        } catch {
            lastError = "Não foi possível salvar a equipe no banco. Ela ficou no aparelho e será reenviada na próxima sincronização."
            // Mantém local; `loadIfNeeded` tenta subir de novo.
        }
        NotificationService.shared.deliverDuoTeamNotification(
            title: "Treino em dupla/equipe",
            body: "“\(team.name)” criada. Convide alguém para treinar com você."
        )
        return team
    }

    /// Cria convite + texto motivador para SMS.
    func createInvite(
        team: DuoTeam,
        partnerName: String,
        phone: String
    ) async -> (invite: DuoTeamInvite, copy: DuoInviteShareCopy)? {
        let name = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneE164 = Self.normalizedPhone(phone)
        guard !name.isEmpty else {
            lastError = "Informe o nome do parceiro."
            return nil
        }
        guard phoneE164.count >= 10 else {
            lastError = "Informe um telefone válido com DDD."
            return nil
        }
        return await makeInvite(
            team: team,
            toName: name,
            toPhoneE164: phoneE164,
            toEmail: nil,
            toUid: nil,
            notifyBody: "Convite para \(name) · código %@. Envie o SMS ou o e-mail — o HealthFit espera por eles."
        )
    }

    /// Cria convite + texto motivador para e-mail.
    func createEmailInvite(
        team: DuoTeam,
        partnerName: String,
        email: String
    ) async -> (invite: DuoTeamInvite, copy: DuoInviteShareCopy)? {
        let name = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !name.isEmpty else {
            lastError = "Informe o nome do parceiro."
            return nil
        }
        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            lastError = "Informe um e-mail válido."
            return nil
        }
        return await makeInvite(
            team: team,
            toName: name,
            toPhoneE164: "",
            toEmail: normalizedEmail,
            toUid: nil,
            notifyBody: "Convite por e-mail para \(name) · código %@. O HealthFit espera por eles."
        )
    }

    /// Código compartilhável para adicionar mais pessoas (WhatsApp, etc.).
    func createShareableInvite(team: DuoTeam) async -> (invite: DuoTeamInvite, copy: DuoInviteShareCopy)? {
        await makeInvite(
            team: team,
            toName: "Novo membro",
            toPhoneE164: "",
            toEmail: nil,
            toUid: nil,
            notifyBody: "Código %@ pronto. Compartilhe — o HealthFit espera pelo novo membro."
        )
    }

    /// Atualiza a foto de capa do grupo (opcional).
    @discardableResult
    func updateTeamPhoto(teamId: String, image: UIImage) async -> Bool {
        guard teams.firstIndex(where: { $0.id == teamId }) != nil else {
            lastError = "Equipe não encontrada."
            return false
        }
        guard let data = Self.jpegDataForUpload(image) else {
            lastError = "Não foi possível preparar a foto."
            return false
        }
        do {
            let url = try await ProfilePhotoStorageService.uploadDuoTeamCoverJPEG(
                data: data,
                teamId: teamId
            )
            guard let freshIndex = teams.firstIndex(where: { $0.id == teamId }) else { return false }
            var updated = teams[freshIndex]
            updated.photoURL = url.absoluteString
            updated.updatedAt = .now
            // Reatribuir o array dispara @Published (mutação in-place não redesenha a UI).
            var next = teams
            next[freshIndex] = updated
            teams = next
            persistLocal()
            try await DuoTeamFirestoreService.saveTeam(updated)
            lastError = nil
            return true
        } catch {
            lastError = "Não foi possível enviar a foto do grupo. Verifique a conexão e tente de novo."
            return false
        }
    }

    /// Remove a foto de capa do grupo.
    @discardableResult
    func removeTeamPhoto(teamId: String) async -> Bool {
        guard let index = teams.firstIndex(where: { $0.id == teamId }) else {
            lastError = "Equipe não encontrada."
            return false
        }
        do {
            try await ProfilePhotoStorageService.deleteDuoTeamCover(teamId: teamId)
            var updated = teams[index]
            updated.photoURL = nil
            updated.updatedAt = .now
            var next = teams
            next[index] = updated
            teams = next
            persistLocal()
            try await DuoTeamFirestoreService.saveTeam(updated)
            lastError = nil
            return true
        } catch {
            lastError = "Não foi possível remover a foto do grupo."
            return false
        }
    }

    /// PHPicker às vezes devolve UIImage sem bitmap pronto para `jpegData`.
    private static func jpegDataForUpload(_ image: UIImage, quality: CGFloat = 0.82) -> Data? {
        if let data = image.jpegData(compressionQuality: quality), !data.isEmpty {
            return data
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = min(image.scale, 2)
        let size = image.size
        guard size.width > 1, size.height > 1 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: quality)
    }

    /// Convida alguém do app; a pessoa precisa aceitar ou recusar.
    @discardableResult
    func inviteAppUser(team: DuoTeam, user: UserDirectoryEntry) async -> Bool {
        if team.members.contains(where: { $0.uid == user.uid }) {
            lastError = "Essa pessoa já está na equipe."
            return false
        }
        if sentInvites.contains(where: {
            $0.teamId == team.id && $0.toUid == user.uid && $0.status == .pending && !$0.isExpired
        }) {
            lastError = "Já existe um convite pendente para \(user.shownName)."
            return false
        }

        guard let result = await makeInvite(
            team: team,
            toName: user.shownName,
            toPhoneE164: "",
            toEmail: nil,
            toUid: user.uid,
            notifyBody: "Convite enviado para \(user.shownName). Aguardando resposta."
        ) else { return false }

        do {
            try await DuoTeamFirestoreService.savePendingInvite(forUserId: user.uid, invite: result.invite)
            try await DuoTeamFirestoreService.saveJoinAccess(
                forUserId: user.uid,
                teamId: team.id,
                invite: result.invite
            )
        } catch {
            lastError = "Convite criado, mas \(user.shownName) pode precisar do código \(result.invite.code)."
        }

        let inbox = DuoInboxNotification(
            id: UUID().uuidString,
            kind: "invitedToTeam",
            title: "Convite para um grupo",
            body: "\(boundUserName) convidou você para “\(team.name)” · \(team.modalitiesLabel). Abra Dupla / equipe para aceitar ou recusar.",
            teamId: team.id,
            teamName: team.name,
            fromUid: result.invite.fromUid,
            fromName: boundUserName,
            createdAt: .now,
            delivered: false
        )
        try? await DuoTeamFirestoreService.saveInboxNotification(forUserId: user.uid, notification: inbox)

        NotificationService.shared.deliverDuoTeamNotification(
            title: "Convite pendente",
            body: "Aguardando \(user.shownName) aceitar o convite para “\(team.name)”."
        )
        return true
    }

    @discardableResult
    func acceptReceivedInvite(_ invite: DuoTeamInvite) async -> DuoTeam? {
        if !hasPrivacyConsent {
            acknowledgePrivacy()
        }
        let joined = await joinTeam(accepting: invite)
        if joined != nil, let userId = boundUserId {
            try? await DuoTeamFirestoreService.deletePendingInvite(forUserId: userId, inviteId: invite.id)
            try? await DuoTeamFirestoreService.deleteJoinAccess(forUserId: userId, teamId: invite.teamId)
            receivedInvites.removeAll { $0.id == invite.id }
            await notifyInviteResponse(
                invite: invite,
                accepted: true,
                responderName: boundUserName
            )
        }
        return joined
    }

    func declineReceivedInvite(_ invite: DuoTeamInvite) async {
        guard let userId = boundUserId else { return }
        var updated = invite
        updated.status = .declined
        do {
            try await DuoTeamFirestoreService.saveInvite(updated)
            try await DuoTeamFirestoreService.deletePendingInvite(forUserId: userId, inviteId: invite.id)
            try? await DuoTeamFirestoreService.deleteJoinAccess(forUserId: userId, teamId: invite.teamId)
            receivedInvites.removeAll { $0.id == invite.id }
            await notifyInviteResponse(
                invite: updated,
                accepted: false,
                responderName: boundUserName
            )
        } catch {
            lastError = "Não foi possível recusar o convite."
        }
    }

    /// Quem convidou pode retirar um convite ainda pendente.
    @discardableResult
    func cancelSentInvite(_ invite: DuoTeamInvite) async -> Bool {
        guard invite.status == .pending, !invite.isExpired else {
            lastError = "Só é possível retirar convites pendentes."
            return false
        }
        guard boundUserId == invite.fromUid else {
            lastError = "Apenas quem enviou o convite pode retirá-lo."
            return false
        }

        var updated = invite
        updated.status = .cancelled
        do {
            try await DuoTeamFirestoreService.saveInvite(updated)
            if let toUid = invite.toUid, !toUid.isEmpty {
                try? await DuoTeamFirestoreService.deletePendingInvite(forUserId: toUid, inviteId: invite.id)
                try? await DuoTeamFirestoreService.deleteJoinAccess(forUserId: toUid, teamId: invite.teamId)
                let inbox = DuoInboxNotification(
                    id: UUID().uuidString,
                    kind: "inviteCancelled",
                    title: "Convite retirado",
                    body: "\(boundUserName) retirou o convite para “\(invite.teamName)”.",
                    teamId: invite.teamId,
                    teamName: invite.teamName,
                    fromUid: boundUserId ?? invite.fromUid,
                    fromName: boundUserName,
                    createdAt: .now,
                    delivered: false
                )
                try? await DuoTeamFirestoreService.saveInboxNotification(forUserId: toUid, notification: inbox)
            }
            if let idx = sentInvites.firstIndex(where: { $0.id == invite.id }) {
                var next = sentInvites
                next[idx] = updated
                sentInvites = next
            }
            // Remove da lista de recebidos se ainda estiver no aparelho do convidado (mesmo usuário raro).
            receivedInvites.removeAll { $0.id == invite.id }
            persistLocal()
            lastError = nil
            return true
        } catch {
            lastError = "Não foi possível retirar o convite."
            return false
        }
    }

    /// Avisa quem convidou sobre aceite/recusa.
    private func notifyInviteResponse(
        invite: DuoTeamInvite,
        accepted: Bool,
        responderName: String
    ) async {
        let name = responderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Alguém"
            : responderName
        let inbox = DuoInboxNotification(
            id: UUID().uuidString,
            kind: accepted ? "inviteAccepted" : "inviteDeclined",
            title: accepted ? "Convite aceito" : "Convite recusado",
            body: accepted
                ? "\(name) aceitou o convite para “\(invite.teamName)”."
                : "\(name) recusou o convite para “\(invite.teamName)”.",
            teamId: invite.teamId,
            teamName: invite.teamName,
            fromUid: boundUserId ?? "",
            fromName: name,
            createdAt: .now,
            delivered: false
        )
        try? await DuoTeamFirestoreService.saveInboxNotification(
            forUserId: invite.fromUid,
            notification: inbox
        )
    }

    /// Convites pendentes enviados para um UID nesta equipe.
    func pendingInvite(forUserId userId: String, teamId: String) -> DuoTeamInvite? {
        sentInvites.first {
            $0.teamId == teamId
                && $0.toUid == userId
                && $0.status == .pending
                && !$0.isExpired
        }
    }

    /// Só convites ainda aguardando resposta (sem histórico aceito/recusado/retirado).
    func pendingSentInvites(forTeamId teamId: String? = nil) -> [DuoTeamInvite] {
        sentInvites
            .filter {
                $0.status == .pending
                    && !$0.isExpired
                    && (teamId == nil || $0.teamId == teamId)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Convites pendentes enviados desta equipe.
    func sentInvites(forTeamId teamId: String) -> [DuoTeamInvite] {
        pendingSentInvites(forTeamId: teamId)
    }

    private func makeInvite(
        team: DuoTeam,
        toName: String,
        toPhoneE164: String,
        toEmail: String? = nil,
        toUid: String? = nil,
        notifyBody: String
    ) async -> (invite: DuoTeamInvite, copy: DuoInviteShareCopy)? {
        guard teams.contains(where: { $0.id == team.id }) else {
            lastError = "Você precisa estar na equipe para convidar."
            return nil
        }
        guard let userId = boundUserId else {
            lastError = "Faça login para convidar."
            return nil
        }

        let code = Self.makeInviteCode()
        let invite = DuoTeamInvite(
            id: UUID().uuidString,
            teamId: team.id,
            teamName: team.name,
            modality: team.modality,
            code: code,
            fromUid: userId,
            fromName: boundUserName,
            toName: toName,
            toPhoneE164: toPhoneE164,
            toEmail: toEmail,
            toUid: toUid,
            status: .pending,
            createdAt: .now,
            expiresAt: Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now.addingTimeInterval(86400 * 14)
        )

        sentInvites.insert(invite, at: 0)
        persistLocal()

        do {
            try await DuoTeamFirestoreService.saveInvite(invite)
        } catch {
            lastError = "Convite salvo no aparelho; falha ao enviar ao Firebase."
        }

        let body = notifyBody.contains("%@")
            ? String(format: notifyBody, code)
            : notifyBody
        NotificationService.shared.deliverDuoTeamNotification(
            title: "Convite criado",
            body: body
        )

        let copy = Self.motivationalInviteCopy(
            toName: toName,
            fromName: boundUserName,
            team: team,
            code: code
        )
        return (invite, copy)
    }

    static func motivationalInviteCopy(
        toName: String,
        fromName: String,
        team: DuoTeam,
        code: String
    ) -> DuoInviteShareCopy {
        let greetingName = toName.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = greetingName.isEmpty || greetingName == "Novo membro" ? "aí" : greetingName

        let body = """
        Oi, \(who)!

        \(fromName) te convidou para treinar em dupla/equipe no HealthFit — equipe “\(team.name)” (\(team.modalitiesLabel)).

        Treinar junto muda o jogo: vocês combinam horários no chat, se motivam de verdade e acompanham o desempenho no ranking da equipe.

        O HealthFit espera por você. Entre com o código \(code) e vamos nessa!

        Se já tiver o app: abra Dupla / equipe e use o código \(code).
        Se ainda não tiver: baixe o HealthFit e entre com o mesmo código.

        Lembrete: o chat é só para marcar atividades físicas (mensagens duram 12 horas). Por segurança, o HealthFit não usa localização em tempo real.

        Te esperamos no time — o app já está pronto quando você chegar!
        """

        return DuoInviteShareCopy(
            smsBody: body,
            emailSubject: "\(fromName) te espera no HealthFit — treino em dupla/equipe",
            emailBody: body,
            shareText: body
        )
    }

    // MARK: - Relatório / ranking

    func buildAndPublishReport(
        teamId: String,
        sessions: [WorkoutSession]
    ) async -> DuoTeamReport? {
        guard let team = teams.first(where: { $0.id == teamId }) else {
            lastError = "Equipe não encontrada."
            return nil
        }
        guard let userId = boundUserId else { return nil }

        // Só treinos desta equipe cuja modalidade está nas modalidades do grupo.
        let duoSessions = sessions.filter {
            $0.duoTeamId == teamId && team.allows(session: $0)
        }
        let myStats = Self.performance(
            uid: userId,
            displayName: boundUserName,
            sessions: duoSessions
        )
        do {
            try await DuoTeamFirestoreService.saveMemberPerformance(myStats, teamId: teamId)
        } catch {
            lastError = "Seu desempenho foi calculado; falha ao publicar no ranking."
        }

        var byUid: [String: DuoMemberPerformance] = [:]
        if let remote = try? await DuoTeamFirestoreService.fetchMemberPerformances(teamId: teamId) {
            for item in remote { byUid[item.uid] = item }
        }
        byUid[userId] = myStats

        for member in team.members {
            guard let uid = member.uid, byUid[uid] == nil else { continue }
            byUid[uid] = DuoMemberPerformance(
                uid: uid,
                displayName: member.name,
                sessionsLast7Days: 0,
                sessionsLast30Days: 0,
                minutesLast7Days: 0,
                minutesLast30Days: 0,
                caloriesLast7Days: 0,
                caloriesLast30Days: 0,
                lastWorkoutAt: nil,
                updatedAt: .now
            )
        }

        let sorted = byUid.values.sorted {
            if $0.rankingScore7d != $1.rankingScore7d {
                return $0.rankingScore7d > $1.rankingScore7d
            }
            if $0.sessionsLast7Days != $1.sessionsLast7Days {
                return $0.sessionsLast7Days > $1.sessionsLast7Days
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        let rows = sorted.enumerated().map { index, perf in
            DuoTeamRankingRow(rank: index + 1, performance: perf)
        }

        return DuoTeamReport(
            teamId: team.id,
            teamName: team.name,
            modality: team.modality,
            periodLabel: "Últimos 7 dias",
            rows: rows,
            teamSessions7d: sorted.reduce(0) { $0 + $1.sessionsLast7Days },
            teamMinutes7d: sorted.reduce(0) { $0 + $1.minutesLast7Days },
            teamCalories7d: sorted.reduce(0) { $0 + $1.caloriesLast7Days }
        )
    }

    private static func performance(
        uid: String,
        displayName: String,
        sessions: [WorkoutSession]
    ) -> DuoMemberPerformance {
        let now = Date()
        let day7 = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let day30 = now.addingTimeInterval(-30 * 24 * 60 * 60)
        let completed = sessions.filter { $0.endedAt != nil }

        func aggregate(since: Date) -> (count: Int, minutes: Int, calories: Int, last: Date?) {
            let slice = completed.filter { ($0.endedAt ?? $0.startedAt) >= since }
            let minutes = slice.reduce(0) { $0 + max(0, $1.activeDurationSeconds) / 60 }
            let calories = slice.reduce(0) { $0 + Int($1.caloriesBurned.rounded()) }
            let last = slice.map { $0.endedAt ?? $0.startedAt }.max()
            return (slice.count, minutes, calories, last)
        }

        let week = aggregate(since: day7)
        let month = aggregate(since: day30)
        return DuoMemberPerformance(
            uid: uid,
            displayName: displayName,
            sessionsLast7Days: week.count,
            sessionsLast30Days: month.count,
            minutesLast7Days: week.minutes,
            minutesLast30Days: month.minutes,
            caloriesLast7Days: week.calories,
            caloriesLast30Days: month.calories,
            lastWorkoutAt: week.last ?? month.last,
            updatedAt: now
        )
    }

    /// Sai da equipe. Se for o último membro, a equipe é encerrada.
    @discardableResult
    func leaveTeam(teamId: String) async -> Bool {
        guard let userId = boundUserId else {
            lastError = "Faça login para sair da equipe."
            return false
        }

        // Preferir estado fresco do banco para não sobrescrever membros com dados locais antigos.
        let resolvedTeam: DuoTeam?
        if let remote = try? await DuoTeamFirestoreService.fetchTeam(id: teamId) {
            resolvedTeam = remote
        } else {
            resolvedTeam = teams.first(where: { $0.id == teamId })
        }
        guard var team = resolvedTeam else {
            // Sem doc remoto: limpa só o local.
            teams.removeAll { $0.id == teamId }
            persistLocal()
            lastError = nil
            return true
        }

        guard team.members.contains(where: { $0.uid == userId }) else {
            try? await DuoTeamFirestoreService.removeMembership(userId: userId, teamId: teamId)
            teams.removeAll { $0.id == teamId }
            persistLocal()
            lastError = nil
            return true
        }

        stopListening(teamId: teamId)
        messagesByTeam[teamId] = nil

        let teamName = team.name
        let remainingAfterLeave = team.members.filter { $0.uid != userId }

        do {
            if remainingAfterLeave.isEmpty {
                // Capa do grupo: apagar no Storage ainda como membro (regra exige membership).
                try? await ProfilePhotoStorageService.deleteDuoTeamCover(teamId: teamId)
                // Último membro: apaga a equipe enquanto ainda consta em memberUids.
                try await DuoTeamFirestoreService.deleteTeam(id: teamId)
                try? await DuoTeamFirestoreService.removeMembership(userId: userId, teamId: teamId)
            } else {
                // Aviso no chat ainda como membro.
                let system = DuoChatMessage(
                    id: UUID().uuidString,
                    teamId: teamId,
                    senderUid: userId,
                    senderName: "HealthFit",
                    text: "\(boundUserName) saiu da equipe.",
                    kind: .system,
                    createdAt: .now,
                    proposedAt: nil
                )
                try? await DuoTeamFirestoreService.saveMessage(system)

                // Remove o membro inteiro (inclui foto de perfil e bandeira no grupo).
                team.members = remainingAfterLeave
                team.updatedAt = .now
                if team.createdByUid == userId, let nextOwner = remainingAfterLeave.compactMap(\.uid).first {
                    team.createdByUid = nextOwner
                    if let ownerName = remainingAfterLeave.first(where: { $0.uid == nextOwner })?.name {
                        team.createdByName = ownerName
                    }
                }

                // Só o doc da equipe (sem reescrever memberships alheios — isso bloqueava o leave).
                try await DuoTeamFirestoreService.updateTeamDocumentOnly(team)
                try await DuoTeamFirestoreService.removeMembership(userId: userId, teamId: teamId)
                try? await DuoTeamFirestoreService.deleteMemberPerformance(teamId: teamId, userId: userId)
            }
        } catch {
            lastError = "Não foi possível sair da equipe. Verifique a conexão e tente de novo."
            print("[HealthFit] Duo leaveTeam: \(error.localizedDescription)")
            return false
        }

        teams.removeAll { $0.id == teamId }
        sentInvites.removeAll { $0.teamId == teamId }
        persistLocal()
        lastError = nil
        NotificationService.shared.deliverDuoTeamNotification(
            title: "Você saiu da equipe",
            body: "“\(teamName)” não aparece mais na sua lista."
        )
        return true
    }

    func joinTeam(withCode rawCode: String) async -> DuoTeam? {
        guard hasPrivacyConsent else {
            lastError = "Confirme o aviso de privacidade antes de continuar."
            return nil
        }
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count >= 4 else {
            lastError = "Código inválido."
            return nil
        }

        do {
            guard let invite = try await DuoTeamFirestoreService.fetchInvite(code: code) else {
                lastError = "Convite não encontrado."
                return nil
            }
            return await completeJoin(invite: invite)
        } catch {
            lastError = Self.joinFailureMessage(error)
            print("[HealthFit] Duo join by code: \(error.localizedDescription)")
            return nil
        }
    }

    /// Aceita um convite já carregado (inbox / pendentes) sem depender só da query por código.
    func joinTeam(accepting invite: DuoTeamInvite) async -> DuoTeam? {
        guard hasPrivacyConsent else {
            lastError = "Confirme o aviso de privacidade antes de continuar."
            return nil
        }
        // Preferir versão fresca do Firestore; fallback para o convite local.
        let remote = try? await DuoTeamFirestoreService.fetchInvite(id: invite.id)
        let resolved = remote ?? invite
        return await completeJoin(invite: resolved)
    }

    private func completeJoin(invite: DuoTeamInvite) async -> DuoTeam? {
        guard let userId = boundUserId else {
            lastError = "Faça login para entrar na equipe."
            return nil
        }
        if invite.isExpired || invite.status != .pending {
            lastError = "Este convite não está mais disponível."
            return nil
        }

        do {
            guard var team = try await DuoTeamFirestoreService.fetchTeam(id: invite.teamId) else {
                lastError = "Equipe não encontrada. Peça um novo convite."
                return nil
            }
            if team.members.contains(where: { $0.uid == userId }) {
                if !teams.contains(where: { $0.id == team.id }) {
                    teams.insert(team, at: 0)
                    persistLocal()
                }
                try? await DuoTeamFirestoreService.deleteJoinAccess(forUserId: userId, teamId: team.id)
                try? await DuoTeamFirestoreService.deletePendingInvite(forUserId: userId, inviteId: invite.id)
                lastError = nil
                return team
            }

            team.members.append(
                makeSelfMember(uid: userId, phoneE164: invite.toPhoneE164)
            )
            team.updatedAt = .now
            var updatedInvite = invite
            updatedInvite.status = .accepted

            // 1) Vínculo próprio (regra permite create do próprio uid).
            try await DuoTeamFirestoreService.upsertOwnMembership(userId: userId, team: team)
            // 2) Atualiza equipe sem reescrever memberships de terceiros.
            try await DuoTeamFirestoreService.updateTeamDocumentOnly(team)
            // 3) Marca convite aceito (índice de código é best-effort).
            try await DuoTeamFirestoreService.saveInvite(updatedInvite)
            try? await DuoTeamFirestoreService.deleteJoinAccess(forUserId: userId, teamId: team.id)
            try? await DuoTeamFirestoreService.deletePendingInvite(forUserId: userId, inviteId: invite.id)

            if let idx = teams.firstIndex(where: { $0.id == team.id }) {
                teams[idx] = team
            } else {
                teams.insert(team, at: 0)
            }
            receivedInvites.removeAll { $0.id == invite.id }
            persistLocal()

            let system = DuoChatMessage(
                id: UUID().uuidString,
                teamId: team.id,
                senderUid: userId,
                senderName: "HealthFit",
                text: "\(boundUserName) entrou na equipe pelo convite.",
                kind: .system,
                createdAt: .now,
                proposedAt: nil
            )
            try? await DuoTeamFirestoreService.saveMessage(system)

            NotificationService.shared.deliverDuoTeamNotification(
                title: "Você entrou na equipe",
                body: "“\(team.name)” · \(team.modalitiesLabel). Combinem o treino no chat."
            )
            lastError = nil
            return team
        } catch {
            lastError = Self.joinFailureMessage(error)
            print("[HealthFit] Duo completeJoin: \(error.localizedDescription)")
            return nil
        }
    }

    private static func joinFailureMessage(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == "FIRFirestoreErrorDomain", ns.code == 7 {
            return "Não foi possível entrar nesta equipe agora. Atualize a lista e, se o convite expirou, peça um novo."
        }
        if ns.localizedDescription.localizedCaseInsensitiveContains("permission") {
            return "Não foi possível entrar nesta equipe agora. Atualize a lista e, se o convite expirou, peça um novo."
        }
        return "Falha ao entrar na equipe. Verifique a conexão e tente de novo."
    }

    // MARK: - Chat

    func startListening(teamId: String) {
        if listeners[teamId] != nil { return }
        listeners[teamId] = DuoTeamFirestoreService.listenMessages(teamId: teamId) { [weak self] messages in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.applyRemoteMessages(messages, teamId: teamId)
                // Purge fora do caminho crítico da UI.
                Task { await self.purgeExpiredMessages(teamId: teamId, from: messages) }
            }
        }
    }

    /// Reinicia o listener (útil ao voltar para a tela do chat).
    func restartListening(teamId: String) {
        stopListening(teamId: teamId)
        startListening(teamId: teamId)
    }

    func stopListening(teamId: String) {
        listeners[teamId]?.remove()
        listeners[teamId] = nil
    }

    func loadMessages(teamId: String) async {
        do {
            let messages = try await DuoTeamFirestoreService.fetchMessages(teamId: teamId)
            applyRemoteMessages(messages, teamId: teamId)
            Task { await purgeExpiredMessages(teamId: teamId, from: messages) }
        } catch {
            lastError = "Não foi possível carregar o chat."
        }
    }

    /// Aplica mensagens do Firebase sem apagar otimistas locais ainda não confirmadas.
    private func applyRemoteMessages(_ remote: [DuoChatMessage], teamId: String) {
        let remoteFiltered = Self.filterActiveMessages(remote)
        let remoteIds = Set(remoteFiltered.map(\.id))
        let pendingLocal = (messagesByTeam[teamId] ?? []).filter { message in
            guard !remoteIds.contains(message.id), !message.isExpired else { return false }
            // Mantém só envios recentes (ainda sincronizando).
            return Date().timeIntervalSince(message.createdAt) < 90
        }
        setMessages(Self.filterActiveMessages(remoteFiltered + pendingLocal), for: teamId)
    }

    /// Reatribui o dicionário para o `@Published` disparar a UI de imediato.
    private func setMessages(_ messages: [DuoChatMessage], for teamId: String) {
        var next = messagesByTeam
        next[teamId] = messages
        messagesByTeam = next
    }

    func sendText(teamId: String, text: String) async {
        guard let userId = boundUserId else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let message = DuoChatMessage(
            id: UUID().uuidString,
            teamId: teamId,
            senderUid: userId,
            senderName: boundUserName,
            text: trimmed,
            kind: .text,
            createdAt: .now,
            proposedAt: nil
        )
        appendLocal(message)
        do {
            try await DuoTeamFirestoreService.saveMessage(message)
            await notifyTeamMembersOfChatMessage(message)
        } catch {
            lastError = "Mensagem não sincronizou com o Firebase."
        }
    }

    func sendScheduleProposal(teamId: String, when: Date, note: String) async {
        guard let userId = boundUserId else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let whenText = formatter.string(from: when)
        let extra = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = extra.isEmpty
            ? "Proposta de treino: \(whenText)"
            : "Proposta de treino: \(whenText) — \(extra)"

        let message = DuoChatMessage(
            id: UUID().uuidString,
            teamId: teamId,
            senderUid: userId,
            senderName: boundUserName,
            text: body,
            kind: .scheduleProposal,
            createdAt: .now,
            proposedAt: when
        )
        appendLocal(message)
        do {
            try await DuoTeamFirestoreService.saveMessage(message)
            await notifyTeamMembersOfChatMessage(message)
        } catch {
            lastError = "Proposta salva localmente; falha no Firebase."
        }
    }

    /// Avisa os outros membros (inbox + notificação local no aparelho deles).
    private func notifyTeamMembersOfChatMessage(_ message: DuoChatMessage) async {
        guard message.kind != .system else { return }
        let team: DuoTeam?
        if let local = teams.first(where: { $0.id == message.teamId }) {
            team = local
        } else {
            team = try? await DuoTeamFirestoreService.fetchTeam(id: message.teamId)
        }
        guard let team else { return }

        let preview: String
        if message.kind == .scheduleProposal {
            preview = message.text
        } else {
            let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            preview = trimmed.count > 120 ? String(trimmed.prefix(117)) + "…" : trimmed
        }

        let title = message.kind == .scheduleProposal
            ? "Proposta de treino · \(team.name)"
            : "Nova mensagem · \(team.name)"

        for member in team.members {
            guard let uid = member.uid, uid != message.senderUid else { continue }
            let inbox = DuoInboxNotification(
                id: UUID().uuidString,
                kind: message.kind == .scheduleProposal ? "duoChatSchedule" : "duoChatMessage",
                title: title,
                body: "\(message.senderName): \(preview)",
                teamId: team.id,
                teamName: team.name,
                fromUid: message.senderUid,
                fromName: message.senderName,
                createdAt: .now,
                delivered: false
            )
            try? await DuoTeamFirestoreService.saveInboxNotification(forUserId: uid, notification: inbox)
        }
    }

    func scheduledMessages(for teamId: String) -> [DuoChatMessage] {
        (messagesByTeam[teamId] ?? [])
            .filter { $0.isSchedule && !$0.isExpired }
            .sorted { ($0.proposedAt ?? $0.createdAt) < ($1.proposedAt ?? $1.createdAt) }
    }

    // MARK: - Helpers

    static func normalizedPhone(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        if digits.hasPrefix("55"), digits.count >= 12 { return digits }
        if digits.count >= 10, digits.count <= 11 { return "55" + digits }
        return digits
    }

    static func makeInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }

    private func makeSelfMember(uid: String, phoneE164: String? = nil) -> DuoTeamMember {
        DuoTeamMember(
            uid: uid,
            name: boundUserName,
            phoneE164: phoneE164,
            countryCode: boundCountryCode,
            photoURL: boundPhotoURL
        )
    }

    /// Atualiza foto/bandeira do usuário atual em todas as equipes e republica no Firebase.
    func refreshMyMemberProfileAcrossTeams(
        photoURL: String? = nil,
        countryCode: String? = nil
    ) async {
        if let photoURL {
            boundPhotoURL = photoURL.isEmpty ? nil : photoURL
        }
        if let countryCode {
            let trimmed = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            boundCountryCode = trimmed.isEmpty ? nil : trimmed
        }
        guard let userId = boundUserId else { return }

        for index in teams.indices {
            guard let memberIndex = teams[index].members.firstIndex(where: { $0.uid == userId }) else {
                continue
            }
            teams[index].members[memberIndex].name = boundUserName
            if let boundCountryCode {
                teams[index].members[memberIndex].countryCode = boundCountryCode
            }
            if photoURL != nil {
                // Atualização explícita (inclui limpar com "").
                teams[index].members[memberIndex].photoURL = boundPhotoURL
            } else if let boundPhotoURL {
                teams[index].members[memberIndex].photoURL = boundPhotoURL
            }
            teams[index].updatedAt = .now
            try? await DuoTeamFirestoreService.saveTeam(teams[index])
        }
        persistLocal()
    }

    /// Busca foto e bandeira dos membros no diretório/perfil e atualiza a equipe.
    func enrichMembersFromDirectory(teamId: String) async {
        // Membros do Firestore são a fonte da verdade — evita reintroduzir quem saiu (e a foto).
        if let remote = try? await DuoTeamFirestoreService.fetchTeam(id: teamId),
           let syncIndex = teams.firstIndex(where: { $0.id == teamId }) {
            var synced = teams[syncIndex]
            let localUids = Set(synced.members.compactMap(\.uid))
            let remoteUids = Set(remote.members.compactMap(\.uid))
            if localUids != remoteUids || synced.members.count != remote.members.count {
                synced.members = remote.members
                synced.updatedAt = max(synced.updatedAt, remote.updatedAt)
                synced.photoURL = remote.photoURL
                teams[syncIndex] = synced
                persistLocal()
            }
        }

        guard let teamIndex = teams.firstIndex(where: { $0.id == teamId }) else { return }
        var team = teams[teamIndex]
        var changed = false
        for i in team.members.indices {
            guard let uid = team.members[i].uid,
                  let entry = try? await ProfileFirestoreService.fetchMemberPublicProfile(userId: uid) else {
                continue
            }
            if !entry.shownName.isEmpty, team.members[i].name != entry.shownName {
                team.members[i].name = entry.shownName
                changed = true
            }
            if let code = entry.countryCode, !code.isEmpty,
               team.members[i].countryCode?.uppercased() != code.uppercased() {
                team.members[i].countryCode = code.uppercased()
                changed = true
            }
            if let photo = entry.photoURL, !photo.isEmpty, team.members[i].photoURL != photo {
                team.members[i].photoURL = photo
                changed = true
            }
        }
        if changed {
            team.updatedAt = .now
            teams[teamIndex] = team
            persistLocal()
            // Só o doc da equipe — não reescrever memberships (pode falhar / reintroduzir vínculos).
            try? await DuoTeamFirestoreService.updateTeamDocumentOnly(team)
        }
    }

    private func appendLocal(_ message: DuoChatMessage) {
        var list = messagesByTeam[message.teamId] ?? []
        if !list.contains(where: { $0.id == message.id }) {
            list.append(message)
        }
        setMessages(Self.filterActiveMessages(list), for: message.teamId)
        if let idx = teams.firstIndex(where: { $0.id == message.teamId }) {
            teams[idx].updatedAt = .now
            persistLocal()
        }
    }

    private static func filterActiveMessages(_ messages: [DuoChatMessage]) -> [DuoChatMessage] {
        messages.filter { !$0.isExpired }.sorted { $0.createdAt < $1.createdAt }
    }

    private func purgeExpiredMessages(teamId: String, from messages: [DuoChatMessage]) async {
        let expiredIds = messages.filter(\.isExpired).map(\.id)
        guard !expiredIds.isEmpty else { return }
        try? await DuoTeamFirestoreService.deleteMessages(teamId: teamId, messageIds: expiredIds)
    }

    private func tearDownListeners() {
        for (_, reg) in listeners { reg.remove() }
        listeners.removeAll()
        pauseInboxListener()
        deliveringInboxIds.removeAll()
    }

    /// Em background: mantém a inbox ativa para avisos de chat/convite; o chat listener de mensagens já é por tela.
    func handleAppEnteredBackground() {
        // Inbox permanece — notifica mensagens de chat e respostas de convite.
    }

    /// Ao voltar: busca pendências e garante o listener.
    func handleAppBecameActive() {
        guard let userId = boundUserId else { return }
        Task {
            await deliverInboxNotificationsIfNeeded(userId: userId)
            startInboxListenerIfNeeded(userId: userId)
        }
    }

    private func pauseInboxListener() {
        inboxListener?.remove()
        inboxListener = nil
    }

    private func startInboxListenerIfNeeded(userId: String) {
        guard inboxListener == nil else { return }
        inboxListener = DuoTeamFirestoreService.listenInboxNotifications(userId: userId) { [weak self] notes in
            Task { @MainActor [weak self] in
                await self?.deliverInboxNotifications(notes, userId: userId)
            }
        }
    }

    private func deliverInboxNotificationsIfNeeded(userId: String) async {
        do {
            let notes = try await DuoTeamFirestoreService.fetchUndeliveredNotifications(forUserId: userId)
            await deliverInboxNotifications(notes, userId: userId)
        } catch {
            print("[HealthFit] Duo inbox fetch: \(error.localizedDescription)")
        }
    }

    private func deliverInboxNotifications(_ notes: [DuoInboxNotification], userId: String) async {
        for note in notes where !note.delivered {
            guard !deliveringInboxIds.contains(note.id) else { continue }
            deliveringInboxIds.insert(note.id)
            NotificationService.shared.deliverDuoTeamNotification(
                title: note.title,
                body: note.body,
                teamId: note.teamId,
                teamName: note.teamName,
                kind: note.kind
            )
            do {
                try await DuoTeamFirestoreService.markNotificationDelivered(forUserId: userId, id: note.id)
            } catch {
                print("[HealthFit] Duo inbox mark delivered: \(error.localizedDescription)")
            }
            // Se a pessoa foi adicionada, recarrega equipes para aparecer na lista.
            if note.kind == "addedToTeam" {
                do {
                    let remoteTeams = try await DuoTeamFirestoreService.fetchTeams(forUserId: userId)
                    teams = await mergeTeamsPreferringCloud(local: teams, remote: remoteTeams)
                    persistLocal()
                } catch {
                    print("[HealthFit] Duo reload after add: \(error.localizedDescription)")
                }
            }
            // Nova mensagem de chat: atualiza a conversa na hora (mesmo se o snapshot atrasar).
            if note.kind == "duoChatMessage" || note.kind == "duoChatSchedule" {
                await loadMessages(teamId: note.teamId)
                if listeners[note.teamId] == nil {
                    startListening(teamId: note.teamId)
                }
            }
            // Atualiza status dos convites enviados (aceito / recusado).
            if note.kind == "inviteAccepted" || note.kind == "inviteDeclined" {
                do {
                    let remoteInvites = try await DuoTeamFirestoreService.fetchInvitesSent(byUserId: userId)
                    if !remoteInvites.isEmpty {
                        sentInvites = remoteInvites
                        persistLocal()
                    } else if let idx = sentInvites.firstIndex(where: {
                        $0.teamId == note.teamId
                            && ($0.toUid == note.fromUid || $0.toName.caseInsensitiveCompare(note.fromName) == .orderedSame)
                            && $0.status == .pending
                    }) {
                        sentInvites[idx].status = note.kind == "inviteAccepted" ? .accepted : .declined
                        persistLocal()
                    }
                } catch {
                    print("[HealthFit] Duo reload invites after response: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Convites pendentes (SMS/código) também geram aviso local uma vez.
    private func notifyNewPendingInvitesIfNeeded(_ invites: [DuoTeamInvite], userId: String) {
        var notified = loadNotifiedPendingInviteIds(userId: userId)
        var changed = false
        for invite in invites {
            guard !notified.contains(invite.id) else { continue }
            NotificationService.shared.deliverDuoTeamNotification(
                title: "Convite para um grupo",
                body: "\(invite.fromName) convidou você para “\(invite.teamName)”. Abra Dupla / equipe para aceitar.",
                teamId: invite.teamId,
                teamName: invite.teamName,
                kind: "invitePending"
            )
            notified.insert(invite.id)
            changed = true
        }
        if changed {
            saveNotifiedPendingInviteIds(notified, userId: userId)
        }
    }

    private func loadNotifiedPendingInviteIds(userId: String) -> Set<String> {
        guard let data = UserScopedDefaults.data(
            forLogicalKey: ScopedKey.notifiedPendingInvites,
            uid: userId,
            legacyKey: nil
        ),
        let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(decoded)
    }

    private func saveNotifiedPendingInviteIds(_ ids: Set<String>, userId: String) {
        guard let data = try? JSONEncoder().encode(Array(ids)) else { return }
        UserScopedDefaults.setData(
            data,
            forLogicalKey: ScopedKey.notifiedPendingInvites,
            uid: userId,
            legacyKey: nil
        )
    }

    /// Junta equipes locais e do Firestore; sobe para o banco só o que ainda faz sentido.
    private func mergeTeamsPreferringCloud(local: [DuoTeam], remote: [DuoTeam]) async -> [DuoTeam] {
        var byId: [String: DuoTeam] = [:]
        for team in remote {
            byId[team.id] = team
        }

        let userId = boundUserId
        for localTeam in local {
            if let remoteTeam = byId[localTeam.id] {
                if localTeam.updatedAt > remoteTeam.updatedAt {
                    // Local mais novo, mas a lista de membros do remoto manda (quem saiu não volta com a foto).
                    var toPush = localTeam
                    toPush.members = Self.mergeMemberProfiles(remote: remoteTeam.members, local: localTeam.members)
                    do {
                        try await DuoTeamFirestoreService.saveTeam(toPush)
                        byId[localTeam.id] = toPush
                    } catch {
                        print("[HealthFit] Duo merge push newer local \(localTeam.id): \(error.localizedDescription)")
                        byId[localTeam.id] = remoteTeam
                    }
                }
                continue
            }

            // Só no aparelho (sem membership remoto).
            let stillMember = userId.map { uid in localTeam.members.contains(where: { $0.uid == uid }) } ?? false
            guard stillMember else {
                // Fantasma local (saiu / removido) — não reenvia nem mantém na lista.
                print("[HealthFit] Duo drop stale local team \(localTeam.id)")
                continue
            }

            do {
                try await DuoTeamFirestoreService.saveTeam(localTeam)
                byId[localTeam.id] = localTeam
            } catch {
                // Permissão/rede: não assusta a UI; tenta de novo na próxima sync.
                print("[HealthFit] Duo merge upload \(localTeam.id): \(error.localizedDescription)")
                if !Self.isPermissionDenied(error) {
                    byId[localTeam.id] = localTeam
                }
            }
        }
        return byId.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Mantém só quem ainda está no remoto; atualiza nome/foto/bandeira a partir do local quando houver.
    private static func mergeMemberProfiles(
        remote: [DuoTeamMember],
        local: [DuoTeamMember]
    ) -> [DuoTeamMember] {
        let localByUid = Dictionary(
            uniqueKeysWithValues: local.compactMap { member -> (String, DuoTeamMember)? in
                guard let uid = member.uid else { return nil }
                return (uid, member)
            }
        )
        return remote.map { remoteMember in
            guard let uid = remoteMember.uid, let localMember = localByUid[uid] else {
                return remoteMember
            }
            var merged = remoteMember
            if !localMember.name.isEmpty {
                merged.name = localMember.name
            }
            if let photo = localMember.photoURL, !photo.isEmpty {
                merged.photoURL = photo
            }
            if let country = localMember.countryCode, !country.isEmpty {
                merged.countryCode = country.uppercased()
            }
            return merged
        }
    }

    private static func isPermissionDenied(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == "FIRFirestoreErrorDomain", ns.code == 7 { return true }
        return ns.localizedDescription.localizedCaseInsensitiveContains("permission")
    }

    private func loadLocal() {
        guard let uid = boundUserId else { return }
        if let data = UserScopedDefaults.data(forLogicalKey: ScopedKey.teams, uid: uid, legacyKey: nil),
           let decoded = try? JSONDecoder().decode([DuoTeam].self, from: data) {
            teams = decoded
        } else {
            teams = []
        }
        if let data = UserScopedDefaults.data(forLogicalKey: ScopedKey.invites, uid: uid, legacyKey: nil),
           let decoded = try? JSONDecoder().decode([DuoTeamInvite].self, from: data) {
            sentInvites = decoded
        } else {
            sentInvites = []
        }
    }

    private func persistLocal() {
        guard let uid = boundUserId else { return }
        if let data = try? JSONEncoder().encode(teams) {
            UserScopedDefaults.setData(data, forLogicalKey: ScopedKey.teams, uid: uid, legacyKey: nil)
        }
        if let data = try? JSONEncoder().encode(sentInvites) {
            UserScopedDefaults.setData(data, forLogicalKey: ScopedKey.invites, uid: uid, legacyKey: nil)
        }
    }
}
