import SwiftUI

/// Card de entrada no Dashboard / Treinos para dupla ou equipe.
struct DuoTeamCard: View {
    @ObservedObject private var duoService = DuoTeamService.shared
    @State private var showConsent = false
    @State private var showHub = false

    var body: some View {
        Button {
            if duoService.hasPrivacyConsent {
                showHub = true
            } else {
                showConsent = true
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: "person.3.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Treino em dupla / equipe")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(
                        duoService.hasPrivacyConsent
                            ? (duoService.teams.isEmpty
                                ? "Convide parceiros, chat e SMS — sem localização ao vivo"
                                : "\(duoService.teams.count) equipe(s) · chat para marcar treinos")
                            : "Toque para saber como funciona (sem mapa em tempo real)"
                    )
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .cardStyle()
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
