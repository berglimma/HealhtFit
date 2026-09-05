import Combine
import Foundation
import SwiftUI

struct CoachConsentView: View {
    var onAccept: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)

                Text("HealthFit Coach")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(CoachPrivacy.clearNotice)
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label(CoachPrivacy.shortLabel, systemImage: "lock.shield.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                Spacer()

                Button("Li e concordo — continuar") {
                    CoachPreferences.grantConsent()
                    onAccept()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Agora não", role: .cancel, action: onCancel)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(24)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CoachHubView: View {
    @ObservedObject private var coach = CoachService.shared
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var showConsent = false
    @State private var showProfileSetup = false
    @State private var showInvite = false
    @State private var showJoin = false
    @State private var showSearch = false
    @State private var inviteCode = ""
    @State private var joinStatus: String?
    @State private var selectedLink: CoachLink?
    @State private var showDeleteCadastroConfirm = false
    @State private var isDeletingCadastro = false
    @State private var cadastroStatusMessage: String?

    private var role: UserAccountRole {
        authService.currentUser?.accountRole ?? .student
    }

    private var isPro: Bool {
        role.isPersonalProfessional || role.isNutritionProfessional
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if !CoachPreferences.hasConsent {
                    consentCard
                } else if isPro {
                    professionalSections
                } else {
                    studentSections
                }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("HealthFit Coach")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            coach.start()
            Task {
                await coach.refreshLinkStatusesForPlan()
                if isPro {
                    await coach.refreshProfessionalPhotoFromAppProfileIfNeeded()
                }
            }
        }
        .sheet(isPresented: $showConsent) {
            CoachConsentView(
                onAccept: { showConsent = false; showProfileSetup = isPro },
                onCancel: { showConsent = false }
            )
        }
        .sheet(isPresented: $showProfileSetup) {
            NavigationStack {
                CoachProfileSetupView {
                    showProfileSetup = false
                    Task { await coach.refreshProfile() }
                }
            }
        }
        .sheet(isPresented: $showInvite) {
            NavigationStack {
                CoachInviteCreateView()
            }
        }
        .sheet(isPresented: $showJoin) {
            joinSheet
        }
        .sheet(isPresented: $showSearch) {
            NavigationStack {
                CoachSearchView()
            }
        }
        .navigationDestination(item: $selectedLink) { link in
            CoachLinkDetailView(link: link)
        }
        .alert("Excluir cadastro no Coach?", isPresented: $showDeleteCadastroConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir cadastro", role: .destructive) {
                Task {
                    isDeletingCadastro = true
                    cadastroStatusMessage = nil
                    let ok = await coach.deleteProfessionalRegistration()
                    isDeletingCadastro = false
                    if ok {
                        cadastroStatusMessage = "Cadastro removido. Você pode cadastrar de novo depois se quiser."
                    } else {
                        cadastroStatusMessage = coach.lastError ?? "Não foi possível excluir o cadastro."
                    }
                }
            }
        } message: {
            Text("Seu perfil sai da busca regional, os vínculos com alunos são encerrados e o papel da conta volta para Aluno. Fichas já enviadas podem permanecer no app dos alunos.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isPro ? "Painel do profissional" : "Seu personal e nutrição")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(isPro
                 ? "Cadastre alunos, envie fichas e cardápios, e converse no chat."
                 : "Com plano Fit ou superior, receba fichas do personal, dietas e chat 1:1. Cardio continua livre.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var consentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ative o HealthFit Coach")
                .font(.headline)
            Text(CoachPrivacy.shortLabel)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Button("Começar") { showConsent = true }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var professionalSections: some View {
        if coach.myProfile == nil {
            Button {
                if CoachPreferences.hasConsent { showProfileSetup = true }
                else { showConsent = true }
            } label: {
                Label("Completar perfil profissional (CREF/CRN)", systemImage: "person.text.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        } else {
            profileSummary
            HStack(spacing: 10) {
                Button { showInvite = true } label: {
                    Label("Convidar aluno", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button { showProfileSetup = true } label: {
                    Label("Editar", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button(role: .destructive) {
                showDeleteCadastroConfirm = true
            } label: {
                if isDeletingCadastro {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Excluir cadastro no Coach", systemImage: "person.crop.circle.badge.minus")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(isDeletingCadastro)

            Text("Remove seu perfil da busca, encerra vínculos com alunos e volta o papel da conta para Aluno.")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)

            if let cadastroStatusMessage {
                Text(cadastroStatusMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.accentSecondary)
            }
        }

        linksSection(title: "Meus alunos", empty: "Nenhum aluno vinculado ainda. Gere um código de convite.")
    }

    @ViewBuilder
    private var studentSections: some View {
        if !subscriptionService.canAccess(.healthFitCoach) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Plano Fit ou superior necessário")
                    .font(.headline)
                Text(AppFeature.healthFitCoach.upsellDescription)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .requiresSubscription(.healthFitCoach)
        }

        HStack(spacing: 10) {
            Button { showJoin = true } label: {
                Label("Entrar com código", systemImage: "ticket.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button { showSearch = true } label: {
                Label("Buscar na região", systemImage: "mappin.and.ellipse")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }

        linksSection(title: "Meus profissionais", empty: "Você ainda não tem personal ou nutricionista vinculado no app.")
    }

    private var profileSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let profile = coach.myProfile {
                HStack(spacing: 14) {
                    DuoMemberAvatarView(
                        name: profile.displayName,
                        photoURL: profile.photoURL,
                        localImage: authService.profileImage,
                        size: 56
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(profile.credentialSummary)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.accent)
                        Text(profile.locationLabel)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Text(profile.isDirectoryVisible ? "Visível na busca regional" : "Oculto na busca")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Foto sincronizada do Perfil do app. Altere em Perfil para atualizar aqui e na busca.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func linksSection(title: String, empty: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            if coach.myLinks.isEmpty {
                Text(empty)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(coach.myLinks) { link in
                    Button { selectedLink = link } label: {
                        CoachLinkRow(link: link, viewerUid: authService.currentUser?.id ?? "")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var joinSheet: some View {
        NavigationStack {
            Form {
                Section("Código do personal / nutri") {
                    TextField("Ex.: ABC123", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                if let joinStatus {
                    Text(joinStatus).foregroundStyle(.secondary)
                }
                Button("Vincular") {
                    Task {
                        let ok = await coach.acceptInvite(code: inviteCode)
                        joinStatus = ok ? "Vinculado com sucesso." : (coach.lastError ?? "Não foi possível vincular.")
                        if ok { showJoin = false }
                    }
                }
            }
            .navigationTitle("Entrar com código")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { showJoin = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct CoachLinkRow: View {
    let link: CoachLink
    let viewerUid: String

    private var title: String {
        viewerUid == link.coachUid ? link.studentName : link.coachName
    }

    private var photoURL: String? {
        viewerUid == link.coachUid ? link.studentPhotoURL : link.coachPhotoURL
    }

    var body: some View {
        HStack(spacing: 12) {
            DuoMemberAvatarView(name: title, photoURL: photoURL, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                HStack(spacing: 6) {
                    Image(systemName: link.profession.icon)
                        .font(.caption2)
                    Text("\(link.profession.title) · \(link.status.displayLabel)")
                        .font(.caption)
                }
                .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Card de entrada do HealthFit Coach no Perfil (abaixo de “Você é”).
struct HealthFitCoachProfileCard: View {
    let role: UserAccountRole
    let subtitle: String
    let statusChips: [String]
    var isFitLocked: Bool = false

    private var isPro: Bool {
        role.isPersonalProfessional || role.isNutritionProfessional
    }

    private var eyebrow: String {
        if isPro { return "PAINEL PROFISSIONAL" }
        if isFitLocked { return "ALUNO · PLANO FIT+" }
        return "ALUNO · PERSONAL E NUTRI"
    }

    private var title: String {
        isPro ? "HealthFit Coach" : "Seu personal e nutrição"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.42, blue: 0.48),
                    Color(red: 0.08, green: 0.22, blue: 0.32),
                    Color(red: 0.05, green: 0.14, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Atmosfera: formas suaves (sem asset dedicado)
            Circle()
                .fill(AppTheme.accent.opacity(0.22))
                .frame(width: 160, height: 160)
                .blur(radius: 8)
                .offset(x: 140, y: -50)

            Circle()
                .fill(Color.orange.opacity(0.12))
                .frame(width: 100, height: 100)
                .offset(x: -30, y: 40)

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Label(eyebrow, systemImage: "person.badge.shield.checkmark.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())

                    Spacer(minLength: 8)

                    if isFitLocked {
                        PlanRequirementBadge(tier: FeatureGate.minimumPlan(for: .healthFitCoach), compact: true)
                    } else {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !statusChips.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(statusChips.prefix(3), id: \.self) { chip in
                            Text(chip)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.95))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Capsule())
                                .lineLimit(1)
                        }
                    }
                }

                HStack(spacing: 14) {
                    Label(isPro ? "Alunos" : "Fichas", systemImage: isPro ? "person.2.fill" : "dumbbell.fill")
                    Label(isPro ? "Prescrever" : "Dieta", systemImage: isPro ? "list.clipboard.fill" : "fork.knife")
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 168)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("HealthFit Coach")
        .accessibilityHint(subtitle)
    }
}

/// Deep link do chat Coach (toque em notificação FCM).
@MainActor
final class CoachNavigationRouter: ObservableObject {
    static let shared = CoachNavigationRouter()

    struct ChatDestination: Identifiable, Equatable {
        let linkId: String
        var id: String { linkId }
    }

    @Published var presentedChat: ChatDestination?
    @Published private(set) var focusProfileTabTick: Int = 0

    private init() {}

    func openChat(linkId: String) {
        let trimmed = linkId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        focusProfileTabTick &+= 1
        CoachService.shared.start()
        CoachService.shared.ensureChatListening(linkId: trimmed)
        presentedChat = ChatDestination(linkId: trimmed)
    }

    func dismissChat() {
        presentedChat = nil
    }

    func handleNotificationUserInfo(_ userInfo: [AnyHashable: Any], category: String) {
        let kind = stringValue(userInfo["kind"])
        let type = stringValue(userInfo["type"])
        let linkId = stringValue(userInfo["linkId"])
        guard !linkId.isEmpty else { return }
        let isCoach =
            kind == "coachChatMessage"
            || type == "coachChatMessage"
            || category == "HEALTHFIT_COACH"
        guard isCoach else { return }
        openChat(linkId: linkId)
    }

    private func stringValue(_ raw: Any?) -> String {
        (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
