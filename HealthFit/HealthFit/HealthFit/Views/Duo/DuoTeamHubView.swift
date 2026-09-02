import SwiftUI

struct DuoTeamHubView: View {
    @ObservedObject private var duoService = DuoTeamService.shared
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var joinCode = ""
    @State private var newName = ""
    @State private var selectedModalities: Set<DuoTeamModality> = []
    @State private var isWorking = false
    @State private var isRefreshing = false

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

                if !duoService.pendingSentInvites().isEmpty {
                    pendingSentInvitesSection
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
        .refreshable {
            await duoService.refreshAll()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Dupla / equipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        isRefreshing = true
                        await duoService.refreshAll()
                        isRefreshing = false
                    }
                } label: {
                    if isRefreshing || duoService.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .accessibilityLabel("Atualizar")
                .disabled(isRefreshing || duoService.isLoading)
            }
        }
        .task {
            await duoService.refreshAll()
        }
        .sheet(isPresented: $showCreate) {
            createSheet
        }
        .sheet(isPresented: $showJoin) {
            joinSheet
        }
        .requiresSubscription(.duoTeam)
    }

    private var privacyBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sem localização em tempo real", systemImage: "location.slash.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Não há mapa ao vivo. O chat é só para marcar atividades físicas e as mensagens duram 12 horas.")
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
            Text("Crie uma dupla/equipe, busque pessoas pelo nome no app (ou SMS) e use o chat só para marcar atividades físicas (mensagens expiram em 12h).")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 28)
        .cardStyle()
    }

    private func teamRow(_ team: DuoTeam) -> some View {
        HStack(spacing: 14) {
            DuoTeamCoverThumb(photoURL: team.photoURL, modality: team.effectiveModalities.first)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(team.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(team.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            DuoUnreadBadge(count: duoService.unreadCount(for: team.id))
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
            Text("Puxe para atualizar ou use o botão ↻. Convites expirados saem da lista.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
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

    private var pendingSentInvitesSection: some View {
        let invites = duoService.pendingSentInvites()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Convites pendentes")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text("Arraste o card para a esquerda para retirar.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            List {
                ForEach(invites) { invite in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(invite.toName) · \(invite.code)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(
                                invite.toUid == nil
                                    ? invite.teamName
                                    : "\(invite.teamName) · no app"
                            )
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer(minLength: 8)
                        Text(DuoInviteStatus.pending.displayLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.12), in: Capsule())
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { _ = await duoService.cancelSentInvite(invite) }
                        } label: {
                            Label("Retirar", systemImage: "trash")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppTheme.cardBackground)
                            .padding(.vertical, 2)
                    )
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .frame(height: CGFloat(invites.count) * 76)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var createSheet: some View {
        NavigationStack {
            Form {
                Section("Nova dupla / equipe") {
                    TextField("Nome", text: $newName)
                }
                Section {
                    ForEach(DuoTeamModality.selectableCases) { modality in
                        Button {
                            if selectedModalities.contains(modality) {
                                selectedModalities.remove(modality)
                            } else {
                                selectedModalities.insert(modality)
                            }
                        } label: {
                            HStack {
                                Label(modality.rawValue, systemImage: modality.icon)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: selectedModalities.contains(modality)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .foregroundStyle(
                                        selectedModalities.contains(modality)
                                            ? AppTheme.accent
                                            : AppTheme.textSecondary
                                    )
                            }
                        }
                    }
                } header: {
                    Text("Modalidades do grupo")
                } footer: {
                    Text("Selecione uma ou mais. Só treinos dessas modalidades contam no ranking e geram o card de postagem em grupo.")
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
                            _ = await duoService.createTeam(
                                name: newName,
                                modalities: Array(selectedModalities)
                            )
                            isWorking = false
                            newName = ""
                            selectedModalities = []
                            showCreate = false
                        }
                    }
                    .disabled(
                        newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || selectedModalities.isEmpty
                            || isWorking
                    )
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
                detailList(for: team)
            } else {
                ContentUnavailableView("Equipe não encontrada", systemImage: "person.3")
            }
        }
    }

    @ViewBuilder
    private func detailList(for team: DuoTeam) -> some View {
        List {
            privacySection
            membersSection(for: team)
            inviteSection
            pendingInvitesSection(for: team)
            modalitiesSection(for: team)
            duoWorkoutSection(for: team)
            actionsSection(for: team)
            scheduledSection(for: team)
            leaveSection(for: team)
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showInvite) {
            DuoTeamInviteView(team: team)
                .environmentObject(authService)
        }
        .confirmationDialog(
            "Sair do grupo?",
            isPresented: $showLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button("Sair do grupo", role: .destructive) {
                Task { await leaveTeam(teamId: team.id) }
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
    }

    private var privacySection: some View {
        Section {
            Label("Sem mapa ou localização em tempo real", systemImage: "location.slash")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private func membersSection(for team: DuoTeam) -> some View {
        let currentUid = authService.currentUser?.id
        let profileImage = authService.profileImage
        Section("Membros (\(team.memberCount))") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72, maximum: 80), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(team.members) { member in
                    DuoMemberCardView(
                        member: member,
                        localImage: member.uid == currentUid ? profileImage : nil
                    )
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private var inviteSection: some View {
        Section("Adicionar pessoas") {
            Button {
                showInvite = true
            } label: {
                Label("Buscar no app, SMS, e-mail ou código", systemImage: "person.badge.plus")
            }
            Text("A pessoa recebe o convite e precisa aceitar ou recusar. Arraste um convite pendente para retirá-lo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func pendingInvitesSection(for team: DuoTeam) -> some View {
        let invites = duoService.pendingSentInvites(forTeamId: team.id)
        if !invites.isEmpty {
            Section {
                ForEach(invites) { invite in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(invite.toName)
                                .font(.subheadline.weight(.medium))
                            Text(invite.toUid == nil ? "SMS / código · \(invite.code)" : "No app · \(invite.code)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(DuoInviteStatus.pending.displayLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { _ = await duoService.cancelSentInvite(invite) }
                        } label: {
                            Label("Retirar", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Convites pendentes")
            } footer: {
                Text("Arraste o card para a esquerda para retirar o convite.")
            }
        }
    }

    @ViewBuilder
    private func modalitiesSection(for team: DuoTeam) -> some View {
        Section("Modalidades do grupo") {
            ForEach(team.effectiveModalities) { modality in
                Label(modality.rawValue, systemImage: modality.icon)
            }
            Text("Só treinos dessas modalidades entram no ranking e geram o card de postagem em grupo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func duoWorkoutSection(for team: DuoTeam) -> some View {
        let active = isDuoWorkoutActive
        let label = team.modalitiesLabel
        Section("Treino em equipe") {
            Button {
                if active {
                    workoutStore.clearDuoTeamWorkoutContext()
                } else {
                    workoutStore.setDuoTeamWorkoutContext(
                        teamId: team.id,
                        teamName: team.name,
                        modalities: team.effectiveModalities
                    )
                }
            } label: {
                Label(
                    active
                        ? "Modo equipe ativo — toque para desligar"
                        : "Ativar: próximos treinos das modalidades do grupo",
                    systemImage: active ? "person.3.fill" : "figure.run.circle"
                )
            }
            Text(
                active
                    ? "Modo ativo para: \(label). Outras modalidades ficam individuais (sem card/ranking de grupo)."
                    : "Ative o modo equipe e treine uma das modalidades do grupo (\(label)). Só assim conta no ranking e gera o card em grupo."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func actionsSection(for team: DuoTeam) -> some View {
        Section("Ações") {
            NavigationLink {
                DuoTeamChatView(teamId: team.id, teamName: team.name)
            } label: {
                Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
            }
            .badge(duoService.unreadCount(for: team.id))
            NavigationLink {
                DuoTeamReportView(teamId: team.id)
            } label: {
                Label("Relatório e ranking da equipe", systemImage: "chart.bar.fill")
            }
        }
    }

    @ViewBuilder
    private func scheduledSection(for team: DuoTeam) -> some View {
        let messages = duoService.scheduledMessages(for: team.id)
        if !messages.isEmpty {
            Section("Treinos combinados") {
                ForEach(messages) { message in
                    Text(message.text)
                        .font(.subheadline)
                }
            }
        }
    }

    @ViewBuilder
    private func leaveSection(for team: DuoTeam) -> some View {
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
            Text(leaveFooter(for: team))
        }
    }

    private func leaveFooter(for team: DuoTeam) -> String {
        if team.memberCount <= 1 {
            return "Você é o único membro. Ao sair, a equipe será encerrada."
        }
        return "Você deixa de ver o chat e os convites desta equipe. Os demais membros continuam."
    }

    private func leaveTeam(teamId: String) async {
        isLeaving = true
        let ok = await duoService.leaveTeam(teamId: teamId)
        if ok, workoutStore.activeDuoTeamId == teamId {
            workoutStore.clearDuoTeamWorkoutContext()
        }
        isLeaving = false
        if ok { dismiss() }
    }
}

/// Miniatura da capa do grupo (ícone da modalidade).
struct DuoTeamCoverThumb: View {
    var photoURL: String?
    var modality: DuoTeamModality?
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            AppTheme.accent.opacity(0.15)
            Image(systemName: modality?.icon ?? DuoTeamModality.mixed.icon)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.accent.opacity(0.25), lineWidth: 1)
        )
    }
}
