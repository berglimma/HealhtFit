import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var wellnessService: DailyWellnessService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @State var sheet: WorkoutSheet
    @State private var showVision = false
    @State private var showPreWorkoutPrompt = false
    @State private var showStartingExercisePicker = false
    @State private var pendingTookPreWorkout: Bool?
    @State private var selectedStartingExerciseIndex = 0
    @State private var showEditWorkout = false
    @State private var showDeleteConfirmation = false
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
        .fullScreenCover(isPresented: $showVision) {
            VisionWorkoutView()
        }
        .confirmationDialog(
            "Pré-treino",
            isPresented: $showPreWorkoutPrompt,
            titleVisibility: .visible
        ) {
            Button("Sim, tomei") {
                presentStartingExercisePicker(tookPreWorkout: true)
            }
            Button("Não tomei") {
                presentStartingExercisePicker(tookPreWorkout: false)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Você tomou pré-treino antes deste treino? \(SupplementGuidance.preWorkoutCaffeineLimit.capitalized).")
        }
        .sheet(isPresented: $showStartingExercisePicker) {
            StartingExercisePickerSheet(
                exercises: sheet.exercises,
                selectedIndex: $selectedStartingExerciseIndex,
                onCancel: {
                    showStartingExercisePicker = false
                    pendingTookPreWorkout = nil
                },
                onStart: {
                    let tookPreWorkout = pendingTookPreWorkout ?? false
                    showStartingExercisePicker = false
                    beginWorkout(
                        tookPreWorkout: tookPreWorkout,
                        startingExerciseIndex: selectedStartingExerciseIndex
                    )
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var overviewSection: some View {
        VStack(spacing: 12) {
            if sheet.createdByAssistant {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundStyle(Color(red: 0.35, green: 0.55, blue: 0.95))
                    Text("Gerado pelo IAssistente — sugestão educativa. É essencial consultar um profissional de Educação Física antes de seguir esta ficha.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 16) {
                StatPill(value: "\(sheet.totalExercises)", label: "Exercícios", icon: "list.bullet")
                StatPill(value: "~\(sheet.estimatedDuration / 60)", label: "Minutos", icon: "clock")
                StatPill(value: "\(sheet.exercises.reduce(0) { $0 + $1.sets })", label: "Séries", icon: "repeat")
            }
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercícios")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(Array(sheet.exercises.enumerated()), id: \.element.id) { index, exercise in
                ExerciseRow(
                    index: index + 1,
                    exercise: exercise,
                    preferredGender: sheet.resolvedProgramGender
                )
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

    private func presentStartingExercisePicker(tookPreWorkout: Bool) {
        pendingTookPreWorkout = tookPreWorkout
        selectedStartingExerciseIndex = 0
        if sheet.exercises.count <= 1 {
            beginWorkout(tookPreWorkout: tookPreWorkout, startingExerciseIndex: 0)
        } else {
            showStartingExercisePicker = true
        }
    }

    private func beginWorkout(tookPreWorkout: Bool, startingExerciseIndex: Int = 0) {
        workoutStore.startSession(
            for: sheet,
            tookPreWorkout: tookPreWorkout,
            startingExerciseIndex: startingExerciseIndex
        )
        wellnessService.applyPreWorkoutFromWorkouts(allTrackedSessions)
        let startIndex = min(max(0, startingExerciseIndex), max(0, sheet.exercises.count - 1))
        let exerciseName = sheet.exercises.indices.contains(startIndex)
            ? sheet.exercises[startIndex].name
            : (sheet.exercises.first?.name ?? "")
        watchConnectivity.startWorkoutOnWatch(workoutName: sheet.title, exerciseName: exerciseName)
        let athleteName = authService.currentUser?.greetingName ?? "Atleta"
        NotificationService.shared.deliverWorkoutStartNotification(
            workoutTitle: sheet.title,
            athleteName: athleteName
        )
        pendingTookPreWorkout = nil
        workoutStore.resumeActiveWorkout()
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
    var preferredGender: Gender? = nil

    var body: some View {
        DisclosureGroup {
            ExerciseExecutionGuideView(
                steps: exercise.executionGuide,
                exercise: exercise,
                preferredGender: preferredGender
            )
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

private struct StartingExercisePickerSheet: View {
    let exercises: [Exercise]
    @Binding var selectedIndex: Int
    let onCancel: () -> Void
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Escolha com qual exercício deseja começar. Você pode mudar a qualquer momento durante o treino.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                List {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                        Button {
                            selectedIndex = index
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedIndex == index ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIndex == index ? AppTheme.accent : AppTheme.textSecondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("\(exercise.sets)x\(exercise.reps) · \(exercise.muscleGroup.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }

                                Spacer()

                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)

                Button(action: onStart) {
                    Label("Começar treino", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Começar por")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: onCancel)
                }
            }
        }
    }
}
