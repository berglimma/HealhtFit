import SwiftUI

/// Tela bloqueante: o usuário só continua após atualizar na App Store.
struct ForceAppUpdateView: View {
    @ObservedObject var updateService: AppUpdateService

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer(minLength: 24)

                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.bottom, 4)

                Text("Atualização necessária")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(updateService.updateMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                VStack(spacing: 8) {
                    versionRow(label: "Sua versão", value: updateService.installedVersion)
                    if let store = updateService.storeVersion {
                        versionRow(label: "Versão na App Store", value: store)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    updateService.openAppStore()
                } label: {
                    Label("Atualizar na App Store", systemImage: "safari.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Text("O HealthFit precisa da versão mais recente para funcionar corretamente.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 24)
            }
            .padding(24)
            .adaptiveContentWidth()
        }
        .interactiveDismissDisabled()
    }

    private func versionRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}
