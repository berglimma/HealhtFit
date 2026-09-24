import SwiftUI
import Charts

struct StrengthPerformanceView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    @State private var period: StrengthPerformancePeriod = .threeMonths
    @State private var selectedExerciseKey: String?
    @State private var selected1RMDate: Date?
    @State private var selectedVolumeWeek: Date?

    private var exercises: [StrengthExerciseOption] {
        StrengthPerformanceAnalyzer.availableExercises(
            sessions: workoutStore.sessionHistory,
            period: period
        )
    }

    private var activeExerciseKey: String? {
        if let selectedExerciseKey,
           exercises.contains(where: { $0.nameKey == selectedExerciseKey }) {
            return selectedExerciseKey
        }
        return exercises.first?.nameKey
    }

    private var activeExerciseName: String {
        exercises.first(where: { $0.nameKey == activeExerciseKey })?.displayName ?? "Exercício"
    }

    private var oneRMPoints: [Estimated1RMPoint] {
        guard let key = activeExerciseKey else { return [] }
        return StrengthPerformanceAnalyzer.estimated1RMSeries(
            exerciseNameKey: key,
            sessions: workoutStore.sessionHistory,
            sheets: workoutStore.workoutSheets,
            period: period
        )
    }

    private var volumeSlices: [WeeklyVolumeSlice] {
        StrengthPerformanceAnalyzer.weeklyVolumeSeries(
            sessions: workoutStore.sessionHistory,
            sheets: workoutStore.workoutSheets,
            period: period
        )
    }

    private var hasAnyLoadData: Bool {
        !exercises.isEmpty || !volumeSlices.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Desempenho")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }

            if hasAnyLoadData {
                estimated1RMCard
                weeklyVolumeCard
            } else {
                emptyState
            }
        }
    }

    // MARK: - 1RM card

    private var estimated1RMCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("1RM estimado")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 8)
                periodMenu
            }

            exercisePicker

            Text("1RM projetado ao longo do tempo")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            if oneRMPoints.count >= 2 {
                Chart {
                    ForEach(oneRMPoints) { point in
                        LineMark(
                            x: .value("Data", point.date),
                            y: .value("1RM", point.estimated1RM)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(AppTheme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        AreaMark(
                            x: .value("Data", point.date),
                            y: .value("1RM", point.estimated1RM)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.accent.opacity(0.28), AppTheme.accent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        PointMark(
                            x: .value("Data", point.date),
                            y: .value("1RM", point.estimated1RM)
                        )
                        .foregroundStyle(AppTheme.accent)
                        .symbolSize(selected1RMPoint?.id == point.id ? 64 : 28)
                    }

                    if let selected = selected1RMPoint {
                        RuleMark(x: .value("Selecionado", selected.date))
                            .foregroundStyle(Color.white.opacity(0.25))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .chartXSelection(value: $selected1RMDate)
                .chartYScale(domain: oneRMYDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(Self.shortDate.string(from: date))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Self.axisNumber.string(from: NSNumber(value: v)) ?? "\(Int(v))")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 200)

                if let selected = selected1RMPoint {
                    oneRMTooltip(selected)
                } else if let last = oneRMPoints.last {
                    oneRMTooltip(last)
                }
            } else if let only = oneRMPoints.first {
                singlePointBanner(only)
            } else {
                Text("Sem cargas registradas neste exercício no período.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            }
        }
        .cardStyle()
    }

    private var selected1RMPoint: Estimated1RMPoint? {
        guard let selected1RMDate else { return nil }
        let calendar = Calendar.current
        return oneRMPoints.min(by: {
            abs(calendar.startOfDay(for: $0.date).timeIntervalSince(selected1RMDate))
                < abs(calendar.startOfDay(for: $1.date).timeIntervalSince(selected1RMDate))
        })
    }

    private var oneRMYDomain: ClosedRange<Double> {
        let values = oneRMPoints.map(\.estimated1RM)
        let maxV = values.max() ?? 100
        let upper = max(ceil(maxV / 10) * 10, 20)
        return 0...upper
    }

    @ViewBuilder
    private var exercisePicker: some View {
        if exercises.count > 1 {
            Menu {
                ForEach(exercises) { option in
                    Button {
                        selectedExerciseKey = option.nameKey
                        selected1RMDate = nil
                    } label: {
                        if option.nameKey == activeExerciseKey {
                            Label(option.displayName, systemImage: "checkmark")
                        } else {
                            Text(option.displayName)
                        }
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Text(activeExerciseName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.top, 2)
                }
            }
        } else {
            Text(activeExerciseName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func oneRMTooltip(_ point: Estimated1RMPoint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.mediumDate.string(from: point.date))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            HStack(spacing: 6) {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 8, height: 8)
                Text("1RM estimado: \(Self.kg.string(from: NSNumber(value: point.estimated1RM)) ?? String(format: "%.1f", point.estimated1RM)) kg")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func singlePointBanner(_ point: Estimated1RMPoint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Primeiro registro de carga")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("1RM estimado: \(Self.kg.string(from: NSNumber(value: point.estimated1RM)) ?? String(format: "%.1f", point.estimated1RM)) kg em \(Self.mediumDate.string(from: point.date)). Continue treinando para ver a evolução.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Weekly volume card

    private var weeklyVolumeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Volume semanal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Por semana, com o volume de cada série atribuído à parte do corpo do exercício")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                periodMenu
            }

            if volumeSlices.isEmpty {
                Text("Sem volume de carga no período. Registre o peso nos exercícios ao treinar.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 24)
            } else {
                Chart(volumeSlices) { slice in
                    BarMark(
                        x: .value("Semana", slice.weekStart, unit: .weekOfYear),
                        y: .value("Volume", slice.volumeKg)
                    )
                    .foregroundStyle(by: .value("Grupo", slice.muscleGroup.rawValue))
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale(domain: MuscleGroup.allCases.map(\.rawValue), range: MuscleGroup.allCases.map(\.chartColor))
                .chartLegend(.hidden)
                .chartXSelection(value: $selectedVolumeWeek)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Self.compactVolume(v))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(Self.weekAxis.string(from: date))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 220)

                volumeTooltip
            }
        }
        .cardStyle()
    }

    private var selectedVolumeSlices: [WeeklyVolumeSlice] {
        let weeks = Set(volumeSlices.map(\.weekStart))
        let target: Date
        if let selectedVolumeWeek,
           let nearest = weeks.min(by: { abs($0.timeIntervalSince(selectedVolumeWeek)) < abs($1.timeIntervalSince(selectedVolumeWeek)) }) {
            target = nearest
        } else if let last = weeks.sorted().last {
            target = last
        } else {
            return []
        }
        return volumeSlices
            .filter { $0.weekStart == target }
            .sorted { $0.volumeKg > $1.volumeKg }
    }

    @ViewBuilder
    private var volumeTooltip: some View {
        let slices = selectedVolumeSlices
        if let week = slices.first?.weekStart {
            VStack(alignment: .leading, spacing: 8) {
                Text(Self.weekTitle.string(from: week))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                ForEach(slices) { slice in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(slice.muscleGroup.chartColor)
                            .frame(width: 8, height: 8)
                        Text(slice.muscleGroup.rawValue)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text("\(Self.volumeKg.string(from: NSNumber(value: slice.volumeKg)) ?? "\(Int(slice.volumeKg))") kg")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Shared

    private var periodMenu: some View {
        Picker("Período", selection: $period) {
            ForEach(StrengthPerformancePeriod.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.menu)
        .tint(AppTheme.accent)
        .onChange(of: period) { _, _ in
            selected1RMDate = nil
            selectedVolumeWeek = nil
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Acompanhe suas cargas")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Ao concluir treinos com o peso registrado em cada exercício, você verá aqui o 1RM estimado e o volume semanal por parte do corpo.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Formatters

    private static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f
    }()

    private static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f
    }()

    private static let weekAxis: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f
    }()

    private static let weekTitle: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f
    }()

    private static let kg: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return f
    }()

    private static let volumeKg: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    private static let axisNumber: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    private static func compactVolume(_ value: Double) -> String {
        if value >= 1000 {
            let k = value / 1000
            let formatted = NumberFormatter()
            formatted.locale = Locale(identifier: "pt_BR")
            formatted.maximumFractionDigits = k.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
            return "\(formatted.string(from: NSNumber(value: k)) ?? "\(Int(k))")k"
        }
        return axisNumber.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

private extension MuscleGroup {
    /// Paleta alinhada ao HealthFit (verde / laranja), sem azul ou verde claro genéricos.
    var chartColor: Color {
        switch self {
        case .chest: return AppTheme.accent
        case .back: return AppTheme.accent.opacity(0.72)
        case .legs: return AppTheme.accentSecondary
        case .shoulders: return AppTheme.accentSecondary.opacity(0.78)
        case .arms: return Color.white.opacity(0.78)
        case .core: return AppTheme.accent.opacity(0.45)
        case .fullBody: return Color.white.opacity(0.38)
        }
    }
}
