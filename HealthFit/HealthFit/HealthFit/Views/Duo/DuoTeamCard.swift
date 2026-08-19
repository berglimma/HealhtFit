import SwiftUI

/// Card de entrada no Dashboard / Treinos para dupla ou equipe.
struct DuoTeamCard: View {
    @ObservedObject private var duoService = DuoTeamService.shared
    @State private var showConsent = false
    @State private var showHub = false

    private var subtitle: String {
        if !duoService.hasPrivacyConsent {
            return "Toque para saber como funciona (sem mapa em tempo real)"
        }
        if duoService.teams.isEmpty {
            return "Convide parceiros, chat e ranking — sem localização ao vivo"
        }
        let unread = duoService.totalUnreadChatCount
        if unread == 1 {
            return "1 mensagem não lida no chat"
        }
        if unread > 1 {
            return "\(unread) mensagens não lidas no chat"
        }
        return "\(duoService.teams.count) equipe(s) · chat para marcar treinos"
    }

    private var footerText: String {
        duoService.teams.isEmpty ? "Criar ou entrar" : "Abrir equipes"
    }

    var body: some View {
        Button {
            if duoService.hasPrivacyConsent {
                showHub = true
            } else {
                showConsent = true
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                WorkoutProgramHeroCard(
                    title: "Treino em dupla / equipe",
                    subtitle: subtitle,
                    accent: AppTheme.accent,
                    imageName: "DuoTeamCover",
                    systemImage: "person.3.fill",
                    coverColors: [AppTheme.accent, AppTheme.accentSecondary],
                    footerLabels: [
                        (icon: "person.3.fill", text: footerText),
                        (icon: "chart.bar.fill", text: "Ranking")
                    ]
                )
                DuoUnreadBadge(count: duoService.totalUnreadChatCount)
                    .padding(12)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showConsent) {
            DuoTeamConsentView(
                onAccept: {
                    duoService.acknowledgePrivacy()
                    showConsent = false
                    showHub = true
                },
                onCancel: { showConsent = false }
            )
            .presentationDetents([.medium, .large])
        }
        .navigationDestination(isPresented: $showHub) {
            DuoTeamHubView()
        }
    }
}

/// Bolha vermelha com a quantidade de mensagens não lidas no chat da equipe.
struct DuoUnreadBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, count > 9 ? 6 : 0)
                .frame(minWidth: 22, minHeight: 22)
                .background(Color.red)
                .clipShape(Capsule())
                .accessibilityLabel(
                    count == 1
                        ? "1 mensagem não lida"
                        : "\(min(count, 99)) mensagens não lidas"
                )
        }
    }
}
