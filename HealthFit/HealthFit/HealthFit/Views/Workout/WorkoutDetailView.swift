import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var wellnessService: DailyWellnessService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @State var sheet: WorkoutSheet
    @State private var showActiveWorkout = false
    @State private var showVision = false
    @State private var showPreWorkoutPrompt = false
    @State private var showEditWorkout = false
    @State private var showDeleteConfirmation = false
    @State private var shouldPopToWorkoutList = false
    @State private var showRepeatedWorkoutAlert = false
    @State private var repeatedWorkoutSession: WorkoutSession?

    private var canModify: Bool {
        workoutStore.canModify(sheet)
    }

    private var repeatedWorkoutAlertMessage: String {
        guard let session = repeatedWorkoutSession else {
            return "Este treino é o mesmo que o último realizado nas últimas 24 horas."
        }
        let when = session.endedAt ?? session.startedAt
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: when, relativeTo: .now)
        return "Este treino é o mesmo que o último realizado (\(session.workoutTitle), \(relative)). Descansar o mesmo grupo muscular ajuda na recuperação. Deseja continuar mesmo assim?"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overviewSection
                exercisesSection
                actionButtons
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle(sheet.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if canModify {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showEditWorkout = true
                        } label: {
                            Label("Editar ficha", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Excluir ficha", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditWorkout) {
            CreateWorkoutView(editingSheet: sheet)
        }
        .onChange(of: workoutStore.workoutSheets) { _, sheets in
            if let updated = sheets.first(where: { $0.id == sheet.id }) {
                sheet = updated
            }
        }
        .alert("Excluir treino?", isPresented: $showDeleteConfirmation) {
            Button("Excluir", role: .destructive) {
                workoutStore.deleteWorkoutSheet(sheet)
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("“\(sheet.title)” será removido permanentemente.")
        }
        .alert("Treino repetido", isPresented: $showRepeatedWorkoutAlert) {
            Button("Continuar mesmo assim") {
                showPreWorkoutPrompt = true
            }
            Button("Escolher outro", role: .cancel) {
                repeatedWorkoutSession = nil
            }
        } message: {
            Text(repeatedWorkoutAlertMessage)
        }
        .fullScreenCover(isPresented: $showActiveWorkout, onDismiss: {
            if shouldPopToWorkoutList {
                shouldPopToWorkoutList = false
                dismiss()
            }
        }) {
            ActiveWorkoutView(sheet: sheet) {
                shouldPopToWorkoutList = true
            }
        }
        .sheet(isPresented: $showVision) {
            VisionWorkoutView()
        }
        .confirmationDialog(
            "Pré-treino",
            isPresented: $showPreWorkoutPrompt,
            titleVisibility: .visible
        ) {
            Button("Sim, tomei") {
                beginWorkout(tookPreWorkout: true)
            }
            Button("Não tomei") {
                beginWorkout(tookPreWorkout: false)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Você tomou pré-treino antes deste treino? \(SupplementGuidance.preWorkoutCaffeineLimit.capitalized).")
        }
    }

    private var overviewSection: some View {
        HStack(spacing: 16) {
            StatPill(value: "\(sheet.totalExercises)", label: "Exercícios", icon: "list.bullet")
            StatPill(value: "~\(sheet.estimatedDuration / 60)", label: "Minutos", icon: "clock")
            StatPill(value: "\(sheet.exercises.reduce(0) { $0 + $1.sets })", label: "Séries", icon: "repeat")
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercícios")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(Array(sheet.exercises.enumerated()), id: \.element.id) { index, exercise in
                ExerciseRow(index: index + 1, exercise: exercise)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                requestStartWorkout()
            } label: {
                Label("Iniciar Treino", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                showVision = true
            } label: {
                Label("Câmera com Vision", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func requestStartWorkout() {
        if let repeated = workoutStore.recentSameWorkoutSession(as: sheet) {
            repeatedWorkoutSession = repeated
            showRepeatedWorkoutAlert = true
        } else {
            showPreWorkoutPrompt = true
        }
    }

    private func beginWorkout(tookPreWorkout: Bool) {
        workoutStore.startSession(for: sheet, tookPreWorkout: tookPreWorkout)
        wellnessService.applyPreWorkoutFromWorkouts(allTrackedSessions)
        let firstExercise = sheet.exercises.first?.name ?? ""
        watchConnectivity.startWorkoutOnWatch(workoutName: sheet.title, exerciseName: firstExercise)
        let athleteName = authService.currentUser?.greetingName ?? "Atleta"
        NotificationService.shared.deliverWorkoutStartNotification(
            workoutTitle: sheet.title,
            athleteName: athleteName
        )
        showActiveWorkout = true
    }

    private var allTrackedSessions: [WorkoutSession] {
        var sessions = workoutStore.sessionHistory
        if let activeSession = workoutStore.activeSession {
            sessions.append(activeSession)
        }
        return sessions
    }
}

struct StatPill: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ExerciseRow: View {
    let index: Int
    let exercise: Exercise

    var body: some View {
        DisclosureGroup {
            ExerciseExecutionGuideView(steps: exercise.executionGuide, exercise: exercise)
                .padding(.top, 4)
        } label: {
            HStack(spacing: 14) {
                Text("\(index)")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.accent.opacity(0.2))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    HStack(spacing: 8) {
                        Text("\(exercise.sets)x\(exercise.reps)")
                        Text("Rec. \(exercise.recommendedWeightLabel)")
                        Text("\(exercise.restSeconds)s descanso")
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: exercise.muscleGroup.icon)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .tint(AppTheme.accent)
    }
}
