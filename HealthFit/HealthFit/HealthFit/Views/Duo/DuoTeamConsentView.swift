import SwiftUI

struct DuoTeamConsentView: View {
    var onAccept: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)

                Text("Treino em dupla / equipe")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(DuoTeamPrivacy.clearNotice)
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label(
                    "Sem mapa em tempo real e sem compartilhar sua posição ao vivo.",
                    systemImage: "location.slash.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

                Spacer()

                Button("Li e concordo — continuar") {
                    onAccept()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Agora não", role: .cancel) {
                    onCancel()
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(24)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
