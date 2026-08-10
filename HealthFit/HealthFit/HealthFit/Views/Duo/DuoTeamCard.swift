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
