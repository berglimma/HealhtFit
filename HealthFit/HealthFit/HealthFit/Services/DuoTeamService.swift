import Combine
import Foundation
import FirebaseFirestore

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

    private enum ScopedKey {
        static let teams = "duo_teams"
        static let invites = "duo_invites"
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
        do {
            if let entry = try? await ProfileFirestoreService.fetchMemberPublicProfile(userId: userId) {
                if !entry.shownName.isEmpty { boundUserName = entry.shownName }
                // Não apagar país/foto locais se o diretório ainda estiver incompleto.
                if let code = entry.countryCode, !code.isEmpty {
                    boundCountryCode = code
                }
                if let photo = entry.photoURL, !photo.isEmpty {
                    boundPhotoURL = photo
                }
            }
            let localTeams = teams
            let remoteTeams = try await DuoTeamFirestoreService.fetchTeams(forUserId: userId)
            teams = await mergeTeamsPreferringCloud(local: localTeams, remote: remoteTeams)
            let remoteInvites = try await DuoTeamFirestoreService.fetchInvitesSent(byUserId: userId)
            if !remoteInvites.isEmpty {
                sentInvites = remoteInvites
            }
            receivedInvites = try await DuoTeamFirestoreService.fetchPendingInvites(forUserId: userId)
                .filter { !$0.isExpired && $0.status == .pending }
            await refreshMyMemberProfileAcrossTeams()
            persistLocal()
        } catch {
            lastError = "Não foi possível sincronizar as equipes com o banco."
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
        do {
            return try await ProfileFirestoreService.searchUsers(
                query: query,
                excludingUserId: boundUserId
            )
        } catch {
            lastError = "Não foi possível buscar usuários."
            return []
        }
    }

    // MARK: - Create / invite / join

    func createTeam(name: String, modality: DuoTeamModality) async -> DuoTeam? {
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

        let team = DuoTeam(
            id: UUID().uuidString,
            name: trimmed,
            modality: modality,
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
                text: "Equipe criada. O chat é só para marcar atividades físicas; mensagens expiram em 24h. Sem localização em tempo real.",
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

    /// Convida alguém já cadastrado no HealthFit (busca por nome / como quer ser chamado).
    @discardableResult
    func inviteAppUser(team: DuoTeam, user: UserDirectoryEntry) async -> Bool {
        if team.members.contains(where: { $0.uid == user.uid }) {
            lastError = "Essa pessoa já está na equipe."
            return false
        }
        if sentInvites.contains(where: {
            $0.teamId == team.id && $0.toUid == user.uid && $0.status == .pending && !$0.isExpired
        }) {
            lastError = "Já existe um convite pendente para essa pessoa."
            return false
        }
        guard let result = await makeInvite(
            team: team,
            toName: user.shownName,
            toPhoneE164: "",
            toEmail: nil,
            toUid: user.uid,
            notifyBody: "Convite enviado para \(user.shownName). O HealthFit espera pela resposta."
        ) else { return false }

        do {
            try await DuoTeamFirestoreService.savePendingInvite(forUserId: user.uid, invite: result.invite)
        } catch {
            lastError = "Convite criado, mas a pessoa pode precisar do código \(result.invite.code)."
        }
        NotificationService.shared.deliverDuoTeamNotification(
            title: "Convite no HealthFit",
            body: "\(user.shownName) recebeu o convite para “\(team.name)”. Também pode usar o código \(result.invite.code)."
        )
        return true
    }

    @discardableResult
    func acceptReceivedInvite(_ invite: DuoTeamInvite) async -> DuoTeam? {
        let joined = await joinTeam(withCode: invite.code)
        if joined != nil, let userId = boundUserId {
            try? await DuoTeamFirestoreService.deletePendingInvite(forUserId: userId, inviteId: invite.id)
            receivedInvites.removeAll { $0.id == invite.id }
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
            receivedInvites.removeAll { $0.id == invite.id }
        } catch {
            lastError = "Não foi possível recusar o convite."
        }
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

        \(fromName) te convidou para treinar em dupla/equipe no HealthFit — equipe “\(team.name)” (\(team.modality.rawValue)).

        Treinar junto muda o jogo: vocês combinam horários no chat, se motivam de verdade e acompanham o desempenho no ranking da equipe.

        O HealthFit espera por você. Entre com o código \(code) e vamos nessa!

        Se já tiver o app: abra Dupla / equipe e use o código \(code).
        Se ainda não tiver: baixe o HealthFit e entre com o mesmo código.

        Lembrete: o chat é só para marcar atividades físicas (mensagens duram 24 horas). Por segurança, o HealthFit não usa localização em tempo real.

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

        // Só treinos iniciados em dupla/equipe desta equipe — individuais ficam de fora.
        let duoSessions = sessions.filter { $0.duoTeamId == teamId }
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
        let resolvedTeam: DuoTeam?
        if let local = teams.first(where: { $0.id == teamId }) {
            resolvedTeam = local
        } else {
            resolvedTeam = try? await DuoTeamFirestoreService.fetchTeam(id: teamId)
        }
        guard var team = resolvedTeam else {
            lastError = "Equipe não encontrada."
            return false
        }
        guard team.members.contains(where: { $0.uid == userId }) else {
            teams.removeAll { $0.id == teamId }
            persistLocal()
            return true
        }

        stopListening(teamId: teamId)
        messagesByTeam[teamId] = nil
        team.members.removeAll { $0.uid == userId }
        team.updatedAt = .now

        do {
            try await DuoTeamFirestoreService.removeMembership(userId: userId, teamId: teamId)

            if team.members.isEmpty {
                try await DuoTeamFirestoreService.deleteTeam(id: teamId)
            } else {
                if team.createdByUid == userId, let nextOwner = team.members.compactMap(\.uid).first {
                    team.createdByUid = nextOwner
                    if let ownerName = team.members.first(where: { $0.uid == nextOwner })?.name {
                        team.createdByName = ownerName
                    }
                }
                try await DuoTeamFirestoreService.saveTeam(team)
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
            }
        } catch {
            lastError = "Não foi possível sair da equipe. Tente de novo."
            return false
        }

        teams.removeAll { $0.id == teamId }
        sentInvites.removeAll { $0.teamId == teamId }
        persistLocal()
        NotificationService.shared.deliverDuoTeamNotification(
            title: "Você saiu da equipe",
            body: "“\(team.name)” não aparece mais na sua lista."
        )
        return true
    }

    func joinTeam(withCode rawCode: String) async -> DuoTeam? {
        guard hasPrivacyConsent else {
            lastError = "Confirme o aviso de privacidade antes de continuar."
            return nil
        }
        guard let userId = boundUserId else {
            lastError = "Faça login para entrar na equipe."
            return nil
        }
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count >= 4 else {
            lastError = "Código inválido."
            return nil
        }

        do {
            guard var invite = try await DuoTeamFirestoreService.fetchInvite(code: code) else {
                lastError = "Convite não encontrado."
                return nil
            }
            if invite.isExpired || invite.status != .pending {
                lastError = "Este convite não está mais disponível."
                return nil
            }
            guard var team = try await DuoTeamFirestoreService.fetchTeam(id: invite.teamId) else {
                lastError = "Equipe não encontrada."
                return nil
            }
            if team.members.contains(where: { $0.uid == userId }) {
                if !teams.contains(where: { $0.id == team.id }) {
                    teams.insert(team, at: 0)
                    persistLocal()
                }
                return team
            }

            team.members.append(
                makeSelfMember(uid: userId, phoneE164: invite.toPhoneE164)
            )
            team.updatedAt = .now
            invite.status = .accepted

            try await DuoTeamFirestoreService.saveTeam(team)
            try await DuoTeamFirestoreService.saveInvite(invite)

            if let idx = teams.firstIndex(where: { $0.id == team.id }) {
                teams[idx] = team
            } else {
                teams.insert(team, at: 0)
            }
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
            try await DuoTeamFirestoreService.saveMessage(system)

            NotificationService.shared.deliverDuoTeamNotification(
                title: "Você entrou na equipe",
                body: "“\(team.name)” · \(team.modality.rawValue). Combinem o treino no chat."
            )
            return team
        } catch {
            lastError = "Falha ao entrar na equipe. Verifique a conexão."
            return nil
        }
    }

    // MARK: - Chat

    func startListening(teamId: String) {
        guard listeners[teamId] == nil else { return }
        listeners[teamId] = DuoTeamFirestoreService.listenMessages(teamId: teamId) { [weak self] messages in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.messagesByTeam[teamId] = Self.filterActiveMessages(messages)
                await self.purgeExpiredMessages(teamId: teamId, from: messages)
            }
        }
    }

    func stopListening(teamId: String) {
        listeners[teamId]?.remove()
        listeners[teamId] = nil
    }

    func loadMessages(teamId: String) async {
        do {
            let messages = try await DuoTeamFirestoreService.fetchMessages(teamId: teamId)
            messagesByTeam[teamId] = Self.filterActiveMessages(messages)
            await purgeExpiredMessages(teamId: teamId, from: messages)
        } catch {
            lastError = "Não foi possível carregar o chat."
        }
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
            NotificationService.shared.deliverDuoTeamNotification(
                title: "Treino marcado na equipe",
                body: body
            )
        } catch {
            lastError = "Proposta salva localmente; falha no Firebase."
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
            try? await DuoTeamFirestoreService.saveTeam(team)
        }
    }

    private func appendLocal(_ message: DuoChatMessage) {
        var list = messagesByTeam[message.teamId] ?? []
        list.append(message)
        messagesByTeam[message.teamId] = Self.filterActiveMessages(list)
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
    }

    /// Junta equipes locais e do Firestore; sobe para o banco as que só existem no aparelho.
    private func mergeTeamsPreferringCloud(local: [DuoTeam], remote: [DuoTeam]) async -> [DuoTeam] {
        var byId: [String: DuoTeam] = [:]
        for team in remote {
            byId[team.id] = team
        }
        for localTeam in local {
            if let remoteTeam = byId[localTeam.id] {
                if localTeam.updatedAt > remoteTeam.updatedAt {
                    byId[localTeam.id] = localTeam
                    try? await DuoTeamFirestoreService.saveTeam(localTeam)
                }
            } else {
                // Equipe só no aparelho → grava no banco.
                do {
                    try await DuoTeamFirestoreService.saveTeam(localTeam)
                    byId[localTeam.id] = localTeam
                } catch {
                    byId[localTeam.id] = localTeam
                    lastError = "Algumas equipes ainda não sincronizaram com o banco."
                }
            }
        }
        return byId.values.sorted { $0.updatedAt > $1.updatedAt }
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
