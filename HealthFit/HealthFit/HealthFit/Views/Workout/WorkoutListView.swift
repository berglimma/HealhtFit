import SwiftUI

private enum WorkoutSection: String, CaseIterable, Identifiable {
    case strength = "Musculação"
    case home = "Treine em Casa"
    case cardio = "Cardio"
    case meditation = "Meditação"

    var id: String { rawValue }
}

struct WorkoutListView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showCreateWorkout = false
    @State private var createTargetGender: Gender = .male
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
                    case .home:
                        homeSection
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
            .navigationDestination(for: WorkoutSheet.self) { sheet in
                WorkoutDetailView(sheet: sheet)
            }
            .navigationDestination(for: Gender.self) { gender in
                GenderWorkoutHubView(gender: gender) { targetGender in
                    createTargetGender = targetGender
                    showCreateWorkout = true
                }
            }
            .navigationDestination(for: HomeWorkoutHubRoute.self) { _ in
                HomeWorkoutHubView()
            }
            .navigationDestination(for: MobilityWorkoutHubRoute.self) { _ in
                MobilityWorkoutHubView()
            }
            .navigationDestination(for: CardioExercise.self) { exercise in
                CardioSetupView(exercise: exercise)
            }
            .navigationDestination(for: MeditationTopic.self) { topic in
                MeditationSetupView(topic: topic)
            }
            .sheet(isPresented: $showCreateWorkout) {
                CreateWorkoutView(initialTargetGender: createTargetGender)
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

    private var homeSection: some View {
        VStack(spacing: 16) {
            Text("Treinos com peso corporal — sem academia")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            NavigationLink(value: HomeWorkoutHubRoute()) {
                HomeProgramHeroCard(
                    recommendedCount: workoutStore.homeStandardWorkoutSheets.count
                )
            }
            .buttonStyle(.plain)

            Text("Cada ficha inclui demos em vídeo/GIF dos exercícios durante o treino.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var strengthSection: some View {
        VStack(spacing: 16) {
            Text("Escolha o programa")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            NavigationLink(value: Gender.male) {
                GenderProgramHeroCard(
                    gender: .male,
                    recommendedCount: workoutStore.maleStandardWorkoutSheets.count,
                    customCount: workoutStore.customWorkoutSheets(for: .male).count
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: Gender.female) {
                GenderProgramHeroCard(
                    gender: .female,
                    recommendedCount: workoutStore.femaleStandardWorkoutSheets.count,
                    customCount: workoutStore.customWorkoutSheets(for: .female).count
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: MobilityWorkoutHubRoute()) {
                MobilityProgramHeroCard(
                    recommendedCount: workoutStore.mobilityStandardWorkoutSheets.count
                )
            }
            .buttonStyle(.plain)

            Text("Mobilidade ajuda a preparar articulações para agachamento, terra, supino e desenvolvimento.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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

struct HomeWorkoutHubRoute: Hashable {}
struct MobilityWorkoutHubRoute: Hashable {}

struct HomeProgramHeroCard: View {
    let recommendedCount: Int

    private let accent = Color(red: 0.35, green: 0.72, blue: 0.55)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.28, blue: 0.22),
                    Color(red: 0.06, green: 0.12, blue: 0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative circles
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 160, height: 160)
                .offset(x: 180, y: -40)

            VStack(alignment: .leading, spacing: 8) {
                Label("SEM EQUIPAMENTOS", systemImage: "house.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)

                Text("TREINE EM CASA")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Full body, core, HIIT, pernas e superiores com demos")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))

                Label("\(recommendedCount) fichas recomendadas", systemImage: "star.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(accent.opacity(0.45), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct HomeWorkoutHubView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var recommendedSheets: [WorkoutSheet] {
        workoutStore.homeStandardWorkoutSheets
    }

    private let accent = Color(red: 0.35, green: 0.72, blue: 0.55)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hubHeader

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recomendados")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Fichas de peso corporal com demonstrações durante o treino")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(recommendedSheets) { sheet in
                            NavigationLink(value: sheet) {
                                WorkoutSheetCard(sheet: sheet, iconSystemName: "house.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle("Treine em Casa")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hubHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "house.fill")
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("TREINE EM CASA")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(recommendedSheets.count) fichas · peso corporal · demos em vídeo")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct MobilityProgramHeroCard: View {
    let recommendedCount: Int

    private let accent = Color(red: 0.45, green: 0.65, blue: 0.95)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image("WorkoutProgramMobility")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Label("PARA MUSCULAÇÃO", systemImage: "figure.flexibility")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)

                Text("MOBILIDADE")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Aquecimento, quadril, ombros e pós-treino com demos")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))

                Label("\(recommendedCount) fichas recomendadas", systemImage: "star.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(accent.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(accent.opacity(0.45), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct MobilityWorkoutHubView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var recommendedSheets: [WorkoutSheet] {
        workoutStore.mobilityStandardWorkoutSheets
    }

    private let accent = Color(red: 0.45, green: 0.65, blue: 0.95)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hubHeader

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recomendados")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Rotinas de mobilidade voltadas à musculação, com GIFs na execução")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(recommendedSheets) { sheet in
                            NavigationLink(value: sheet) {
                                WorkoutSheetCard(sheet: sheet, iconSystemName: "figure.flexibility")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle("Mobilidade")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hubHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.flexibility")
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("MOBILIDADE")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(recommendedSheets.count) fichas · preparo para carga · demos em GIF")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct GenderProgramHeroCard: View {
    let gender: Gender
    let recommendedCount: Int
    let customCount: Int

    private var title: String {
        gender == .female ? "FEMININO" : "MASCULINO"
    }

    private var subtitle: String {
        gender == .female
            ? "Glúteos, pernas, postura e core"
            : "Peito, costas, pernas e ombros"
    }

    private var imageName: String {
        gender == .female ? "WorkoutProgramFemale" : "WorkoutProgramMale"
    }

    private var accent: Color {
        gender == .female ? Color(red: 0.86, green: 0.45, blue: 0.58) : AppTheme.accent
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))

                HStack(spacing: 10) {
                    Label("\(recommendedCount) recomendados", systemImage: "star.fill")
                    Label("\(customCount) personalizados", systemImage: "person.crop.circle")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(accent.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(accent.opacity(0.45), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct GenderWorkoutHubView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let gender: Gender
    var onCreateCustom: (Gender) -> Void

    @State private var sheetToEdit: WorkoutSheet?
    @State private var sheetPendingDeletion: WorkoutSheet?

    private var title: String {
        gender == .female ? "Programa Feminino" : "Programa Masculino"
    }

    private var accent: Color {
        gender == .female ? Color(red: 0.86, green: 0.45, blue: 0.58) : AppTheme.accent
    }

    private var recommendedSheets: [WorkoutSheet] {
        workoutStore.recommendedStandardWorkouts(for: gender)
    }

    private var customSheets: [WorkoutSheet] {
        workoutStore.customWorkoutSheets(for: gender)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hubHeader

                workoutGroupSection(
                    title: "Recomendados",
                    subtitle: "Fichas padrão do programa \(gender == .female ? "feminino" : "masculino")",
                    sheets: recommendedSheets
                )

                workoutGroupSection(
                    title: "Personalizados",
                    subtitle: "Treinos criados para este programa",
                    sheets: customSheets,
                    emptyMessage: "Nenhum personalizado ainda. Toque em + para criar."
                )
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onCreateCustom(gender)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            }
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

    private var hubHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: gender == .female ? "figure.strengthtraining.traditional" : "dumbbell.fill")
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(gender == .female ? "FEMININO" : "MASCULINO")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(recommendedSheets.count) recomendados · \(customSheets.count) personalizados")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
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
                showsPersonalBadge: workoutStore.canModify(sheet)
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
}

struct WorkoutSheetCard: View {
    let sheet: WorkoutSheet
    var showsPersonalBadge = false
    var iconSystemName: String?

    private var resolvedIcon: String {
        if let iconSystemName { return iconSystemName }
        if sheet.createdByAssistant { return "bubble.left.and.bubble.right.fill" }
        if sheet.title.lowercased().hasPrefix("casa") { return "house.fill" }
        if sheet.title.lowercased().hasPrefix("mobilidade") { return "figure.flexibility" }
        return "dumbbell.fill"
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: resolvedIcon)
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(sheet.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    if sheet.createdByAssistant {
                        Text("IAssistente")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 0.35, green: 0.55, blue: 0.95))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.15))
                            .clipShape(Capsule())
                    } else if showsPersonalBadge {
                        Text("Personalizado")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.accent.opacity(0.15))
                            .clipShape(Capsule())
                    } else if sheet.title.lowercased().hasPrefix("casa") {
                        Text("Treine em Casa")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 0.35, green: 0.72, blue: 0.55))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.35, green: 0.72, blue: 0.55).opacity(0.15))
                            .clipShape(Capsule())
                    } else if sheet.title.lowercased().hasPrefix("mobilidade") {
                        Text("Mobilidade")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 0.45, green: 0.65, blue: 0.95))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.45, green: 0.65, blue: 0.95).opacity(0.15))
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
