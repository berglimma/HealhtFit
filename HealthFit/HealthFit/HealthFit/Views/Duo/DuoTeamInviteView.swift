import MessageUI
import SwiftUI

struct DuoTeamInviteView: View {
    let team: DuoTeam
    @ObservedObject private var duoService = DuoTeamService.shared
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var searchResults: [UserDirectoryEntry] = []
    @State private var isSearching = false
    @State private var invitingUid: String?
    @State private var searchError: String?

    @State private var partnerName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var isWorking = false

    @State private var inviteCopy: DuoInviteShareCopy?
    @State private var smsRecipients: [String] = []
    @State private var emailRecipients: [String] = []
    @State private var showSMS = false
    @State private var showMail = false
    @State private var showSMSUnavailable = false
    @State private var showMailUnavailable = false
    @State private var statusMessage: String?
    @State private var showShare = false
    @State private var generatedCode: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Busque no app e envie o convite. A pessoa precisa aceitar ou recusar. Você acompanha o status (pendente, aceito ou recusado). Também dá para SMS, e-mail ou código. Sem localização em tempo real.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Buscar no HealthFit") {
                    HStack {
                        TextField("Nome, apelido ou e-mail", text: $searchQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit { Task { await runSearch() } }
                        if isSearching {
                            ProgressView()
                        } else {
                            Button {
                                Task { await runSearch() }
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            .disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                        }
                    }

                    if let searchError {
                        Text(searchError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                        Text("Digite pelo menos 2 letras do nome, apelido ou e-mail.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !isSearching && searchResults.isEmpty && !searchQuery.isEmpty {
                        Text("Ninguém encontrado. A pessoa precisa ter aberto o app pelo menos uma vez (com esta versão) para aparecer na busca. Enquanto isso, use SMS, e-mail ou código.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(searchResults) { user in
                        let isMember = team.members.contains(where: { $0.uid == user.uid })
                        let pending = duoService.pendingInvite(forUserId: user.uid, teamId: team.id)
                        Button {
                            Task { await inviteUser(user) }
                        } label: {
                            HStack(spacing: 12) {
                                DuoMemberAvatarView(
                                    name: user.shownName,
                                    photoURL: user.photoURL,
                                    countryCode: user.countryCode,
                                    size: 48
                                )
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(user.shownName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        if user.flagEmoji != "🏳️" {
                                            Text(user.flagEmoji)
                                                .font(.subheadline)
                                        }
                                    }
                                    Text(user.detailLine)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                if invitingUid == user.uid {
                                    ProgressView()
                                } else if isMember {
                                    Text("Na equipe")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else if pending != nil {
                                    Text("Pendente")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                } else {
                                    Image(systemName: "person.badge.plus")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                        .disabled(invitingUid != nil || isMember || pending != nil)
                    }
                }

                teamInvitesStatusSection

                Section("Convidar por SMS") {
                    TextField("Nome", text: $partnerName)
                    TextField("Telefone com DDD", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    Button {
                        Task { await createAndSendSMS() }
                    } label: {
                        Label(
                            isWorking ? "Criando…" : "Criar e enviar SMS",
                            systemImage: "message.fill"
                        )
                    }
                    .disabled(isWorking)
                }

                Section("Convidar por e-mail") {
                    TextField("Nome", text: $partnerName)
                    TextField("E-mail", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await createAndSendEmail() }
                    } label: {
                        Label(
                            isWorking ? "Criando…" : "Criar e enviar e-mail",
                            systemImage: "envelope.fill"
                        )
                    }
                    .disabled(isWorking)
                }

                Section("Ou gerar código para compartilhar") {
                    if let generatedCode {
                        Text(generatedCode)
                            .font(.title2.monospaced().weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }
                    Button {
                        Task { await createShareable() }
                    } label: {
                        Label(
                            generatedCode == nil ? "Gerar código" : "Gerar outro código",
                            systemImage: "link.badge.plus"
                        )
                    }
                    .disabled(isWorking)

                    if inviteCopy != nil {
                        Button {
                            showShare = true
                        } label: {
                            Label("Compartilhar convite", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            if let generatedCode {
                                UIPasteboard.general.string = generatedCode
                                statusMessage = "Código \(generatedCode) copiado."
                            }
                        } label: {
                            Label("Copiar código", systemImage: "doc.on.doc")
                        }
                    }
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .navigationTitle("Adicionar pessoas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .task {
                await duoService.ensureDirectorySynced(profile: authService.currentUser)
            }
            .onChange(of: searchQuery) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count >= 2 else {
                    searchResults = []
                    return
                }
                Task {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
                    await runSearch()
                }
            }
            .sheet(isPresented: $showSMS) {
                if let inviteCopy {
                    MessageComposeView(
                        recipients: smsRecipients,
                        body: inviteCopy.smsBody,
                        onFinish: { result in
                            showSMS = false
                            switch result {
                            case .sent:
                                statusMessage = "SMS enviado. O HealthFit espera por eles no time."
                            case .cancelled:
                                statusMessage = "SMS cancelado. O convite motivador já foi criado — compartilhe por e-mail ou código."
                            case .failed:
                                statusMessage = "Falha ao enviar SMS. Tente e-mail ou compartilhar o código."
                            @unknown default:
                                break
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showMail) {
                if let inviteCopy {
                    MailComposeView(
                        recipients: emailRecipients,
                        subject: inviteCopy.emailSubject,
                        body: inviteCopy.emailBody,
                        onFinish: { result in
                            showMail = false
                            switch result {
                            case .sent:
                                statusMessage = "E-mail enviado. O HealthFit espera por eles no time."
                            case .cancelled:
                                statusMessage = "E-mail cancelado. Você ainda pode enviar SMS ou compartilhar o código."
                            case .failed:
                                statusMessage = "Não foi possível abrir o Mail. Tente SMS ou compartilhar."
                            case .saved:
                                statusMessage = "Rascunho salvo no Mail."
                            @unknown default:
                                break
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showShare) {
                if let inviteCopy {
                    ShareSheet(items: [inviteCopy.shareText])
                }
            }
            .alert("SMS indisponível", isPresented: $showSMSUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Este aparelho não pode enviar SMS. Use e-mail ou compartilhe o código.")
            }
            .alert("E-mail indisponível", isPresented: $showMailUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Configure uma conta de e-mail no aparelho ou compartilhe o convite de outra forma.")
            }
        }
    }

    private func runSearch() async {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            searchResults = []
            searchError = nil
            return
        }
        isSearching = true
        defer { isSearching = false }
        await duoService.ensureDirectorySynced(profile: authService.currentUser)
        searchResults = await duoService.searchAppUsers(query: q)
        searchError = duoService.lastError
    }

    private func inviteUser(_ user: UserDirectoryEntry) async {
        invitingUid = user.uid
        defer { invitingUid = nil }
        let ok = await duoService.inviteAppUser(team: team, user: user)
        if ok {
            statusMessage = "Convite enviado para \(user.shownName). Status: pendente — aguardando aceite ou recusa."
        } else if let error = duoService.lastError {
            statusMessage = error
        }
    }

    @ViewBuilder
    private var teamInvitesStatusSection: some View {
        let invites = duoService.sentInvites(forTeamId: team.id)
        if !invites.isEmpty {
            Section("Status dos convites") {
                ForEach(invites.prefix(10)) { invite in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(invite.toName)
                                .font(.subheadline.weight(.medium))
                            Text(invite.toUid == nil ? "SMS / código" : "No app")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(invite.isExpired && invite.status == .pending
                             ? DuoInviteStatus.expired.displayLabel
                             : invite.status.displayLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(inviteStatusColor(invite))
                    }
                }
            }
        }
    }

    private func inviteStatusColor(_ invite: DuoTeamInvite) -> Color {
        if invite.isExpired && invite.status == .pending { return .secondary }
        switch invite.status {
        case .pending: return .orange
        case .accepted: return .green
        case .declined, .cancelled, .expired: return .secondary
        }
    }

    private func createAndSendSMS() async {
        isWorking = true
        defer { isWorking = false }
        guard let result = await duoService.createInvite(
            team: team,
            partnerName: partnerName,
            phone: phone
        ) else { return }

        applyInviteResult(result.invite, copy: result.copy)
        smsRecipients = [result.invite.toPhoneE164]

        if MessageComposeView.canSendText {
            showSMS = true
        } else {
            showSMSUnavailable = true
        }
    }

    private func createAndSendEmail() async {
        isWorking = true
        defer { isWorking = false }
        guard let result = await duoService.createEmailInvite(
            team: team,
            partnerName: partnerName,
            email: email
        ) else { return }

        applyInviteResult(result.invite, copy: result.copy)
        emailRecipients = [result.invite.toEmail ?? email]

        if MailComposeView.canSendMail {
            showMail = true
        } else if let url = MailComposeView.mailtoURL(
            recipients: emailRecipients,
            subject: result.copy.emailSubject,
            body: result.copy.emailBody
        ), UIApplication.shared.canOpenURL(url) {
            await UIApplication.shared.open(url)
            statusMessage = "Abrindo o app de e-mail com o convite motivador."
        } else {
            showMailUnavailable = true
        }
    }

    private func createShareable() async {
        isWorking = true
        defer { isWorking = false }
        guard let result = await duoService.createShareableInvite(team: team) else { return }
        applyInviteResult(result.invite, copy: result.copy)
        statusMessage = "Código \(result.invite.code) pronto. Compartilhe — o HealthFit espera pelo novo membro."
    }

    private func applyInviteResult(_ invite: DuoTeamInvite, copy: DuoInviteShareCopy) {
        generatedCode = invite.code
        inviteCopy = copy
        statusMessage = "Convite criado · código \(invite.code)"
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
