import SwiftUI

struct KiteSpotBuddyConsentView: View {
    var onAccept: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "wind")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)

                Text("Kite Spot Buddy")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(KiteSpotBuddyPrivacy.clearNotice)
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label(
                    "Somente kitesurf · somente durante a sessão · opt-in separado do Duo.",
                    systemImage: "location.fill.viewfinder"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.cyan)

                Spacer()

                Button("Li e concordo — ativar Spot Buddy") {
                    KiteSpotBuddyPreferences.grantConsent()
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
