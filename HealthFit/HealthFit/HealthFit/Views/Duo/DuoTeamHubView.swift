import SwiftUI

struct DuoTeamHubView: View {
    @ObservedObject private var duoService = DuoTeamService.shared
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var joinCode = ""
    @State private var newName = ""
    @State private var newModality: DuoTeamModality = .mixed
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                privacyBanner

                HStack(spacing: 12) {
                    Button {
                        showCreate = true
                    } label: {
                        Label("Criar", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        showJoin = true
                    } label: {
                        Label("Entrar com código", systemImage: "ticket.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if !duoService.receivedInvites.isEmpty {
                    receivedInvitesSection
                }

                if duoService.teams.isEmpty {
                    emptyState
                } else {
                    ForEach(duoService.teams) { team in
                        NavigationLink {
                            DuoTeamDetailView(teamId: team.id)
                        } label: {
                            teamRow(team)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !duoService.sentInvites.isEmpty {
                    invitesSection
                }

                if let error = duoService.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Dupla / equipe")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await duoService.loadIfNeeded()
        }
        .sheet(isPresented: $showCreate) {
            createSheet
        }
        .sheet(isPresented: $showJoin) {
            joinSheet
        }
    }

    private var privacyBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sem localização em tempo real", systemImage: "location.slash.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Não há mapa ao vivo. O chat é só para marcar atividades físicas e as mensagens duram 24 horas.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.3")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.accent)
            Text("Nenhuma equipe ainda")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text("Crie uma dupla/equipe, busque pessoas pelo nome no app (ou SMS) e use o chat só para marcar atividades físicas (mensagens expiram em 24h).")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 28)
        .cardStyle()
    }

    private func teamRow(_ team: DuoTeam) -> some View {
        HStack(spacing: 14) {
            Image(systemName: team.modality.icon)
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 44, height: 44)
                .background(AppTheme.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(team.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(team.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .cardStyle()
    }

    private var receivedInvitesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Convites recebidos")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            ForEach(duoService.receivedInvites) { invite in
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(invite.fromName) convidou você")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(invite.teamName) · \(invite.modality.rawValue)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack {
                        Button("Aceitar") {
                            Task {
                                isWorking = true
                                _ = await duoService.acceptReceivedInvite(invite)
                                isWorking = false
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button("Recusar", role: .destructive) {
                            Task { await duoService.declineReceivedInvite(invite) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .cardStyle()
            }
        }
    }

    private var invitesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Convites enviados")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            ForEach(duoService.sentInvites.prefix(8)) { invite in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(invite.toName) · \(invite.code)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(
                            invite.toUid == nil
                                ? "\(invite.teamName) · \(invite.status.rawValue)"
                                : "\(invite.teamName) · no app · \(invite.status.rawValue)"
                        )
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                }
                .cardStyle()
            }
        }
    }

    private var createSheet: some View {
        NavigationStack {
            Form {
                Section("Nova dupla / equipe") {
                    TextField("Nome", text: $newName)
                    Picker("Modalidade", selection: $newModality) {
                        ForEach(DuoTeamModality.allCases) { modality in
                            Label(modality.rawValue, systemImage: modality.icon)
                                .tag(modality)
                        }
                    }
                }
                Section {
                    Text("Por segurança o HealthFit não usa localização em tempo real.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Criar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showCreate = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Criar") {
                        Task {
                            isWorking = true
                            _ = await duoService.createTeam(name: newName, modality: newModality)
                            isWorking = false
                            newName = ""
                            showCreate = false
                        }
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
                }
            }
        }
    }

    private var joinSheet: some View {
        NavigationStack {
            Form {
                Section("Código do convite") {
                    TextField("Ex.: AB12CD", text: $joinCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("Peça o código a quem te convidou (também chega por SMS se a pessoa usou o convite).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Entrar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showJoin = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Entrar") {
                        Task {
                            isWorking = true
                            _ = await duoService.joinTeam(withCode: joinCode)
                            isWorking = false
                            joinCode = ""
                            showJoin = false
                        }
                    }
                    .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 4 || isWorking)
                }
            }
        }
    }
}

struct DuoTeamDetailView: View {
    let teamId: String
    @ObservedObject private var duoService = DuoTeamService.shared
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var showInvite = false
    @State private var showLeaveConfirm = false
    @State private var isLeaving = false

    private var team: DuoTeam? {
        duoService.teams.first(where: { $0.id == teamId })
    }

    private var isDuoWorkoutActive: Bool {
        workoutStore.activeDuoTeamId == teamId
    }

    var body: some View {
        Group {
            if let team {
                List {
                    Section {
                        Label("Sem mapa ou localização em tempo real", systemImage: "location.slash")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Section("Membros (\(team.memberCount))") {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 72, maximum: 80), spacing: 10)],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            ForEach(team.members) { member in
                                DuoMemberCardView(
                                    member: member,
                                    localImage: member.uid == authService.currentUser?.id
                                        ? authService.profileImage
                                        : nil
                                )
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.clear)
                    }

                    Section("Adicionar pessoas") {
                        Button {
                            showInvite = true
                        } label: {
                            Label("Buscar no app, SMS, e-mail ou código", systemImage: "person.badge.plus")
                        }
                        Text("Busque pelo nome ou “Como você gostaria de ser chamado”. Também dá para convidar por SMS, e-mail motivador ou código.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Treino em equipe") {
                        Button {
                            if isDuoWorkoutActive {
                                workoutStore.clearDuoTeamWorkoutContext()
                            } else {
                                workoutStore.setDuoTeamWorkoutContext(
                                    teamId: team.id,
                                    teamName: team.name
                                )
                            }
                        } label: {
                            Label(
                                isDuoWorkoutActive
                                    ? "Modo equipe ativo — toque para desligar"
                                    : "Ativar: próximos treinos contam para a equipe",
                                systemImage: isDuoWorkoutActive
                                    ? "person.3.fill"
                                    : "figure.run.circle"
                            )
                        }
                        Text(
                            isDuoWorkoutActive
                                ? "Os próximos treinos que você iniciar (força, cardio, etc.) entram no relatório desta equipe. Treinos individuais não entram."
                                : "Ative o modo equipe antes de iniciar o treino. Só esses treinos aparecem no ranking — os individuais ficam de fora."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Section("Ações") {
                        NavigationLink {
                            DuoTeamChatView(teamId: team.id, teamName: team.name)
                        } label: {
                            Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                        }
                        NavigationLink {
                            DuoTeamReportView(teamId: team.id)
                        } label: {
                            Label("Relatório e ranking da equipe", systemImage: "chart.bar.fill")
                        }
                    }

                    if !duoService.scheduledMessages(for: team.id).isEmpty {
                        Section("Treinos combinados") {
                            ForEach(duoService.scheduledMessages(for: team.id)) { message in
                                Text(message.text)
                                    .font(.subheadline)
                            }
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            showLeaveConfirm = true
                        } label: {
                            Label(
                                isLeaving ? "Saindo…" : "Sair do grupo",
                                systemImage: "rectangle.portrait.and.arrow.right"
                            )
                        }
                        .disabled(isLeaving)
                    } footer: {
                        Text(
                            team.memberCount <= 1
                                ? "Você é o único membro. Ao sair, a equipe será encerrada."
                                : "Você deixa de ver o chat e os convites desta equipe. Os demais membros continuam."
                        )
                    }
                }
                .navigationTitle(team.name)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showInvite) {
                    DuoTeamInviteView(team: team)
                }
                .confirmationDialog(
                    "Sair do grupo?",
                    isPresented: $showLeaveConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Sair do grupo", role: .destructive) {
                        Task {
                            isLeaving = true
                            let leftTeamId = team.id
                            let ok = await duoService.leaveTeam(teamId: leftTeamId)
                            if ok, workoutStore.activeDuoTeamId == leftTeamId {
                                workoutStore.clearDuoTeamWorkoutContext()
                            }
                            isLeaving = false
                            if ok { dismiss() }
                        }
                    }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text(
                        team.memberCount <= 1
                            ? "A equipe será encerrada porque não haverá mais membros."
                            : "Você poderá entrar de novo só com um novo convite/código."
                    )
                }
                .task {
                    await duoService.enrichMembersFromDirectory(teamId: team.id)
                    await duoService.loadMessages(teamId: team.id)
                }
            } else {
                ContentUnavailableView("Equipe não encontrada", systemImage: "person.3")
            }
        }
    }
}
