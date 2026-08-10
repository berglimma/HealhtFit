import MessageUI
import SwiftUI

struct DuoTeamInviteView: View {
    let team: DuoTeam
    @ObservedObject private var duoService = DuoTeamService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var searchResults: [UserDirectoryEntry] = []
    @State private var isSearching = false
    @State private var invitingUid: String?

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
                    Text("Busque no app, envie SMS ou e-mail com um convite motivador. O HealthFit espera por quem ainda não entrou. Sem localização em tempo real.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Buscar no HealthFit") {
                    HStack {
                        TextField("Nome ou como quer ser chamado", text: $searchQuery)
                            .textInputAutocapitalization(.words)
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

                    if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                        Text("Digite pelo menos 2 letras.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !isSearching && searchResults.isEmpty && !searchQuery.isEmpty {
                        Text("Ninguém encontrado com esse nome.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(searchResults) { user in
                        Button {
                            Task { await inviteUser(user) }
                        } label: {
                            HStack(spacing: 12) {
                                DuoMemberAvatarView(
                                    name: user.shownName,
                                    photoURL: user.photoURL,
                                    countryCode: user.countryCode,
                                    size: 40
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.shownName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(user.detailLine)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                if invitingUid == user.uid {
                                    ProgressView()
                                } else if team.members.contains(where: { $0.uid == user.uid }) {
                                    Text("Na equipe")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "person.badge.plus")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                        .disabled(invitingUid != nil || team.members.contains(where: { $0.uid == user.uid }))
                    }
                }

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
            return
        }
        isSearching = true
        defer { isSearching = false }
        searchResults = await duoService.searchAppUsers(query: q)
    }

    private func inviteUser(_ user: UserDirectoryEntry) async {
        invitingUid = user.uid
        defer { invitingUid = nil }
        let ok = await duoService.inviteAppUser(team: team, user: user)
        if ok {
            statusMessage = "Convite enviado para \(user.shownName). O HealthFit espera pela resposta em Dupla / equipe."
            generatedCode = duoService.sentInvites.first(where: { $0.toUid == user.uid })?.code
        } else if let error = duoService.lastError {
            statusMessage = error
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
