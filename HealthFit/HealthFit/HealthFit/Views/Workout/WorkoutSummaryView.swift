import SwiftUI

struct WorkoutSummaryView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let session: WorkoutSession
    let onFinish: () -> Void

    @State private var showMailComposer = false
    @State private var showMailUnavailableAlert = false
    @State private var emailSentFeedback = false

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
        .sheet(isPresented: $showMailComposer) {
            if let user = authService.currentUser {
                MailComposeView(
                    recipients: [user.personalTrainerEmail],
                    subject: WorkoutReportBuilder.emailSubject(session: session, athleteName: user.name),
                    body: WorkoutReportBuilder.emailBody(session: session, athlete: user)
                )
            }
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
                        emailSentFeedback ? "Abrindo e-mail..." : "Enviar relatório ao Personal",
                        systemImage: "envelope.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private func sendReportToTrainer(user: UserProfile) {
        emailSentFeedback = true

        if MailComposeView.canSendMail {
            showMailComposer = true
        } else if let url = MailComposeView.mailtoURL(
            recipients: [user.personalTrainerEmail],
            subject: WorkoutReportBuilder.emailSubject(session: session, athleteName: user.name),
            body: WorkoutReportBuilder.emailBody(session: session, athlete: user)
        ) {
            UIApplication.shared.open(url)
        } else {
            showMailUnavailableAlert = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            emailSentFeedback = false
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
