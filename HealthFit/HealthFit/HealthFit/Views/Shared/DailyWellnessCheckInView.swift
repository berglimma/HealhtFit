import SwiftUI

struct DailyWellnessCheckInView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var wellnessService: DailyWellnessService
    @Environment(\.dismiss) private var dismiss

    @State private var sleepFeedback: SleepAssessment?
    @State private var didLogWaterGlass = false
    @State private var didRegisterSleepLocally = false

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
            .navigationTitle("Check-in da manhã")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Depois") {
                        wellnessService.dismissMorningCheckIn()
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .onAppear {
                wellnessService.refreshWaterGoal(from: authService.currentUser)
            }
            .onChange(of: wellnessService.todaySleepHours) { _, hours in
                // Sono sincronizado de outro dispositivo/perfil enquanto o sheet pedia registro.
                guard hours != nil, sleepFeedback == nil, !didRegisterSleepLocally else { return }
                wellnessService.showSleepCheckIn = false
                dismiss()
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
            Label("Hidratação", systemImage: "drop.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                Text("Água recomendada")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Com base no seu peso (\(String(format: "%.1f", user.weight)) kg), beba:")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                Text(String(format: "%.1f L por dia", user.recommendedDailyWaterLiters))
                    .font(.title2.bold())
                    .foregroundStyle(.blue)

                Text("Equivale a cerca de \(user.recommendedWaterGlasses) copos de \(WaterServing.glassML) ml ou \(user.recommendedWaterBottles) garrafas de \(WaterServing.bottleML) ml.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                ProgressView(value: wellnessService.waterProgress(for: user))
                    .tint(
                        wellnessService.hasMetWaterGoal(for: user)
                            ? AppTheme.accent
                            : .blue
                    )

                Text("\(wellnessService.todayEntry.waterIntakeMl) ml ingeridos hoje")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Comece o dia com um copo d'água")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Recomendamos beber \(WaterServing.glassML) ml agora para despertar o metabolismo e iniciar a hidratação.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    wellnessService.addWater(WaterServing.glassML)
                    didLogWaterGlass = true
                } label: {
                    Label(
                        didLogWaterGlass ? "Copo registrado (+ \(WaterServing.glassML) ml)" : "Beber 1 copo agora",
                        systemImage: didLogWaterGlass ? "checkmark.circle.fill" : "drop.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(didLogWaterGlass)
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
                    didRegisterSleepLocally = true
                    let hours = wellnessService.pendingSleepHours
                    wellnessService.logSleep(hours: hours)
                    wellnessService.refreshWaterGoal(from: authService.currentUser)
                    sleepFeedback = SleepAssessment.evaluate(hours: hours)
                } label: {
                    Label("Registrar sono", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}
