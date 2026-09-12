import SwiftUI
import Charts
import Photos
import UIKit

struct DashboardView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var liveMetrics: LiveMetricsHub
    @EnvironmentObject var weeklyReportService: WeeklyReportService
    @EnvironmentObject var monthlyReportService: MonthlyReportService
    @EnvironmentObject var wellnessService: DailyWellnessService
    @EnvironmentObject var shareCardStore: WorkoutShareCardStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var appUpdateService = AppUpdateService.shared

    @State private var showWeeklyReport = false
    @State private var showMonthlyReport = false
    @State private var selectedRecentSession: WorkoutSession?
    @State private var isSyncingWatch = false
    @State private var watchSyncResult: WatchSyncResult?
    @State private var showWatchSyncAlert = false
    @State private var expandedShareSlot: WorkoutShareCardSlot?
    @State private var fullscreenShareSlot: WorkoutShareCardSlot?
    @State private var suppressShareCardTapAfterLongPress = false
    @State private var isSavingShareCard = false
    @State private var shareCardSaveAlertTitle = ""
    @State private var shareCardSaveAlertMessage = ""
    @State private var showShareCardSaveAlert = false
    /// Charts / HealthKit refresh after first layout — avoids hitching the home paint.
    @State private var showHealthCharts = false
    /// Dia selecionado na faixa semanal (padrão: hoje).
    @State private var selectedWellnessDay: Date = Calendar.current.startOfDay(for: .now)
    @State private var sleepHoursDraft: Double = 7

    /// Live `WorkoutShareCardView` is fixed ~360×464–568; this scale fits dashboard width when expanded.
    private let shareCardExpandedScale: CGFloat = 0.72
    private var shareCardPreviewHeight: CGFloat {
        WorkoutShareCardView.maxPreviewCardHeight * shareCardExpandedScale
    }

    private var healthStatus: WellnessHealthIconStatus {
        wellnessService.healthIconStatus()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    if appUpdateService.pulseFlagsEpoch >= 0, PulseExperimental.isUIEnabled {
                        PulseDashboardCard()
                    }
                    weekDayWellnessSection
                    shareCardsSection
                    metricsRow
                    if showHealthCharts {
                        HealthChartsView()
                    } else {
                        Color.clear.frame(height: 280)
                    }
                    watchSection
                    recentWorkoutsSection
                }
                .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .adaptiveContentWidth()
            }
            .background(AppTheme.background)
            .navigationTitle("Dashboard")
            .task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                showHealthCharts = true
                // Let charts mount before HealthKit batch updates @Published metrics.
                try? await Task.sleep(nanoseconds: 250_000_000)
                await healthKitManager.refreshFromHealthKit()
            }
            .task(id: authService.currentUser?.id) {
                await wellnessService.ensureCurrentWeekLoaded()
                syncSleepDraft(for: selectedWellnessDay)
            }
            .onChange(of: selectedWellnessDay) { _, newDay in
                syncSleepDraft(for: newDay)
            }
            .onChange(of: wellnessService.weekEntriesByDayKey) { _, _ in
                syncSleepDraft(for: selectedWellnessDay)
            }
            .onChange(of: wellnessService.todayEntry) { _, _ in
                syncSleepDraft(for: selectedWellnessDay)
            }
            .refreshable {
                await healthKitManager.refreshFromHealthKit()
                await wellnessService.ensureCurrentWeekLoaded()
            }
            .sheet(isPresented: $showWeeklyReport) {
                WeeklyReportView()
            }
            .sheet(isPresented: $showMonthlyReport) {
                MonthlyReportView()
            }
            .sheet(item: $selectedRecentSession) { session in
                WorkoutSummaryView(
                    session: workoutStore.sessionHistory.first(where: { $0.id == session.id }) ?? session,
                    onFinish: { selectedRecentSession = nil }
                )
            }
            .alert(
                watchSyncResult?.title ?? "Apple Watch",
                isPresented: $showWatchSyncAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(watchSyncResult?.message ?? "")
            }
            .fullScreenCover(item: $fullscreenShareSlot) { slot in
                shareCardFullscreenCover(for: slot)
                    .alert(shareCardSaveAlertTitle, isPresented: $showShareCardSaveAlert) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(shareCardSaveAlertMessage)
                    }
            }
        }
    }

    @ViewBuilder
    private var weekDayWellnessSection: some View {
        let dayKey = DailyWellnessEntry.dayKey(for: selectedWellnessDay)
        let entry = wellnessService.entry(for: dayKey)
        let isToday = Calendar.current.isDateInToday(selectedWellnessDay)
        let waterGoal = authService.currentUser?.recommendedDailyWaterML ?? 2_000
        let sleepHours = entry.sleepHours ?? sleepHoursDraft
        let sleepGoalHours: Double = 8
        let waterPercent = waterGoal > 0
            ? min(Double(entry.waterIntakeMl) / Double(waterGoal), 1)
            : 0

        VStack(alignment: .leading, spacing: 14) {
            weekDayStrip

            sleepDashboardCard(
                entry: entry,
                dayKey: dayKey,
                isToday: isToday,
                sleepHours: sleepHours,
                sleepGoalHours: sleepGoalHours
            )

            waterDashboardCard(
                entry: entry,
                dayKey: dayKey,
                waterGoal: waterGoal,
                waterPercent: waterPercent
            )

            reportsSideBySideRow

            dashboardMotivationBanner
        }
    }

    private var weekDayStrip: some View {
        HStack(spacing: 6) {
            ForEach(currentWeekDates, id: \.self) { date in
                let selected = Calendar.current.isDate(date, inSameDayAs: selectedWellnessDay)
                Button {
                    selectedWellnessDay = date
                } label: {
                    VStack(spacing: 4) {
                        Text(weekdayShortLabel(for: date))
                            .font(.caption2.weight(.bold))
                        Text(dayNumberLabel(for: date))
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selected ? Color.white : AppTheme.textSecondary)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selected ? AppTheme.accent : AppTheme.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                Calendar.current.isDateInToday(date) && !selected
                                    ? AppTheme.accent.opacity(0.55)
                                    : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sleepDashboardCard(
        entry: DailyWellnessEntry,
        dayKey: String,
        isToday: Bool,
        sleepHours: Double,
        sleepGoalHours: Double
    ) -> some View {
        let schedule = sleepScheduleEstimate(hours: sleepHours, loggedAt: entry.sleepUpdatedAt)
        let assessment = entry.sleepHours.map { SleepAssessment.evaluate(hours: $0) }
            ?? SleepAssessment.evaluate(hours: sleepHours)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Label(
                    isToday ? "Sono de hoje" : "Sono · \(weekdayShortLabel(for: selectedWellnessDay))",
                    systemImage: "moon.zzz.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f h", sleepHours))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                    Text("Meta: \(Int(sleepGoalHours))h")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            HStack {
                Spacer()
                Label(assessment.title, systemImage: assessment.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(assessment.color)
            }

            Slider(
                value: Binding(
                    get: { entry.sleepHours ?? sleepHoursDraft },
                    set: { newValue in
                        sleepHoursDraft = newValue
                        wellnessService.logSleep(hours: newValue, dayKey: dayKey)
                    }
                ),
                in: 0...12,
                step: 0.5
            )
            .tint(AppTheme.accent)

            HStack(spacing: 8) {
                sleepMetricTile(
                    icon: "bed.double.fill",
                    value: schedule.bedtime,
                    caption: "Horário de sono"
                )
                sleepMetricTile(
                    icon: "sun.max.fill",
                    value: schedule.wake,
                    caption: "Acordou às"
                )
                sleepMetricTile(
                    icon: "stopwatch.fill",
                    value: schedule.total,
                    caption: "Tempo total"
                )
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func sleepMetricTile(icon: String, value: String, caption: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func waterDashboardCard(
        entry: DailyWellnessEntry,
        dayKey: String,
        waterGoal: Int,
        waterPercent: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Água", systemImage: "drop.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.blue)

                Spacer(minLength: 8)

                waterStepButton(systemImage: "minus", enabled: entry.waterIntakeMl > 0) {
                    let next = max(0, entry.waterIntakeMl - WaterServing.glassML)
                    wellnessService.updateWaterIntake(next, dayKey: dayKey)
                }

                Text("\(formatMilliliters(entry.waterIntakeMl)) / \(formatMilliliters(waterGoal)) ml")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                waterStepButton(systemImage: "plus", enabled: entry.waterIntakeMl < WaterServing.maxDailyIntakeML) {
                    wellnessService.addWater(WaterServing.glassML, dayKey: dayKey)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 10)
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: max(8, geo.size.width * waterPercent), height: 10)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 14)

            HStack(spacing: 10) {
                waterQuickAddButton(title: "+1 copo", icon: "cup.and.saucer.fill") {
                    wellnessService.addWater(WaterServing.glassML, dayKey: dayKey)
                }
                waterQuickAddButton(title: "+1 garrafa", icon: "waterbottle") {
                    wellnessService.addWater(WaterServing.bottleML, dayKey: dayKey)
                }

                Spacer(minLength: 4)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: waterPercent)
                        .stroke(
                            AppTheme.accent,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("\(Int((waterPercent * 100).rounded()))%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                        Text("da meta")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .frame(width: 58, height: 58)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func waterStepButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .foregroundStyle(enabled ? AppTheme.accent : AppTheme.textSecondary.opacity(0.45))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .strokeBorder(
                            enabled ? AppTheme.accent.opacity(0.85) : Color.white.opacity(0.18),
                            lineWidth: 1.5
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(systemImage == "plus" ? "Aumentar água" : "Diminuir água")
    }

    private func waterQuickAddButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .strokeBorder(AppTheme.accent.opacity(0.85), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var reportsSideBySideRow: some View {
        HStack(spacing: 10) {
            compactReportCard(
                title: "Relatório Semanal",
                subtitle: weeklyReportSubtitle,
                icon: "chart.bar.doc.horizontal.fill",
                iconTint: AppTheme.accent,
                showsNew: weeklyReportService.isReportAvailable
            ) {
                showWeeklyReport = true
            }

            compactReportCard(
                title: "Relatório Mensal",
                subtitle: monthlyReportSubtitle,
                icon: "calendar.badge.clock",
                iconTint: AppTheme.accentSecondary,
                showsNew: monthlyReportService.isReportAvailable
            ) {
                showMonthlyReport = true
            }
        }
    }

    private var weeklyReportSubtitle: String {
        if weeklyReportService.isReportAvailable {
            return "Veja seu progresso da semana"
        }
        if weeklyReportService.daysUntilNextReport > 0 {
            return "Próximo relatório em \(weeklyReportService.daysUntilNextReport) dia(s)"
        }
        return "Acompanhe treinos e calorias"
    }

    private var monthlyReportSubtitle: String {
        if monthlyReportService.isReportAvailable {
            return "Sono, suplementos e medidas"
        }
        if monthlyReportService.daysUntilNextReport > 0 {
            return "Próximo relatório em \(monthlyReportService.daysUntilNextReport) dia(s)"
        }
        return "Histórico dos últimos 30 dias"
    }

    private func compactReportCard(
        title: String,
        subtitle: String,
        icon: String,
        iconTint: Color,
        showsNew: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(iconTint.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(iconTint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        if showsNew {
                            Text("NOVO")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(iconTint)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var dashboardMotivationBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Disciplina hoje, resultados amanhã.")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Pequenas escolhas, grandes conquistas.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 4)

            VStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)
                Text("VOCÊ CONSEGUE!")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.22, blue: 0.12),
                        Color(red: 0.08, green: 0.14, blue: 0.10),
                        AppTheme.cardBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)
                    .offset(x: 110, y: -20)
                Circle()
                    .fill(AppTheme.accent.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .blur(radius: 24)
                    .offset(x: -90, y: 30)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Segunda → domingo da semana corrente.
    private var currentWeekDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today) // 1 = domingo
        let mondayOffset = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: today) else {
            return [today]
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private func weekdayShortLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEE"
        let raw = formatter.string(from: date)
            .replacingOccurrences(of: ".", with: "")
            .uppercased()
        if raw.hasPrefix("SÁB") || raw.hasPrefix("SAB") { return "SÁB" }
        return String(raw.prefix(3))
    }

    private func dayNumberLabel(for date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return String(day)
    }

    private func syncSleepDraft(for date: Date) {
        let key = DailyWellnessEntry.dayKey(for: date)
        sleepHoursDraft = wellnessService.sleepHours(for: key) ?? 7
    }

    private func formatMilliliters(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Estima horário de dormir / acordar a partir das horas registradas.
    private func sleepScheduleEstimate(hours: Double, loggedAt: Date?) -> (bedtime: String, wake: String, total: String) {
        let calendar = Calendar.current
        var wakeComponents = calendar.dateComponents([.year, .month, .day], from: selectedWellnessDay)
        if let loggedAt {
            let hour = calendar.component(.hour, from: loggedAt)
            let minute = calendar.component(.minute, from: loggedAt)
            if (5..<14).contains(hour) {
                wakeComponents.hour = hour
                wakeComponents.minute = minute
            } else {
                wakeComponents.hour = 7
                wakeComponents.minute = 30
            }
        } else {
            wakeComponents.hour = 7
            wakeComponents.minute = 30
        }
        let wakeDate = calendar.date(from: wakeComponents) ?? selectedWellnessDay
        let bedDate = wakeDate.addingTimeInterval(-max(hours, 0) * 3600)

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "pt_BR")
        timeFormatter.dateFormat = "HH:mm"

        let totalHours = Int(hours)
        let totalMinutes = Int(((hours - Double(totalHours)) * 60).rounded())
        return (
            bedtime: timeFormatter.string(from: bedDate),
            wake: timeFormatter.string(from: wakeDate),
            total: "\(totalHours)h \(totalMinutes)min"
        )
    }

    private var shareCardsSection: some View {
        VStack(spacing: 16) {
            shareCardSlotSection(slot: .individual)
            shareCardSlotSection(slot: .duoTeam)
        }
    }

    @ViewBuilder
    private func shareCardSlotSection(slot: WorkoutShareCardSlot) -> some View {
        let isExpanded = expandedShareSlot == slot
        if let card = shareCardStore.card(for: slot) {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    if suppressShareCardTapAfterLongPress {
                        suppressShareCardTapAfterLongPress = false
                        return
                    }
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                        expandedShareSlot = isExpanded ? nil : slot
                    }
                } label: {
                    VStack(alignment: .leading, spacing: isExpanded ? 16 : 0) {
                        HStack(spacing: 14) {
                            let modalityIcon = WorkoutShareCardView.modalitySystemImage(for: card.makeSession())
                            ZStack {
                                if let profileImage = authService.profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .strokeBorder(AppTheme.accent.opacity(0.85), lineWidth: 1.5)
                                        )

                                    Image(systemName: modalityIcon)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(AppTheme.accent)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(AppTheme.cardBackground))
                                        .overlay(Circle().strokeBorder(AppTheme.accent.opacity(0.5), lineWidth: 1))
                                        .offset(x: 16, y: 16)
                                } else {
                                    Circle()
                                        .fill(AppTheme.accent.opacity(0.2))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: slot == .duoTeam ? "person.3.fill" : modalityIcon)
                                        .font(.title3)
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            .frame(width: 48, height: 48)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(slot.sectionTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)

                                Text(shareCardSubtitle(for: card, slot: slot))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        if isExpanded {
                            shareCardPreview(for: card, slot: slot)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 1)
                        .onEnded { _ in
                            suppressShareCardTapAfterLongPress = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            fullscreenShareSlot = slot
                        }
                )
                .accessibilityLabel("\(slot.sectionTitle): \(card.makeSession().completedModalityTitle)")
                .accessibilityHint(
                    isExpanded
                        ? "Toque para recolher o card. Mantenha pressionado por 1 segundo para tela cheia e salvar em Fotos."
                        : "Toque para expandir o card. Mantenha pressionado por 1 segundo para tela cheia e salvar em Fotos."
                )
                .accessibilityAction(named: "Abrir em tela cheia") {
                    fullscreenShareSlot = slot
                }
                .onChange(of: card.sessionId) { _, _ in
                    if expandedShareSlot == slot { expandedShareSlot = nil }
                    if fullscreenShareSlot == slot { fullscreenShareSlot = nil }
                }

                Text("Pressione firmemente por 1s para salvar o card em Fotos")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 4)
            }
        } else {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: slot == .duoTeam ? "person.3.fill" : "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(slot.sectionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(slot.emptyHint)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    private func shareCardSubtitle(for card: LastWorkoutShareCard, slot: WorkoutShareCardSlot) -> String {
        let modality = card.makeSession().completedModalityTitle
        let date = formattedShareCardDate(card.displayDate)
        if slot == .duoTeam {
            let team = card.duoTeamName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if team.isEmpty {
                return "\(modality) · \(date)"
            }
            return "\(modality) · \(team) · \(date)"
        }
        return "\(modality) · \(date)"
    }

    private func shareCardFullscreenCover(for slot: WorkoutShareCardSlot) -> some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()
                .onTapGesture {
                    fullscreenShareSlot = nil
                }

            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button("Fechar") {
                        fullscreenShareSlot = nil
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer(minLength: 0)

                Group {
                    if let image = shareCardStore.previewImage(for: slot) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
                            .padding(.horizontal, 24)
                            .onTapGesture {
                                fullscreenShareSlot = nil
                            }
                    } else if let card = shareCardStore.card(for: slot) {
                        WorkoutShareCardView(
                            session: card.makeSession(),
                            athleteName: card.athleteName,
                            motivationLine: card.motivationLine,
                            profileImage: authService.profileImage
                        )
                        .scaleEffect(shareCardExpandedScale)
                        .frame(height: shareCardPreviewHeight)
                        .allowsHitTesting(false)
                        .padding(.horizontal, 24)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    Task { await saveShareCardToPhotos(slot: slot) }
                } label: {
                    HStack(spacing: 10) {
                        if isSavingShareCard {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text("Salvar em Fotos")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(
                    isSavingShareCard
                        || (shareCardStore.previewImage(for: slot) == nil && shareCardStore.card(for: slot) == nil)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .accessibilityLabel("\(slot.sectionTitle) em tela cheia")
        .task {
            await ensureShareCardPreviewImage(slot: slot)
        }
    }

    @ViewBuilder
    private func shareCardPreview(for card: LastWorkoutShareCard, slot: WorkoutShareCardSlot) -> some View {
        if let preview = shareCardStore.previewImage(for: slot) {
            Image(uiImage: preview)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        } else {
            WorkoutShareCardView(
                session: card.makeSession(),
                athleteName: card.athleteName,
                motivationLine: card.motivationLine,
                profileImage: authService.profileImage
            )
            .scaleEffect(shareCardExpandedScale)
            .frame(height: shareCardPreviewHeight)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
        }
    }

    @MainActor
    private func ensureShareCardPreviewImage(slot: WorkoutShareCardSlot) async {
        guard shareCardStore.previewImage(for: slot) == nil,
              let card = shareCardStore.card(for: slot) else { return }
        if let image = WorkoutShareCardRenderer.renderImage(
            session: card.makeSession(),
            athleteName: card.athleteName,
            motivationLine: card.motivationLine,
            profileImage: authService.profileImage
        ) {
            shareCardStore.updatePreviewImage(image, slot: slot)
        }
    }

    @MainActor
    private func saveShareCardToPhotos(slot: WorkoutShareCardSlot) async {
        await ensureShareCardPreviewImage(slot: slot)
        guard let image = shareCardStore.previewImage(for: slot) else {
            presentShareCardSaveAlert(
                title: "Não foi possível salvar",
                message: "A imagem do card não está disponível."
            )
            return
        }

        isSavingShareCard = true
        defer { isSavingShareCard = false }

        do {
            try await PhotoLibrarySaver.saveImage(image)
            presentShareCardSaveAlert(
                title: "Salvo em Fotos",
                message: "O card de postagem foi salvo na sua galeria."
            )
        } catch {
            presentShareCardSaveAlert(
                title: "Não foi possível salvar",
                message: error.localizedDescription
            )
        }
    }

    private func presentShareCardSaveAlert(title: String, message: String) {
        shareCardSaveAlertTitle = title
        shareCardSaveAlertMessage = message
        showShareCardSaveAlert = true
    }

    private func formattedShareCardDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd MMM yyyy · HH:mm"
        return formatter.string(from: date)
    }

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(MotivationMessages.namedGreeting(name: authService.currentUser?.greetingName ?? "Atleta"))
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(dashboardHealthSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            PulsingHeartIconView(
                size: DeviceLayout.isPad ? 52 : 44,
                glowColor: healthStatus.glowColor
            )
            .accessibilityLabel(healthStatus.title)
            .accessibilityValue(wellnessService.healthIconDetailMessage())
        }
    }

    private var dashboardHealthSubtitle: String {
        let restWindow = MotivationMessages.isRestWindow()
        switch healthStatus {
        case .green:
            return restWindow
                ? "Hora de desacelerar e preparar um bom descanso."
                : "Pronto para treinar hoje?"
        case .yellow:
            return "Atualize água e sono para manter o ícone verde."
        case .red:
            return "Ícone vermelho — registre água e sono no Perfil."
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            MetricBadge(
                icon: "figure.walk",
                value: "\(dashboardSteps)",
                label: "Passos",
                color: AppTheme.accent
            )
            MetricBadge(
                icon: "flame.fill",
                value: String(format: "%.0f", healthKitManager.todayCalories),
                label: "Calorias",
                color: AppTheme.accentSecondary
            )
            MetricBadge(
                icon: "heart.fill",
                value: String(format: "%.0f", dashboardHeartRate),
                label: "BPM",
                color: .red
            )
        }
    }

    private var dashboardSteps: Int {
        liveMetrics.todaySteps
    }

    private var dashboardHeartRate: Double {
        liveMetrics.heartRateBPM
    }

    private var watchSection: some View {
        VStack(spacing: 10) {
            Button {
                Task { await syncAppleWatch() }
            } label: {
                HStack {
                    Image(systemName: "applewatch")
                        .font(.title2)
                        .foregroundStyle(watchConnectivity.isWatchConnected ? AppTheme.accent : .gray)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Watch")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(watchStatusSubtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    if isSyncingWatch {
                        ProgressView()
                    } else {
                        Circle()
                            .fill(watchConnectivity.isWatchConnected ? AppTheme.accent : .gray)
                            .frame(width: 10, height: 10)
                    }
                }
                .cardStyle()
            }
            .buttonStyle(.plain)
            .disabled(isSyncingWatch)
            .accessibilityHint("Toca para sincronizar com o Apple Watch")

            NavigationLink {
                BluetoothHeartRateSettingsView()
            } label: {
                HStack {
                    Image(systemName: "wave.3.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            BluetoothHeartRateService.shared.isConnected ? .red : AppTheme.accentSecondary
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sensor Bluetooth")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(bluetoothStatusSubtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .cardStyle()
            }
            .buttonStyle(.plain)
        }
    }

    private var bluetoothStatusSubtitle: String {
        let ble = BluetoothHeartRateService.shared
        if ble.isConnected {
            let name = ble.connectedDevice?.displayName ?? "Sensor"
            let bpm = liveMetrics.heartRateSource == .bluetooth && liveMetrics.heartRateBPM > 0
                ? " · \(Int(liveMetrics.heartRateBPM)) BPM"
                : ""
            return "Conectado · \(name)\(bpm)"
        }
        if liveMetrics.heartRateSource == .healthKit {
            return "Passos/kcal via Apple Saúde · toque para parear BPM"
        }
        return "Cintas e relógios com HR BLE · passos via Saúde"
    }

    private var watchStatusSubtitle: String {
        if isSyncingWatch {
            return "Buscando sincronismo..."
        }
        if watchConnectivity.isWatchConnected {
            return "Conectado · Toque para sincronizar"
        }
        return "Desconectado · Toque para tentar sincronizar"
    }

    private func syncAppleWatch() async {
        guard !isSyncingWatch else { return }
        isSyncingWatch = true
        let result = await watchConnectivity.attemptSyncWithWatch()
        await healthKitManager.refreshFromHealthKit()
        isSyncingWatch = false
        watchSyncResult = result
        showWatchSyncAlert = true
    }

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Treinos Recentes")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if recentCompletedSessions.isEmpty {
                Text("Nenhum treino realizado ainda")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .cardStyle()
            } else {
                ForEach(recentCompletedSessions) { session in
                    Button {
                        selectedRecentSession = session
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.workoutTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(Int(session.duration / 60)) min")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.accent)
                                if session.caloriesBurned > 0 {
                                    Text("\(Int(session.caloriesBurned)) kcal")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Mostra o relatório do treino concluído")
                }
            }
        }
    }

    private var recentCompletedSessions: [WorkoutSession] {
        Array(
            workoutStore.sessionHistory
                .filter { $0.endedAt != nil }
                .prefix(3)
        )
    }
}
