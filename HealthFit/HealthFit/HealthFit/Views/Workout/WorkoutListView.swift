import SwiftUI

struct WorkoutListView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @State private var showCreateWorkout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let session = workoutStore.activeSession {
                    ActiveWorkoutBanner(session: session)
                        .padding(.horizontal, AppTheme.padding)
                        .padding(.top, 8)
                }

                LazyVStack(spacing: 12) {
                    ForEach(workoutStore.workoutSheets) { sheet in
                        NavigationLink(value: sheet) {
                            WorkoutSheetCard(sheet: sheet)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppTheme.padding)
            }
            .background(AppTheme.background)
            .navigationTitle("Fichas de Treino")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateWorkout = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .navigationDestination(for: WorkoutSheet.self) { sheet in
                WorkoutDetailView(sheet: sheet)
            }
            .sheet(isPresented: $showCreateWorkout) {
                CreateWorkoutView()
            }
        }
    }
}

struct WorkoutSheetCard: View {
    let sheet: WorkoutSheet

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(sheet.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(sheet.description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Label("\(sheet.totalExercises) exercícios", systemImage: "list.bullet")
                    Label("~\(sheet.estimatedDuration / 60) min", systemImage: "clock")
                }
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct ActiveWorkoutBanner: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
            Text("Treino em andamento: \(session.workoutTitle)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text("\(session.completedExercises)/\(session.totalExercises)")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.accent)
        }
        .padding()
        .background(AppTheme.accent.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
