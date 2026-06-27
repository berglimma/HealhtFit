import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var authService: AuthService
    @State var sheet: WorkoutSheet
    @State private var showActiveWorkout = false
    @State private var showVision = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overviewSection
                exercisesSection
                actionButtons
            }
            .padding(AppTheme.padding)
        }
        .background(AppTheme.background)
        .navigationTitle(sheet.title)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $showActiveWorkout) {
            ActiveWorkoutView(sheet: sheet)
        }
        .sheet(isPresented: $showVision) {
            VisionWorkoutView()
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
                workoutStore.startSession(for: sheet)
                watchConnectivity.startWorkoutOnWatch(workoutName: sheet.title)
                let athleteName = authService.currentUser?.name ?? "Atleta"
                NotificationService.shared.deliverWorkoutStartNotification(
                    workoutTitle: sheet.title,
                    athleteName: athleteName
                )
                showActiveWorkout = true
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
                    if let weight = exercise.weight {
                        Text("\(Int(weight))kg")
                    }
                    Text("\(exercise.restSeconds)s descanso")
                }
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Image(systemName: exercise.muscleGroup.icon)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
