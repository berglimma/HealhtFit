import SwiftUI
import FirebaseAuth

/// Fila de denúncias do Pulse — visível só para o e-mail moderador (App Review / suporte).
struct PulseModerationQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reports: [PulseCloudReport] = []
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var busyPostId: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && reports.isEmpty {
                    ProgressView("Carregando denúncias…")
                } else if reports.isEmpty {
                    ContentUnavailableView(
                        "Nenhuma denúncia",
                        systemImage: "checkmark.shield",
                        description: Text("Quando alguém denunciar um post, ele aparece aqui.")
                    )
                } else {
                    List {
                        ForEach(reports) { report in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Post \(report.postId.prefix(8))…")
                                    .font(.headline)
                                Text(report.reason)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text("Reporter: \(report.reporterId.prefix(10))… · \(report.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                                HStack(spacing: 12) {
                                    Button("Ocultar post") {
                                        Task { await hide(report) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                                    .disabled(busyPostId == report.postId)

                                    Button("Apagar post", role: .destructive) {
                                        Task { await delete(report) }
                                    }
                                    .disabled(busyPostId == report.postId)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Moderação Pulse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(AppTheme.cardBackground)
                }
            }
            .task { await reload() }
        }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        reports = await PulseFirestoreService.fetchReports(limit: 80)
        if reports.isEmpty {
            statusMessage = PulseExperimental.isCloudSyncEffective
                ? nil
                : "Cloud sync desligado — ligue pulseCloudSyncEnabled ou Labs."
        } else {
            statusMessage = nil
        }
    }

    private func hide(_ report: PulseCloudReport) async {
        guard let postId = UUID(uuidString: report.postId) else { return }
        busyPostId = report.postId
        defer { busyPostId = nil }
        await PulseFirestoreService.moderateHidePost(postId: postId, hidden: true)
        PulseLocalStore.shared.hidePost(postId)
        statusMessage = "Post ocultado."
        await reload()
    }

    private func delete(_ report: PulseCloudReport) async {
        guard let postId = UUID(uuidString: report.postId) else { return }
        busyPostId = report.postId
        defer { busyPostId = nil }
        await PulseFirestoreService.moderateDeletePost(postId: postId)
        PulseLocalStore.shared.hidePost(postId)
        statusMessage = "Post removido na nuvem."
        await reload()
    }
}

enum PulseModerationAccess {
    static func canModerate(email: String?) -> Bool {
        guard let email else { return false }
        return email.lowercased() == AppLegalConfiguration.supportEmail.lowercased()
    }

    static var currentUserCanModerate: Bool {
        canModerate(email: Auth.auth().currentUser?.email)
    }
}
