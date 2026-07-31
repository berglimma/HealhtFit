import SwiftUI

// MARK: - Navigation routes

struct GuidedLevelRoute: Hashable {
    let level: WorkoutLevel
    let gender: Gender
}

struct GuidedFocusRoute: Hashable {
    let focus: WorkoutFocus
    let gender: Gender
}

// MARK: - Sections used in GenderWorkoutHubView

struct GuidedWorkoutSections: View {
    let gender: Gender

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            guidedSection(
                title: "Séries por nível",
                subtitle: "Escolha a intensidade e abra as fichas guiadas"
            ) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(WorkoutLevel.allCases) { level in
                        NavigationLink(value: GuidedLevelRoute(level: level, gender: gender)) {
                            GuidedCategoryCard(
                                title: level.pluralTitle,
                                subtitle: level.subtitle,
                                icon: level.icon,
                                accent: level.accentColor,
                                count: GuidedWorkoutCatalog.templates(for: level).count
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            guidedSection(
                title: "Foco do treino",
                subtitle: "Ao selecionar uma ficha, o cardápio é ajustado ao objetivo"
            ) {
                LazyVStack(spacing: 10) {
                    ForEach(WorkoutFocus.allCases) { focus in
                        NavigationLink(value: GuidedFocusRoute(focus: focus, gender: gender)) {
                            GuidedCategoryCard(
                                title: focus.shortTitle,
                                subtitle: focus.subtitle,
                                icon: focus.icon,
                                accent: focus.accentColor,
                                count: GuidedWorkoutCatalog.templates(for: focus).count,
                                compact: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func guidedSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
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
            content()
        }
    }
}

struct GuidedCategoryCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    var count: Int = 0
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accent.opacity(0.18))
                    .frame(width: compact ? 44 : 48, height: compact ? 44 : 48)
                Image(systemName: icon)
                    .font(compact ? .body : .title3)
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(compact ? .subheadline.weight(.semibold) : .headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(compact ? 2 : 3)
                    .fixedSize(horizontal: false, vertical: true)
                if count > 0 {
                    Text("\(count) ficha\(count == 1 ? "" : "s")")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(compact ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

// MARK: - Category detail (list of templates)

struct GuidedWorkoutCategoryView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var trainingNutritionSync: TrainingNutritionSyncService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let subtitle: String
    let accent: Color
    let templates: [GuidedWorkoutTemplate]
    let gender: Gender

    @State private var nutritionFeedback: String?
    @State private var showNutritionAlert = false
    @State private var pendingSheet: WorkoutSheet?
    @State private var sheetToOpen: WorkoutSheet?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                Text("Ao escolher uma ficha, ela entra nos seus treinos e o cardápio é alinhado ao foco.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVStack(spacing: 12) {
                    ForEach(templates) { template in
                        Button {
                            selectTemplate(template)
                        } label: {
                            GuidedTemplateCard(template: template, accent: accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            for template in templates {
                _ = workoutStore.ensureGuidedWorkoutSheet(template, gender: gender)
            }
        }
        .navigationDestination(item: $sheetToOpen) { sheet in
            WorkoutDetailView(sheet: sheet)
        }
        .alert("Cardápio atualizado", isPresented: $showNutritionAlert) {
            Button("Ver treino") {
                sheetToOpen = pendingSheet
            }
            Button("OK", role: .cancel) {
                sheetToOpen = pendingSheet
            }
        } message: {
            Text(nutritionFeedback ?? "Cardápio ajustado ao treino selecionado.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func selectTemplate(_ template: GuidedWorkoutTemplate) {
        let sheet = workoutStore.ensureGuidedWorkoutSheet(template, gender: gender)
        let message = trainingNutritionSync.applySelection(
            template: template,
            authService: authService,
            mealPlanService: mealPlanService
        )
        nutritionFeedback = message
        pendingSheet = sheet
        showNutritionAlert = true
    }
}

struct GuidedTemplateCard: View {
    let template: GuidedWorkoutTemplate
    let accent: Color

    private var sheetPreview: WorkoutSheet {
        template.makeSheet()
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: template.focus?.icon ?? template.level?.icon ?? "dumbbell.fill")
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(template.title.replacingOccurrences(of: "Guiado — ", with: ""))
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(template.description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label("\(sheetPreview.totalExercises) exercícios", systemImage: "list.bullet")
                    Label("~\(max(sheetPreview.estimatedDuration / 60, 1)) min", systemImage: "clock")
                    if let level = template.level {
                        Text(level.rawValue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(level.accentColor.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}
