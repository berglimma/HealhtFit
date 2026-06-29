import SwiftUI

struct DailyWellnessCheckInView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var wellnessService: DailyWellnessService
    @Environment(\.dismiss) private var dismiss

    @State private var sleepFeedback: SleepAssessment?

    private var user: UserProfile? {
        authService.currentUser
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    sleepSection
                    if let feedback = sleepFeedback {
                        sleepFeedbackCard(feedback)
                    }
                    if let user {
                        waterSection(for: user)
                    }
                    saveButton
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Check-in diário")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Depois") {
                        wellnessService.showSleepCheckIn = false
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Quantas horas você dormiu?", systemImage: "moon.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Informe seu sono da noite passada para acompanharmos sua recuperação.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 8) {
                Text(String(format: "%.1f h", wellnessService.pendingSleepHours))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.accent)

                Slider(value: $wellnessService.pendingSleepHours, in: 0...12, step: 0.5)
                    .tint(AppTheme.accent)

                HStack {
                    Text("0h")
                    Spacer()
                    Text("12h")
                }
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    private func sleepFeedbackCard(_ assessment: SleepAssessment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: assessment.icon)
                .font(.title2)
                .foregroundStyle(assessment.color)

            VStack(alignment: .leading, spacing: 6) {
                Text(assessment.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(assessment.message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(assessment.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func waterSection(for user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Hidratação diária", systemImage: "drop.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Com base no seu peso (\(String(format: "%.1f", user.weight)) kg), beba:")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                Text(String(format: "%.1f L por dia", user.recommendedDailyWaterLiters))
                    .font(.title2.bold())
                    .foregroundStyle(.blue)

                Text("Equivale a cerca de \(user.recommendedWaterGlasses) copos de 250 ml.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    private var saveButton: some View {
        Group {
            if sleepFeedback != nil {
                Button {
                    wellnessService.showSleepCheckIn = false
                    dismiss()
                } label: {
                    Label("Continuar", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {
                    let hours = wellnessService.pendingSleepHours
                    wellnessService.logSleep(hours: hours)
                    sleepFeedback = SleepAssessment.evaluate(hours: hours)
                } label: {
                    Label("Registrar sono", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}
