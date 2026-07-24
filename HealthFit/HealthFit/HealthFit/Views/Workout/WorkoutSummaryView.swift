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
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let session: WorkoutSession
    let onFinish: () -> Void
    /// Chamado ao confirmar "E-mail enviado" — deve voltar à lista de treinos.
    var onReturnToWorkoutList: (() -> Void)? = nil

    @State private var mailDraft: TrainerMailDraft?
    @State private var pendingMailResult: MFMailComposeResult?
    @State private var showMailUnavailableAlert = false
    @State private var showEmailSentAlert = false
    @State private var showEmailFailedAlert = false
    @State private var emailWasSent = false

    private var isCardioSession: Bool {
        WorkoutReportBuilder.isCardioSession(session)
    }

    private var marathonReport: MarathonPerformanceReport? {
        MarathonReportBuilder.build(session: session, allSessions: workoutStore.sessionHistory)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryHeader
                    if session.endedEarly {
                        earlyEndSection
                    }
                    if session.targetCalories != nil {
                        calorieGoalResultSection
                    }
                    if marathonReport != nil {
                        marathonPerformanceSection
                    }
                    preWorkoutSection
                    exerciseBreakdown
                    totalsSection
                    emailSection
                    finishButton
                }
                .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .adaptiveContentWidth()
            }
            .background(AppTheme.background)
            .navigationTitle(session.endedEarly ? "Treino Encerrado" : "Treino Concluído")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $mailDraft, onDismiss: {
            presentAlertForPendingMailResult()
        }) { draft in
            MailComposeView(
                recipients: draft.recipients,
                subject: draft.subject,
                body: draft.body
            ) { result in
                pendingMailResult = result
                mailDraft = nil
            }
        }
        .alert("E-mail enviado", isPresented: $showEmailSentAlert) {
            Button("OK") {
                returnToWorkoutListAfterEmail()
            }
        } message: {
            if let user = authService.currentUser {
                Text("O relatório foi enviado para \(user.personalTrainerName.isEmpty ? user.personalTrainerEmail : user.personalTrainerName) com sucesso.")
            } else {
                Text("O relatório foi enviado com sucesso.")
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
            Text("Configure uma conta de e-mail no iPhone ou cadastre o e-mail do personal no Perfil.")
        }
    }

    @ViewBuilder
    private var emailSection: some View {
        VStack(spacing: 12) {
            if let user = authService.currentUser, user.hasPersonalTrainer {
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
                } else {
                    Text("Para: \(user.personalTrainerEmail)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 8) {
                    Label("E-mail do personal não cadastrado", systemImage: "person.crop.circle.badge.exclamationmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Cadastre o e-mail do personal no Perfil para enviar o relatório deste treino.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var finishButton: some View {
        Button {
            onFinish()
        } label: {
            Text("Fechar")
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var buttonLabel: String {
        if emailWasSent { return "E-mail enviado" }
        if mailDraft != nil { return "Abrindo e-mail..." }
        return "Enviar e-mail para o Personal"
    }

    private func presentAlertForPendingMailResult() {
        guard let result = pendingMailResult else { return }
        pendingMailResult = nil

        switch result {
        case .sent:
            emailWasSent = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showEmailSentAlert = true
            }
        case .failed:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showEmailFailedAlert = true
            }
        case .cancelled, .saved:
            break
        @unknown default:
            break
        }
    }

    private func returnToWorkoutListAfterEmail() {
        if let onReturnToWorkoutList {
            onReturnToWorkoutList()
        } else {
            onFinish()
        }
    }

    private func sendReportToTrainer(user: UserProfile) {
        let recipient = user.personalTrainerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipient.isEmpty else {
            showMailUnavailableAlert = true
            return
        }

        let subject = WorkoutReportBuilder.emailSubject(session: session, athleteName: user.name)
        let body = WorkoutReportBuilder.emailBody(
            session: session,
            athlete: user,
            allSessions: workoutStore.sessionHistory
        )

        if MailComposeView.canSendMail {
            pendingMailResult = nil
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

    private var earlyEndCount: Int {
        let history = workoutStore.sessionHistory
        if history.contains(where: { $0.id == session.id }) {
            return WorkoutReportBuilder.earlyEndCount(from: history)
        }
        return WorkoutReportBuilder.earlyEndCount(from: [session] + history)
    }

    private var earlyEndSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Encerrado antecipadamente")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            if let justification = session.earlyEndJustification?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !justification.isEmpty {
                Text(justification)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Text("Total de encerramentos antecipados: \(earlyEndCount) vez(es)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var summaryHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: session.endedEarly ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(session.endedEarly ? Color.red : AppTheme.accent)

            Text(session.workoutTitle)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            if session.endedEarly {
                Text("Treino encerrado sem conclusão completa")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 20) {
                SummaryStat(
                    value: DurationFormatting.format(seconds: Int(session.duration)),
                    label: "Duração total",
                    icon: "clock.fill"
                )
                if isCardioSession {
                    if session.caloriesBurned > 0 {
                        SummaryStat(
                            value: "\(Int(session.caloriesBurned))",
                            label: "kcal",
                            icon: "flame.fill"
                        )
                    }
                    if session.averageHeartRate > 0 {
                        SummaryStat(
                            value: String(format: "%.0f", session.averageHeartRate),
                            label: "BPM",
                            icon: "heart.fill"
                        )
                    }
                } else {
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
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    @ViewBuilder
    private var calorieGoalResultSection: some View {
        if let target = session.targetCalories, target > 0 {
            let burned = Int(session.caloriesBurned)
            let exceeded = burned >= target
            let superation = burned - target

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: exceeded ? "flame.circle.fill" : "target")
                        .foregroundStyle(exceeded ? .orange : AppTheme.accentSecondary)
                    Text("Meta de calorias")
                        .font(.headline)
                }

                HStack {
                    Text("\(burned) / \(target) kcal")
                        .font(.title3.bold())
                        .foregroundStyle(exceeded ? .orange : AppTheme.textPrimary)
                    Spacer()
                    Text(exceeded ? "Atingida" : "Parcial")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(exceeded ? .green : AppTheme.textSecondary)
                }

                ProgressView(value: min(Double(burned) / Double(target), 1.0))
                    .tint(exceeded ? .orange : AppTheme.accentSecondary)

                if superation > 0 {
                    Text(MotivationMessages.cardioCalorieExceededMessage(
                        currentCalories: burned,
                        targetCalories: target
                    ))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    @ViewBuilder
    private var marathonPerformanceSection: some View {
        if let report = marathonReport {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "figure.run.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                    Text("Performance Maratona")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                }

                HStack(spacing: 16) {
                    SummaryStat(
                        value: String(format: "%.2f km", report.distanceKm),
                        label: "Percorridos",
                        icon: "map.fill"
                    )
                    SummaryStat(
                        value: report.formattedTime,
                        label: "Tempo",
                        icon: "clock.fill"
                    )
                    SummaryStat(
                        value: report.formattedPace.replacingOccurrences(of: " /km", with: ""),
                        label: "Ritmo",
                        icon: "speedometer"
                    )
                }

                Divider().background(Color.white.opacity(0.1))

                HStack {
                    Label("Meta \(String(format: "%.0f", report.targetDistanceKm)) km", systemImage: "target")
                    Spacer()
                    Text(report.goalReached ? "Atingida" : "Parcial")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(report.goalReached ? .green : AppTheme.accentSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Projeções com este ritmo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack {
                        Label("Meia (21,1 km)", systemImage: "flag.checkered")
                        Spacer()
                        Text(report.formattedHalfMarathonProjection)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                    }
                    HStack {
                        Label("Maratona (42,2 km)", systemImage: "trophy.fill")
                        Spacer()
                        Text(report.formattedMarathonProjection)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                HStack {
                    Label("Volume semanal", systemImage: "calendar")
                    Spacer()
                    Text(String(format: "%.1f km", report.weeklyRunningKm))
                        .font(.subheadline.weight(.semibold))
                }

                if let previous = report.previousBestSeconds, let delta = report.improvementSeconds {
                    HStack {
                        Label("Melhor marca anterior", systemImage: "medal.fill")
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(PaceFormatting.formatDuration(seconds: previous))
                                .font(.subheadline.weight(.semibold))
                            if delta < 0 {
                                Text("Novo recorde! −\(abs(delta / 60)) min")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                            } else if delta > 0 {
                                Text("+\(delta / 60) min vs recorde")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            } else {
                                Text("Empate com recorde")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.accentSecondary)
                            }
                        }
                    }
                }

                Text(report.readinessMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 4)

                if !report.coachingTips.isEmpty {
                    Divider().background(Color.white.opacity(0.1))
                    Text("Orientações")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    ForEach(report.coachingTips, id: \.self) { tip in
                        Label(tip, systemImage: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    @ViewBuilder
    private var preWorkoutSection: some View {
        if session.tookPreWorkout != nil || !preWorkoutHistory.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pré-treino")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                if let tookPreWorkout = session.tookPreWorkout {
                    HStack {
                        Label("Neste treino", systemImage: "bolt.fill")
                        Spacer()
                        Text(tookPreWorkout ? "Sim, tomei" : "Não tomei")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tookPreWorkout ? AppTheme.accent : AppTheme.textSecondary)
                    }
                }

                HStack {
                    Label("Usou pré-treino", systemImage: "checkmark.circle.fill")
                    Spacer()
                    Text("\(lifetimePreWorkoutSummary.usedCount)x")
                        .font(.subheadline.weight(.semibold))
                }

                HStack {
                    Label("Não usou", systemImage: "xmark.circle.fill")
                    Spacer()
                    Text("\(lifetimePreWorkoutSummary.notUsedCount)x")
                        .font(.subheadline.weight(.semibold))
                }

                if !preWorkoutHistory.isEmpty {
                    Divider().background(Color.white.opacity(0.1))
                    Text("Todas as respostas")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)

                    ForEach(preWorkoutHistory) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.workoutTitle)
                                    .font(.caption.weight(.medium))
                                Text(entry.date, format: .dateTime.day().month().hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Text(entry.tookPreWorkout ? "Sim" : "Não")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(entry.tookPreWorkout ? AppTheme.accent : AppTheme.textSecondary)
                        }
                    }
                }
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    private var preWorkoutHistory: [PreWorkoutSessionEntry] {
        WorkoutReportBuilder.preWorkoutEntries(from: workoutStore.sessionHistory)
    }

    private var lifetimePreWorkoutSummary: PreWorkoutUsageSummary {
        PreWorkoutUsageSummary.from(sessions: workoutStore.sessionHistory)
    }

    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isCardioSession ? "Detalhes do Cardio" : "Tempo por Exercício")
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
                        if let weightLabel = record.weightComparisonLabel {
                            Text(weightLabel)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
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

    @ViewBuilder
    private var totalsSection: some View {
        if !isCardioSession {
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
