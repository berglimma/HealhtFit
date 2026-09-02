import SwiftUI

struct KiteSpotBuddySessionView: View {
    @ObservedObject var service: KiteSpotBuddyService
    var onRequestHelp: () -> Void
    var onCancelHelp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Spot Buddy", systemImage: "location.fill.viewfinder")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(service.peers.count) no radar")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
            }

            if service.peers.isEmpty {
                Text("Nenhum amigo da equipe com Spot Buddy ativo por perto (até 2 km).")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(service.peers.prefix(4)) { peer in
                    HStack(spacing: 10) {
                        Image(systemName: peer.needsHelp ? "exclamationmark.triangle.fill" : "person.circle.fill")
                            .foregroundStyle(peer.needsHelp ? .orange : AppTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(peer.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(formattedDistance(peer.distanceMeters))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        if let bearing = peer.bearingDegrees {
                            Text("\(Int(bearing.rounded()))°")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            }

            if service.needsHelp {
                Label("Pedido de ajuda enviado", systemImage: "bell.badge.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Button("Estou bem — cancelar ajuda") {
                    onCancelHelp()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            } else {
                Button {
                    onRequestHelp()
                } label: {
                    Label("Pedir ajuda aos amigos", systemImage: "sos")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func formattedDistance(_ meters: Double) -> String {
        if meters < 1_000 {
            return String(format: "%.0f m", meters)
        }
        return String(format: "%.1f km", meters / 1_000)
    }
}

struct KiteSpotBuddyHelpConfirmSheet: View {
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Confirmar pedido de ajuda?")
                    .font(.title3.bold())
                Text("Amigos da equipe com Spot Buddy ativo receberão um alerta com sua distância aproximada.")
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button("Enviar pedido de ajuda", role: .destructive) {
                    onConfirm()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Cancelar", role: .cancel) {
                    onCancel()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

struct KiteSpotBuddyIncomingHelpBanner: View {
    let peer: KiteSpotBuddyPeer
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(peer.displayName) pediu ajuda", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text("A ~\(Int(peer.distanceMeters.rounded())) m de você")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            if let bearing = peer.bearingDegrees {
                Text("Direção: \(Int(bearing.rounded()))°")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
            }
            Button("Entendi") {
                onDismiss()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
