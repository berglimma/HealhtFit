import SwiftUI

private enum WorkoutSection: String, CaseIterable, Identifiable {
    case strength = "Musculação"
    case cardio = "Cardio"
    case meditation = "Meditação"

    var id: String { rawValue }
}

struct WorkoutListView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showCreateWorkout = false
    @State private var sheetToEdit: WorkoutSheet?
    @State private var sheetPendingDeletion: WorkoutSheet?
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
                    case .meditation:
                        meditationSection
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
            .navigationDestination(for: MeditationTopic.self) { topic in
                MeditationSetupView(topic: topic)
            }
            .sheet(isPresented: $showCreateWorkout) {
                CreateWorkoutView()
            }
            .sheet(item: $sheetToEdit) { sheet in
                CreateWorkoutView(editingSheet: sheet)
            }
            .alert("Excluir treino?", isPresented: deletionAlertBinding) {
                Button("Excluir", role: .destructive) {
                    if let sheet = sheetPendingDeletion {
                        workoutStore.deleteWorkoutSheet(sheet)
                    }
                    sheetPendingDeletion = nil
                }
                Button("Cancelar", role: .cancel) {
                    sheetPendingDeletion = nil
                }
            } message: {
                if let sheet = sheetPendingDeletion {
                    Text("“\(sheet.title)” será removido permanentemente.")
                }
            }
        }
    }

    private var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { sheetPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    sheetPendingDeletion = nil
                }
            }
        )
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
        VStack(alignment: .leading, spacing: 20) {
            workoutGroupSection(
                title: "Treinos Padrão",
                subtitle: "Fichas A, B, C e D do app",
                sheets: workoutStore.standardWorkoutSheets
            )

            workoutGroupSection(
                title: "Treinos Personalizados",
                subtitle: "Treino criado especialmente pra você",
                sheets: workoutStore.customWorkoutSheets,
                emptyMessage: "Nenhum treino personalizado ainda. Toque em + para criar o seu."
            )
        }
    }

    private func workoutGroupSection(
        title: String,
        subtitle: String,
        sheets: [WorkoutSheet],
        emptyMessage: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if sheets.isEmpty, let emptyMessage {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sheets) { sheet in
                        workoutSheetRow(sheet)
                    }
                }
            }
        }
    }

    private func workoutSheetRow(_ sheet: WorkoutSheet) -> some View {
        NavigationLink(value: sheet) {
            WorkoutSheetCard(
                sheet: sheet,
                showsPersonalBadge: false
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if workoutStore.canModify(sheet) {
                Button {
                    sheetToEdit = sheet
                } label: {
                    Label("Editar", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    sheetPendingDeletion = sheet
                } label: {
                    Label("Excluir", systemImage: "trash")
                }
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

    private var meditationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Escolha um tópico e a duração da sessão")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            LazyVStack(spacing: 12) {
                ForEach(MeditationTopic.catalog) { topic in
                    NavigationLink(value: topic) {
                        MeditationTopicCard(topic: topic)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct WorkoutSheetCard: View {
    let sheet: WorkoutSheet
    var showsPersonalBadge = false

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
                HStack(spacing: 6) {
                    Text(sheet.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    if showsPersonalBadge {
                        Text("Personalizado")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(sheet.description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
