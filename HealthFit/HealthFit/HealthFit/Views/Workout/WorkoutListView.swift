import SwiftUI

private enum WorkoutSection: String, CaseIterable, Identifiable {
    case strength = "Musculação"
    case cardio = "Cardio"

    var id: String { rawValue }
}

struct WorkoutListView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showCreateWorkout = false
    @State private var selectedSection: WorkoutSection = .strength

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    sectionPicker

                    if let session = workoutStore.activeSession {
                        ActiveWorkoutBanner(session: session)
                    }

                    switch selectedSection {
                    case .strength:
                        strengthSection
                    case .cardio:
                        cardioSection
                    }
                }
                .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .adaptiveContentWidth()
            }
            .background(AppTheme.background)
            .navigationTitle("Treinos")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if selectedSection == .strength {
                        Button {
                            showCreateWorkout = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
            }
            .navigationDestination(for: WorkoutSheet.self) { sheet in
                WorkoutDetailView(sheet: sheet)
            }
            .navigationDestination(for: CardioExercise.self) { exercise in
                CardioSetupView(exercise: exercise)
            }
            .sheet(isPresented: $showCreateWorkout) {
                CreateWorkoutView()
            }
        }
    }

    private var sectionPicker: some View {
        Picker("Seção", selection: $selectedSection) {
            ForEach(WorkoutSection.allCases) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
    }

    private var strengthSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(workoutStore.workoutSheets) { sheet in
                NavigationLink(value: sheet) {
                    WorkoutSheetCard(sheet: sheet)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cardioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Escolha um exercício e defina a intensidade")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            LazyVStack(spacing: 12) {
                ForEach(CardioExercise.catalog) { exercise in
                    NavigationLink(value: exercise) {
                        CardioExerciseCard(exercise: exercise)
                    }
                    .buttonStyle(.plain)
                }
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
