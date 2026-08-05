import SwiftUI
import UIKit

/// Card visual de conquista para Stories / status (WhatsApp & Instagram).
struct WorkoutShareCardView: View {
    let session: WorkoutSession
    let athleteName: String
    let motivationLine: String
    /// Sessões recentes (opcional) para sparkline de durações no card.
    var recentSessions: [WorkoutSession] = []
    /// Foto de perfil do atleta — omitida por completo quando `nil` (sem placeholder).
    var profileImage: UIImage? = nil

    private var displayName: String {
        let trimmed = athleteName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Atleta" : trimmed
    }

    private var isCardio: Bool {
        WorkoutReportBuilder.isCardioSession(session)
    }

    private var isMeditation: Bool {
        let title = session.workoutTitle.lowercased()
        return title.hasPrefix("meditação") || title.hasPrefix("meditacao")
    }

    private var isRunning: Bool {
        session.isOutdoorGPSCardio
    }

    /// Early-end / inactivity headlines + motivation are longer and need room to wrap.
    private var needsExtraTextSpace: Bool {
        session.endedEarly || session.autoEndedByInactivity
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd MMM yyyy · HH:mm"
        return formatter.string(from: session.endedAt ?? session.startedAt).uppercased()
    }

    /// Stories-friendly width; height grows modestly when early-end copy needs room.
    static let cardWidth: CGFloat = 360
    static var standardCardHeight: CGFloat { 464 }
    static var expandedTextCardHeight: CGFloat { 512 }
    static var runningCardHeight: CGFloat { 540 }
    static var runningExpandedCardHeight: CGFloat { 568 }
    /// Extra height when the athlete photo sits below the date.
    static var runningCardHeightWithPhoto: CGFloat { 588 }
    static var runningExpandedCardHeightWithPhoto: CGFloat { 616 }

    /// Altura máxima usada no preview do dashboard (cobre corrida + early-end + foto).
    static var maxPreviewCardHeight: CGFloat { runningExpandedCardHeightWithPhoto }

    private var cardHeight: CGFloat {
        if isRunning {
            let hasPhoto = profileImage != nil
            if needsExtraTextSpace {
                return hasPhoto ? Self.runningExpandedCardHeightWithPhoto : Self.runningExpandedCardHeight
            }
            return hasPhoto ? Self.runningCardHeightWithPhoto : Self.runningCardHeight
        }
        return needsExtraTextSpace ? Self.expandedTextCardHeight : Self.standardCardHeight
    }

