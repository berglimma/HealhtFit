import SwiftUI

struct WorkoutOfTheDayCard: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var coach = CoachService.shared

    @EnvironmentObject var wellnessService: DailyWellnessService

    @State private var sheetToOpen: WorkoutSheet?
    @State private var showGenderPicker = false

    private var profileGender: Gender {
        authService.currentUser?.gender ?? .male
    }

    private var coverImageName: String {
        profileGender == .female ? "WorkoutProgramFemale" : "WorkoutProgramMale"
    }

    private var hasPersonalTrainer: Bool {
        if coach.activePersonalLink != nil { return true }
        guard let user = authService.currentUser else { return false }
        return user.hasPersonalTrainerOnProfile || user.hasPersonalTrainer
    }

    private var personalDisplayName: String? {
        if let name = coach.activePersonalLink?.coachName,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        let profileName = authService.currentUser?.personalTrainerName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return profileName.isEmpty ? nil : profileName
    }

    private var coachRestWeekdays: [Int] {
        coach.activePersonalLink?.restWeekdays ?? []
    }

    private var suggestion: WorkoutOfTheDaySuggestion? {
        let gender = profileGender
        var candidates: [WorkoutSheet] = []
        candidates += workoutStore.recommendedStandardWorkouts(for: gender)
        candidates += workoutStore.atletaStandardWorkouts(for: gender)
        candidates += workoutStore.militarStandardWorkouts(for: gender)
        candidates += workoutStore.shapeStandardWorkouts(for: gender)
        candidates += workoutStore.customWorkoutSheets(for: gender)
        candidates += workoutStore.workoutSheets.filter { $0.isCoachPrescribed && $0.isActive }
        return WorkoutDaySuggestionAnalyzer.suggestWorkoutOfTheDay(
            sessions: workoutStore.sessionHistory,
            candidateSheets: candidates,
            sheetsCatalog: workoutStore.workoutSheets,
            hasPersonalTrainer: hasPersonalTrainer,
            personalName: personalDisplayName,
            coachRestWeekdays: coachRestWeekdays
        )
    }

    var body: some View {
        Group {
            if let suggestion {
                cardContent(suggestion)
            } else {
                emptyCard
            }
        }
        .sheet(item: $sheetToOpen) { sheet in
            NavigationStack {
                WorkoutDetailView(sheet: sheet)
            }
        }
        .confirmationDialog(
            "Escolher programa de musculação",
            isPresented: $showGenderPicker,
            titleVisibility: .visible
        ) {
            Button(profileGender == .male ? "Masculino (seu perfil)" : "Masculino") {
                openMusculacaoHub(gender: .male)
            }
            Button(profileGender == .female ? "Feminino (seu perfil)" : "Feminino") {
                openMusculacaoHub(gender: .female)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Abrimos o programa do seu perfil por padrão. Você pode trocar quando quiser.")
        }
    }

    private func cardContent(_ suggestion: WorkoutOfTheDaySuggestion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                CoverAssetImage(name: coverImageName, maxPixel: 720)
                    .frame(maxWidth: .infinity)
                    .frame(height: 168)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        eyebrow(for: suggestion),
                        systemImage: eyebrowIcon(for: suggestion)
                    )
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.accent)

                    Text(suggestion.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)

                    Text(suggestionLabel(for: suggestion))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                }
                .padding(16)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text(suggestion.reason)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if suggestion.isRestDay {
                    restActions(suggestion)
                } else if let sheet = suggestion.sheet {
                    workoutActions(suggestion, sheet: sheet)
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    AppTheme.accent.opacity(0.35),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func restActions(_ suggestion: WorkoutOfTheDaySuggestion) -> some View {
        HStack(spacing: 10) {
            metricPill(icon: "bed.double.fill", text: "Recuperação")
            metricPill(icon: "heart.fill", text: "Sono · mobilidade")
            Spacer(minLength: 0)
        }

        VStack(spacing: 10) {
            if !wellnessService.isTodayRestDay {
                Button {
                    wellnessService.setRestDay(on: .now, rest: true)
                } label: {
                    Text(
                        suggestion.source == .coachRest
                            ? "Confirmar descanso do personal"
                            : "Marcar descanso hoje"
                    )
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Label("Descanso marcado na constância", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                showGenderPicker = true
            } label: {
                Text("Treinar mesmo assim")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent.opacity(0.16))
                    .foregroundStyle(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                WorkoutHubNavigationRouter.shared.openCardio()
            } label: {
                Label("Cardio leve / caminhada", systemImage: "figure.walk")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cyan.opacity(0.16))
                    .foregroundStyle(Color.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func workoutActions(_ suggestion: WorkoutOfTheDaySuggestion, sheet: WorkoutSheet) -> some View {
        if !suggestion.focusMuscles.isEmpty {
            HStack(spacing: 8) {
                ForEach(suggestion.focusMuscles, id: \.self) { muscle in
                    Label(muscle.rawValue, systemImage: muscle.icon)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.14))
                        .foregroundStyle(AppTheme.accent)
                        .clipShape(Capsule())
                }
            }
        }

        HStack(spacing: 10) {
            metricPill(
                icon: "dumbbell.fill",
                text: "\(sheet.exercises.count) exercícios"
            )
            metricPill(
                icon: "clock.fill",
                text: estimatedMinutes(for: sheet)
            )
            Spacer(minLength: 0)
        }

        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    sheetToOpen = sheet
                } label: {
                    Text("Abrir sugestão")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    showGenderPicker = true
                } label: {
                    Text("Escolher treino")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.accent.opacity(0.16))
                        .foregroundStyle(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button {
                WorkoutHubNavigationRouter.shared.openCardio()
            } label: {
                Label("Realizar cardio", systemImage: "figure.run")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cyan.opacity(0.16))
                    .foregroundStyle(Color.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                CoverAssetImage(name: coverImageName, maxPixel: 720)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.1), .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("TREINO DO DIA")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                    Text("Sem fichas disponíveis")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                .padding(16)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Crie ou abra um programa em Treinos para receber a sugestão do dia.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                VStack(spacing: 10) {
                    Button {
                        showGenderPicker = true
                    } label: {
                        Text("Escolher treino")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        WorkoutHubNavigationRouter.shared.openCardio()
                    } label: {
                        Label("Realizar cardio", systemImage: "figure.run")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.cyan.opacity(0.16))
                            .foregroundStyle(Color.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func eyebrow(for suggestion: WorkoutOfTheDaySuggestion) -> String {
        switch suggestion.source {
        case .coachRest:
            return "DESCANSO · PERSONAL"
        case .routineRest:
            return "DESCANSO · RECUPERAÇÃO"
        case .coachRoutine:
            return "TREINO DO DIA · PERSONAL"
        case .userHistory:
            return "TREINO DO DIA"
        }
    }

    private func eyebrowIcon(for suggestion: WorkoutOfTheDaySuggestion) -> String {
        if suggestion.isRestDay { return "bed.double.fill" }
        return suggestion.isFromCoach ? "person.badge.shield.checkmark.fill" : "sparkles"
    }

    private func suggestionLabel(for suggestion: WorkoutOfTheDaySuggestion) -> String {
        switch suggestion.source {
        case .coachRest:
            return "Rotina do personal · dia livre"
        case .routineRest:
            return "Sugestão de recuperação"
        case .coachRoutine:
            if suggestion.focusMuscles.isEmpty {
                return "Rotina do personal"
            }
            let names = suggestion.focusMuscles.map(\.rawValue).joined(separator: " · ")
            return "Rotina do personal · \(names)"
        case .userHistory:
            if suggestion.focusMuscles.isEmpty {
                return "Sugestão com base no seu histórico"
            }
            let names = suggestion.focusMuscles.map(\.rawValue).joined(separator: " · ")
            return "Sugestão · foco em \(names)"
        }
    }

    private func openMusculacaoHub(gender: Gender) {
        WorkoutHubNavigationRouter.shared.openGenderHub(gender: gender, section: .recommended)
    }

    private func metricPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(AppTheme.textSecondary)
    }

    private func estimatedMinutes(for sheet: WorkoutSheet) -> String {
        let sets = sheet.exercises.reduce(0) { $0 + max($1.sets, 1) }
        let minutes = max(20, sets * 2)
        return "~\(minutes) min"
    }
}
