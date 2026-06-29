import SwiftUI
import MessageUI

private struct TrainerMailDraft: Identifiable {
    let id = UUID()
    let recipients: [String]
    let subject: String
    let body: String
}

struct WorkoutSummaryView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let session: WorkoutSession
    let onFinish: () -> Void

    @State private var mailDraft: TrainerMailDraft?
    @State private var showMailUnavailableAlert = false
    @State private var showEmailSentAlert = false
    @State private var showEmailFailedAlert = false
    @State private var emailWasSent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryHeader
                    exerciseBreakdown
                    totalsSection
                    emailSection
                }
                .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .adaptiveContentWidth()
            }
            .background(AppTheme.background)
            .navigationTitle("Treino Concluído")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") {
                        onFinish()
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .sheet(item: $mailDraft) { draft in
            MailComposeView(
                recipients: draft.recipients,
                subject: draft.subject,
                body: draft.body
            ) { result in
                mailDraft = nil
                handleMailResult(result)
            }
        }
        .alert("E-mail enviado", isPresented: $showEmailSentAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let user = authService.currentUser {
                Text("O relatório foi enviado para \(user.personalTrainerName.isEmpty ? user.personalTrainerEmail : user.personalTrainerName) com sucesso.")
            }
        }
        .alert("Falha no envio", isPresented: $showEmailFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Não foi possível enviar o e-mail. Verifique se há uma conta de e-mail configurada no iPhone (Ajustes → Mail → Contas).")
        }
        .alert("E-mail indisponível", isPresented: $showMailUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Configure uma conta de e-mail no iPhone ou cadastre o e-mail do personal no perfil.")
        }
    }

    @ViewBuilder
    private var emailSection: some View {
        if let user = authService.currentUser, user.hasPersonalTrainer {
            VStack(spacing: 12) {
                Button {
                    sendReportToTrainer(user: user)
                } label: {
                    Label(
                        buttonLabel,
                        systemImage: emailWasSent ? "checkmark.circle.fill" : "envelope.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(emailWasSent ? Color.green : AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(mailDraft != nil || emailWasSent)

                if emailWasSent {
                    Label("E-mail enviado", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                }

                if !user.personalTrainerName.isEmpty {
                    Text("Para: \(user.personalTrainerName) · \(user.personalTrainerEmail)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var buttonLabel: String {
        if emailWasSent { return "E-mail enviado" }
        if mailDraft != nil { return "Abrindo e-mail..." }
        return "Enviar relatório ao Personal"
    }

    private func sendReportToTrainer(user: UserProfile) {
        let recipient = user.personalTrainerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipient.isEmpty else {
            showMailUnavailableAlert = true
            return
        }

        let subject = WorkoutReportBuilder.emailSubject(session: session, athleteName: user.name)
        let body = WorkoutReportBuilder.emailBody(session: session, athlete: user)

        if MailComposeView.canSendMail {
            mailDraft = TrainerMailDraft(
                recipients: [recipient],
                subject: subject,
                body: body
            )
        } else if let url = MailComposeView.mailtoURL(
            recipients: [recipient],
            subject: subject,
            body: body
        ) {
            UIApplication.shared.open(url) { accepted in
                if !accepted {
                    showMailUnavailableAlert = true
                }
            }
        } else {
            showMailUnavailableAlert = true
        }
    }

    private func handleMailResult(_ result: MFMailComposeResult) {
        switch result {
        case .sent:
            emailWasSent = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showEmailSentAlert = true
            }
        case .failed:
            showEmailFailedAlert = true
        case .cancelled, .saved:
            break
        @unknown default:
            break
        }
    }

    private var summaryHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.accent)

            Text(session.workoutTitle)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: 20) {
                SummaryStat(
                    value: DurationFormatting.format(seconds: Int(session.duration)),
                    label: "Duração total",
                    icon: "clock.fill"
                )
                SummaryStat(
                    value: "\(session.completedExercises)/\(session.totalExercises)",
                    label: "Exercícios",
                    icon: "list.bullet"
                )
                if session.caloriesBurned > 0 {
                    SummaryStat(
                        value: "\(Int(session.caloriesBurned))",
                        label: "kcal",
                        icon: "flame.fill"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tempo por Exercício")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(session.exerciseRecords) { record in
                HStack(spacing: 12) {
                    Image(systemName: record.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(record.isCompleted ? AppTheme.accent : AppTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.exerciseName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        if record.restSeconds > 0 {
                            Text("Descanso: \(DurationFormatting.format(seconds: record.restSeconds))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    Spacer()

                    Text(DurationFormatting.format(seconds: record.elapsedSeconds))
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(record.isCompleted ? AppTheme.accent : AppTheme.textSecondary)
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var totalsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Tempo nos exercícios", systemImage: "figure.strengthtraining.traditional")
                Spacer()
                Text(DurationFormatting.format(seconds: session.totalExerciseSeconds))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            }

            HStack {
                Label("Descanso total", systemImage: "timer")
                Spacer()
                Text(DurationFormatting.format(seconds: session.totalRestSeconds))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(AppTheme.accentSecondary)
            }
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

private struct SummaryStat: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

import UIKit