    var body: some View {
        ZStack {
            backgroundLayer

            if isRunning {
                runningCardContent
            } else {
                standardCardContent
            }
        }
        .frame(width: Self.cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Standard (força / cardio genérico / meditação)

    private var standardCardContent: some View {
        VStack(spacing: needsExtraTextSpace ? 6 : 8) {
            brandHeader

            achievementBadge

            Text(headline)
                .font(.system(size: headlineFontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .layoutPriority(3)

            if !motivationLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(motivationLine)
                    .font(.system(size: needsExtraTextSpace ? 11.5 : 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .layoutPriority(3)
            }

            Text(session.workoutTitle)
                .font(.system(size: needsExtraTextSpace ? 13 : 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color("AccentGreen"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)

            summaryChartSection
                .layoutPriority(0)

            statsRow
                .layoutPriority(0)

            footer
        }
        .padding(.horizontal, 20)
        .padding(.top, needsExtraTextSpace ? 12 : 16)
        .padding(.bottom, needsExtraTextSpace ? 10 : 14)
    }

    // MARK: - Corrida / pedal outdoor (mapa + troféu dourado + métricas)

    private var runningCardContent: some View {
        VStack(spacing: needsExtraTextSpace ? 5 : 7) {
            runningBrandHeader

            runningTrophyBadge

            Text(runningHeadline)
                .font(.system(size: needsExtraTextSpace ? 17 : 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .layoutPriority(3)

            if !motivationLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(motivationLine)
                    .font(.system(size: needsExtraTextSpace ? 10.5 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineLimit(needsExtraTextSpace ? 3 : 2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }

            Text(session.workoutTitle)
                .font(.system(size: needsExtraTextSpace ? 12 : 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color("AccentGreen"))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            ShareCardRouteMapView(
                routePoints: session.routePoints,
                distanceKm: session.displayDistanceKm,
                performanceMetric: session.routePerformanceMetric
            )
            .frame(height: needsExtraTextSpace ? 118 : 138)
            .layoutPriority(2)

            runningStatsGrid
                .layoutPriority(1)

            footer
        }
        .padding(.horizontal, 18)
        .padding(.top, needsExtraTextSpace ? 10 : 14)
        .padding(.bottom, needsExtraTextSpace ? 8 : 12)
    }

    /// Logo + data; foto de perfil só quando existe, alinhada abaixo da data.
    private var runningBrandHeader: some View {
        let photoSize: CGFloat = needsExtraTextSpace ? 36 : 44

        return VStack(alignment: .trailing, spacing: 8) {
            brandHeader

            if let profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: photoSize, height: photoSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color.yellow.opacity(0.85), lineWidth: 2)
                    )
            }
        }
    }

    private var outdoorSessionNoun: String {
        if session.isOutdoorCyclingSession { return "o pedal" }
        if session.isOutdoorWalkingSession { return "a caminhada" }
        return "a corrida"
    }

    private var outdoorSessionVerb: String {
        if session.isOutdoorCyclingSession { return "pedalou" }
        if session.isOutdoorWalkingSession { return "caminhou" }
        return "correu"
    }

    private var runningHeadline: String {
        if session.autoEndedByInactivity {
            return "\(displayName) pausou \(outdoorSessionNoun)"
        }
        if session.endedEarly {
            return "\(displayName) \(outdoorSessionVerb), mas não concluiu"
        }
        return "\(displayName) fechou \(outdoorSessionNoun)"
    }

    private var runningTrophyBadge: some View {
        let trophySize: CGFloat = needsExtraTextSpace ? 26 : 32

        return ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.85, blue: 0.2).opacity(0.55))
                .frame(width: 72, height: 72)
                .blur(radius: 16)

            Circle()
                .fill(Color.orange.opacity(0.4))
                .frame(width: 48, height: 48)
                .blur(radius: 10)

            Image(systemName: "trophy.fill")
                .font(.system(size: trophySize, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.55),
                            Color(red: 1.0, green: 0.78, blue: 0.15),
                            Color(red: 0.95, green: 0.55, blue: 0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.yellow.opacity(0.95), radius: 10, y: 0)
                .shadow(color: Color.orange.opacity(0.7), radius: 4, y: 1)
        }
        .frame(width: 64, height: 64)
    }

    private var runningStatsGrid: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                shareStat(value: runningBPMValue, label: "BPM")
                shareStat(value: runningKcalValue, label: "KCAL")
                shareStat(value: runningPaceValue, label: "RITMO")
            }
            HStack(spacing: 6) {
                shareStat(value: runningStepsValue, label: "PASSOS")
                shareStat(value: runningKmValue, label: "KM")
                shareStat(value: runningTempoValue, label: "TEMPO")
            }
            if session.pausedDurationSeconds > 0 {
                HStack(spacing: 6) {
                    shareStat(
                        value: DurationFormatting.format(seconds: session.pausedDurationSeconds),
                        label: "PAUSA"
                    )
                    shareStat(
                        value: DurationFormatting.format(seconds: session.activeDurationSeconds),
                        label: "ATIVO"
                    )
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var runningBPMValue: String {
        session.averageHeartRate > 0
            ? String(format: "%.0f", session.averageHeartRate)
            : "—"
    }

    private var runningKcalValue: String {
        session.caloriesBurned > 0
            ? "\(Int(session.caloriesBurned.rounded()))"
            : "—"
    }

    private var runningPaceValue: String {
        guard let pace = session.displayPaceSecondsPerKm else { return "—" }
        let minutes = pace / 60
        let seconds = pace % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var runningStepsValue: String {
        guard let steps = session.stepCount, steps > 0 else { return "—" }
        if steps >= 10_000 {
            return String(format: "%.1fk", Double(steps) / 1_000.0)
        }
        return "\(steps)"
    }

    private var runningKmValue: String {
        let km = session.displayDistanceKm
        guard km > 0 else { return "—" }
        return String(format: km >= 10 ? "%.1f" : "%.2f", km)
    }

    private var runningTempoValue: String {
        DurationFormatting.format(seconds: Int(session.duration))
    }

    private var headlineFontSize: CGFloat {
        if needsExtraTextSpace { return 18 }
        return 24
    }

    private var headline: String {
        if session.autoEndedByInactivity {
            return "\(displayName) pausou o treino"
        }
        if session.endedEarly {
            return "\(displayName) treinou, mas não concluiu"
        }
        if isMeditation {
            return "\(displayName) praticou mindfulness"
        }
        if isCardio {
            return "\(displayName) elevou o ritmo"
        }
        return "\(displayName) concluiu o treino"
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.04),
                    Color(red: 0.05, green: 0.10, blue: 0.08),
                    Color(red: 0.04, green: 0.07, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    isRunning
                        ? Color.yellow.opacity(0.12)
                        : Color("AccentGreen").opacity(0.16)
                )
                .frame(width: 260, height: 260)
                .blur(radius: 50)
                .offset(x: -90, y: -140)

            Circle()
                .fill(
                    isRunning
                        ? Color.orange.opacity(0.14)
                        : Color("AccentOrange").opacity(0.13)
                )
                .frame(width: 220, height: 220)
                .blur(radius: 45)
                .offset(x: 110, y: 160)

            // Grade sutil
            VStack(spacing: 18) {
                ForEach(0..<14, id: \.self) { _ in
                    Rectangle()
                        .fill(.white.opacity(0.03))
                        .frame(height: 1)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image("BrandHeart")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("HealthFit")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(0.6)
            }
            Spacer(minLength: 8)
            Text(formattedDate)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var achievementBadge: some View {
        let outer: CGFloat = needsExtraTextSpace ? 48 : 58
        let inner: CGFloat = needsExtraTextSpace ? 38 : 46
        let iconSize: CGFloat = needsExtraTextSpace ? 18 : 22
        let photoSize: CGFloat = needsExtraTextSpace ? 40 : 48

        return HStack(spacing: profileImage == nil ? 0 : -8) {
            ZStack {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Color("AccentGreen"),
                                Color("AccentOrange"),
                                Color("AccentGreen")
                            ],
                            center: .center
                        ),
                        lineWidth: needsExtraTextSpace ? 2 : 2.5
                    )
                    .frame(width: outer, height: outer)

                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: inner, height: inner)

                Image(systemName: badgeIcon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(Color("AccentGreen"))
            }
            .zIndex(1)

            if let profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: photoSize, height: photoSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color("AccentGreen").opacity(0.9), lineWidth: 2)
                    )
                    .zIndex(0)
            }
        }
    }

    private var badgeIcon: String {
        if session.endedEarly || session.autoEndedByInactivity {
            return "flame.fill"
        }
        if isMeditation { return "brain.head.profile" }
        if isCardio { return "figure.run" }
        return "trophy.fill"
    }

    // MARK: - Summary chart (pure SwiftUI shapes — ImageRenderer-safe)

    private var showsCardioChart: Bool { isCardio || isMeditation }
    private var showsStrengthChart: Bool { !showsCardioChart && !strengthBarItems.isEmpty }
    private var showsRecentSparkline: Bool { !recentDurationValues.isEmpty }
    private var showsSummaryChart: Bool {
        showsCardioChart || showsStrengthChart || showsRecentSparkline
    }

    @ViewBuilder
    private var summaryChartSection: some View {
        if showsSummaryChart {
            VStack(alignment: .leading, spacing: needsExtraTextSpace ? 4 : 7) {
                if showsCardioChart {
                    cardioMeditationChart
                } else if showsStrengthChart {
                    strengthExerciseChart
                }

                if showsRecentSparkline {
                    recentDurationSparkline
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, needsExtraTextSpace ? 6 : 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var chartBarMaxHeight: CGFloat {
        needsExtraTextSpace ? 28 : 42
    }

    private var chartRowHeight: CGFloat {
        needsExtraTextSpace ? 42 : 56
    }

    private var sparklineMaxHeight: CGFloat {
        needsExtraTextSpace ? 14 : 20
    }

    private var strengthBarItems: [(id: UUID, label: String, value: Double)] {
        let records = Array(session.exerciseRecords.prefix(6))
        return records.map { record in
            let setsValue = Double(record.completedSets)
            let fallback = record.isCompleted
                ? max(Double(record.elapsedSeconds), 1)
                : Double(max(record.elapsedSeconds, 0))
            let value = setsValue > 0 ? setsValue : fallback
            return (record.exerciseId, Self.shortLabel(record.exerciseName), max(value, 0.15))
        }
        .filter { $0.value > 0 }
    }

    private var strengthExerciseChart: some View {
        let items = strengthBarItems
        let maxValue = max(items.map(\.value).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 6) {
            Text("SÉRIES POR EXERCÍCIO")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(0.6)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(items, id: \.id) { item in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color("AccentGreen"), Color("AccentOrange")],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: max(6, CGFloat(item.value / maxValue) * chartBarMaxHeight))

                        Text(item.label)
                            .font(.system(size: 7, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: chartRowHeight, alignment: .bottom)
        }
    }

    private var cardioMeditationChart: some View {
        let metrics = cardioMetricBars
        let maxValue = max(metrics.map(\.value).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: needsExtraTextSpace ? 4 : 6) {
            Text(isMeditation ? "SESSÃO" : "PERFORMANCE")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(0.6)

            VStack(spacing: needsExtraTextSpace ? 4 : 5) {
                ForEach(metrics, id: \.label) { metric in
                    let ratio = max(0.08, min(1.0, metric.value / maxValue))
                    HStack(spacing: 8) {
                        Text(metric.label)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 42, alignment: .leading)

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.08))
                                .frame(height: needsExtraTextSpace ? 5 : 7)
                            Capsule()
                                .fill(metric.color)
                                .frame(width: 168 * ratio, height: needsExtraTextSpace ? 5 : 7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(metric.display)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 44, alignment: .trailing)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
    }

    private var cardioMetricBars: [(label: String, display: String, value: Double, color: Color)] {
        var bars: [(label: String, display: String, value: Double, color: Color)] = []

        let durationMinutes = max(session.duration / 60.0, 0)
        if durationMinutes > 0 {
            bars.append((
                "TEMPO",
                DurationFormatting.format(seconds: Int(session.duration)),
                min(durationMinutes / 60.0, 1.0),
                Color("AccentGreen")
            ))
        }

        if session.caloriesBurned > 0 {
            bars.append((
                "KCAL",
                "\(Int(session.caloriesBurned))",
                min(session.caloriesBurned / 500.0, 1.0),
                Color("AccentOrange")
            ))
        }

        if session.averageHeartRate > 0 {
            bars.append((
                "BPM",
                String(format: "%.0f", session.averageHeartRate),
                min(session.averageHeartRate / 180.0, 1.0),
                Color("AccentGreen").opacity(0.85)
            ))
        }

        if bars.isEmpty {
            bars.append((
                "FOCO",
                isMeditation ? "OK" : "GO",
                0.65,
                Color("AccentGreen")
            ))
        }

        return bars
    }

    private var recentDurationValues: [Double] {
        let history = recentSessions
            .filter { $0.id != session.id }
            .sorted { ($0.endedAt ?? $0.startedAt) < ($1.endedAt ?? $1.startedAt) }
            .suffix(6)
            .map { max($0.duration, 1) }

        var values = Array(history)
        values.append(max(session.duration, 1))
        return values.count >= 2 ? values : []
    }

    private var recentDurationSparkline: some View {
        let values = recentDurationValues
        let maxValue = max(values.max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 4) {
            Text("ÚLTIMOS TREINOS")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(0.6)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    let isCurrent = index == values.count - 1
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isCurrent ? Color("AccentOrange") : Color("AccentGreen").opacity(0.55))
                        .frame(height: max(4, CGFloat(value / maxValue) * sparklineMaxHeight))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: sparklineMaxHeight, alignment: .bottom)
        }
    }

    private static func shortLabel(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 7 else { return trimmed.uppercased() }
        return String(trimmed.prefix(6)).uppercased() + "…"
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            shareStat(
                value: DurationFormatting.format(seconds: Int(session.duration)),
                label: "DURAÇÃO"
            )

            if isCardio {
                if session.pausedDurationSeconds > 0 {
                    shareStat(
                        value: DurationFormatting.format(seconds: session.pausedDurationSeconds),
                        label: "PAUSA"
                    )
                }
                if session.caloriesBurned > 0 {
                    shareStat(value: "\(Int(session.caloriesBurned))", label: "KCAL")
                }
                if session.averageHeartRate > 0 {
                    shareStat(
                        value: String(format: "%.0f", session.averageHeartRate),
                        label: "BPM"
                    )
                }
            } else if isMeditation {
                shareStat(value: "FOCO", label: "MODO")
            } else {
                shareStat(
                    value: "\(session.completedExercises)/\(max(session.totalExercises, 1))",
                    label: "EXERCÍCIOS"
                )
                if session.caloriesBurned > 0 {
                    shareStat(value: "\(Int(session.caloriesBurned))", label: "KCAL")
                }
            }
        }
    }

    private func shareStat(value: String, label: String) -> some View {
        VStack(spacing: needsExtraTextSpace ? 2 : 3) {
            Text(value)
                .font(.system(size: needsExtraTextSpace ? 11 : 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, needsExtraTextSpace ? 5 : 8)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var footer: some View {
        VStack(spacing: needsExtraTextSpace ? 1 : 3) {
            Text("Treinei com HealthFit")
                .font(.system(size: needsExtraTextSpace ? 10 : 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Text("Disciplina · Evolução · Constância")
                .font(.system(size: needsExtraTextSpace ? 8 : 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, needsExtraTextSpace ? 6 : 9)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Mini mapa desenhado (ImageRenderer-safe — sem MapKit)

/// Fundo escuro estilo mapa + polyline colorida por desempenho. Sem MapKit (flaky no ImageRenderer).
struct ShareCardRouteMapView: View {
    let routePoints: [RouteCoordinate]
    var distanceKm: Double = 0
    var performanceMetric: RoutePerformanceMetric = .pace

    private var hasRoute: Bool { routePoints.count >= 2 }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.06, green: 0.09, blue: 0.10),
                                Color(red: 0.04, green: 0.07, blue: 0.08),
                                Color(red: 0.05, green: 0.08, blue: 0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                mapGrid(in: size)

                if hasRoute {
                    routeLayer(in: size)
                } else {
                    placeholderContent
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func mapGrid(in _: CGSize) -> some View {
        Canvas { context, canvasSize in
            let hStep = canvasSize.width / 6
            let vStep = canvasSize.height / 4
            var path = Path()
            for i in 1..<6 {
                let x = CGFloat(i) * hStep
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
            }
            for i in 1..<4 {
                let y = CGFloat(i) * vStep
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width, y: y))
            }
            context.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 1)

            // “Vias” diagonais sutis
            var roads = Path()
            roads.move(to: CGPoint(x: 0, y: canvasSize.height * 0.35))
            roads.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height * 0.55))
            roads.move(to: CGPoint(x: canvasSize.width * 0.2, y: 0))
            roads.addLine(to: CGPoint(x: canvasSize.width * 0.75, y: canvasSize.height))
            context.stroke(roads, with: .color(.white.opacity(0.05)), lineWidth: 2)
        }
    }

    private func routeLayer(in size: CGSize) -> some View {
        let projected = projectedPoints(in: size, padding: 18)
        let segments = RoutePerformanceColoring.segments(from: routePoints, metric: performanceMetric)
        return ZStack {
            if projected.count >= 2 {
                // Segmentos coloridos por desempenho (verde = melhor, vermelho = pior).
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    if index + 1 < projected.count {
                        Path { path in
                            path.move(to: projected[index])
                            path.addLine(to: projected[index + 1])
                        }
                        .stroke(
                            segment.color,
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                        )
                    }
                }

                Circle()
                    .fill(Color("AccentGreen"))
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    .position(projected[0])

                Circle()
                    .fill(segments.last?.color ?? Color("AccentOrange"))
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    .position(projected[projected.count - 1])
            }
        }
    }

    private var placeholderContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "map")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
            Text("ROTA")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(1.2)
            if distanceKm > 0 {
                Text(String(format: "%.2f km", distanceKm))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color("AccentGreen").opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectedPoints(in size: CGSize, padding: CGFloat) -> [CGPoint] {
        let coords = routePoints
        guard let first = coords.first else { return [] }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for point in coords.dropFirst() {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }

        let latSpan = max(maxLat - minLat, 0.00015)
        let lonSpan = max(maxLon - minLon, 0.00015)
        let drawWidth = max(size.width - padding * 2, 1)
        let drawHeight = max(size.height - padding * 2, 1)

        // Mantém proporção geográfica (lon × cos(lat)).
        let midLat = (minLat + maxLat) / 2
        let lonScale = cos(midLat * .pi / 180)
        let aspectLon = lonSpan * max(lonScale, 0.2)
        let fitScale = min(drawWidth / aspectLon, drawHeight / latSpan)
        let usedWidth = aspectLon * fitScale
        let usedHeight = latSpan * fitScale
        let originX = padding + (drawWidth - usedWidth) / 2
        let originY = padding + (drawHeight - usedHeight) / 2

        return coords.map { point in
            let x = originX + CGFloat((point.longitude - minLon) / lonSpan) * usedWidth
            // Latitude cresce para cima; Y cresce para baixo.
            let y = originY + CGFloat((maxLat - point.latitude) / latSpan) * usedHeight
            return CGPoint(x: x, y: y)
        }
    }
}

/// Renderiza o mapa do percurso (polyline colorida) para e-mail / anexos — sem MapKit.
enum WorkoutRouteMapRenderer {
    static let emailAttachmentFileName = "rota-treino.png"
    static let emailAttachmentMimeType = "image/png"

    @MainActor
    static func renderImage(
        session: WorkoutSession,
        width: CGFloat = 900,
        height: CGFloat = 560
    ) -> UIImage? {
        guard session.routePoints.count >= 2 else { return nil }
        let map = ShareCardRouteMapView(
            routePoints: session.routePoints,
            distanceKm: session.displayDistanceKm,
            performanceMetric: session.routePerformanceMetric
        )
        .frame(width: width, height: height)

        let renderer = ImageRenderer(content: map)
        renderer.scale = 2
        renderer.isOpaque = true
        return renderer.uiImage
    }

    @MainActor
    static func pngData(for session: WorkoutSession) -> Data? {
        renderImage(session: session)?.pngData()
    }

    @MainActor
    static func mailAttachment(for session: WorkoutSession) -> MailAttachment? {
        guard let data = pngData(for: session) else { return nil }
        return MailAttachment(
            data: data,
            mimeType: emailAttachmentMimeType,
            fileName: emailAttachmentFileName
        )
    }
}

enum WorkoutShareCardRenderer {
    @MainActor
    static func renderImage(
        session: WorkoutSession,
        athleteName: String,
        motivationLine: String,
        recentSessions: [WorkoutSession] = [],
        profileImage: UIImage? = nil
    ) -> UIImage? {
        let card = WorkoutShareCardView(
            session: session,
            athleteName: athleteName,
            motivationLine: motivationLine,
            recentSessions: recentSessions,
            profileImage: profileImage
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }

    static func shareCaption(session: WorkoutSession, athleteName: String) -> String {
        let name = athleteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = name.isEmpty ? "Hoje" : "\(name) hoje"
        let duration = DurationFormatting.format(seconds: Int(session.duration))
        if session.isOutdoorGPSCardio {
            let km = session.displayDistanceKm
            let kmPart = km > 0 ? String(format: " · %.2f km", km) : ""
            let isBike = session.isOutdoorCyclingSession
            let isWalk = session.isOutdoorWalkingSession
            let tag = isBike ? "#Ciclismo" : (isWalk ? "#Caminhada" : "#Corrida")
            let verb = isBike ? "pedalou" : (isWalk ? "caminhou" : "correu")
            let noun = isBike ? "o pedal" : (isWalk ? "a caminhada" : "a corrida")
            if session.endedEarly || session.autoEndedByInactivity {
                return """
                \(who) \(verb) (não concluiu): \(session.workoutTitle) · \(duration)\(kmPart)
                Cada sessão conta — HealthFit 💪
                #HealthFit \(tag) #Treino
                """
            }
            return """
            \(who) finalizou \(noun): \(session.workoutTitle) · \(duration)\(kmPart)
            Treinei com HealthFit 💪
            #HealthFit \(tag) #Treino
            """
        }
        if session.endedEarly || session.autoEndedByInactivity {
            return """
            \(who) treinou (não concluiu): \(session.workoutTitle) · \(duration)
            Cada sessão conta — HealthFit 💪
            #HealthFit #Treino #Evolucao
            """
        }
        return """
        \(who) finalizou: \(session.workoutTitle) · \(duration)
        Treinei com HealthFit 💪
        #HealthFit #Treino #Evolucao
        """
    }

    static func motivationLine(for session: WorkoutSession) -> String {
        if session.autoEndedByInactivity {
            return "O importante é mostrar up. O próximo você fecha com chave de ouro."
        }
        if session.endedEarly {
            let lines = [
                "Cada sessão conta. Voltar amanhã já é vitória.",
                "Você apareceu hoje — isso já é progresso. O próximo fecha forte.",
                "Não concluiu, mas treinou. Constância > perfeição.",
                "Parou antes, mas não desistiu de si. Orgulho merecido.",
                "Mostrar up já muda o jogo. Na próxima você fecha o ciclo."
            ]
            let index = abs(session.id.hashValue) % lines.count
            return lines[index]
        }
        if session.isOutdoorGPSCardio {
            let lines: [String] = {
                if session.isOutdoorCyclingSession {
                    return [
                        "Quilômetros no pedal. Ritmo firme, mente leve.",
                        "Cada pedalada conta. Estrada e evolução.",
                        "Você saiu e pedalou. Orgulho merecido.",
                        "A ciclovia responde a quem aparece.",
                        "Constância nas rodas, evolução no corpo."
                    ]
                }
                if session.isOutdoorWalkingSession {
                    return [
                        "Cada passo conta. Ritmo firme, mente leve.",
                        "Você saiu e caminhou. Orgulho merecido.",
                        "Quilômetros de caminhada viram disciplina.",
                        "A estrada responde a quem aparece.",
                        "Constância no asfalto, evolução no corpo."
                    ]
                }
                return [
                    "Quilômetros que viram disciplina.",
                    "Cada passo conta. Ritmo firme, mente leve.",
                    "Você saiu e correu. Orgulho merecido.",
                    "A estrada responde a quem aparece.",
                    "Constância no asfalto, evolução no corpo."
                ]
            }()
            let index = abs(session.id.hashValue) % lines.count
            return lines[index]
        }
        let lines = [
            "Mais um dia de compromisso com a sua melhor versão.",
            "Resultado não é sorte — é consistência com propósito.",
            "Você apareceu. Isso já separa quem quer de quem faz.",
            "Corpo em movimento, mente no controle. Orgulho merecido.",
            "A disciplina de hoje é o progresso de amanhã."
        ]
        let index = abs(session.id.hashValue) % lines.count
        return lines[index]
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
