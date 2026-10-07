import MapKit
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

    private var isWaterSportShare: Bool {
        session.isWaterSportSession
            || session.isSurfSession
            || session.isKitesurfSession
    }

    /// Early-end / inactivity headlines + motivation are longer and need room to wrap.
    private var needsExtraTextSpace: Bool {
        session.presentsAsIncompleteOnShareCard
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

    /// Quando false (export ImageRenderer/JPEG), o fundo preenche o retângulo inteiro —
    /// evita cantos pretos transparentes após compressão.
    var clipsRoundedCorners: Bool = true

    var body: some View {
        let card = ZStack {
            backgroundLayer

            if isRunning {
                runningCardContent
            } else {
                standardCardContent
            }
        }
        .frame(width: Self.cardWidth, height: cardHeight)

        if clipsRoundedCorners {
            card.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        } else {
            card
        }
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

            Text(session.completedModalityTitle)
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

    // MARK: - Corrida / pedal outdoor (mapa + ícone da modalidade + métricas)

    private var runningCardContent: some View {
        VStack(spacing: needsExtraTextSpace ? 5 : 7) {
            brandHeader

            // Ícone da modalidade + foto do atleta (mantém a foto do card padrão).
            achievementBadge

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

            Text(session.completedModalityTitle)
                .font(.system(size: needsExtraTextSpace ? 12 : 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color("AccentGreen"))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            ShareCardRouteMapView(
                routePoints: session.routePoints,
                distanceKm: session.displayDistanceKm,
                performanceMetric: session.routePerformanceMetric,
                markMaxSpeedArrow: session.isKitesurfSession
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

    private var outdoorSessionNoun: String {
        if session.isKitesurfSession { return "o kitesurf" }
        if session.isSurfSession { return "o surf" }
        if session.isSwimmingSession { return "a natação" }
        if session.isOutdoorCyclingSession { return "o pedal" }
        if session.isOutdoorWalkingSession { return "a caminhada" }
        // Preferência: título da modalidade quando conhecido (ex.: "Elíptico" não entra aqui).
        let modality = session.completedModalityTitle.lowercased()
        if modality == "corrida" { return "a corrida" }
        if modality == "caminhada" { return "a caminhada" }
        if !modality.isEmpty, modality != "cardio", modality != "treino" {
            // "o kite", "o remo" etc. — artigo genérico + nome da modalidade
            return "o \(modality)"
        }
        return "a corrida"
    }

    private var outdoorSessionVerb: String {
        if session.isKitesurfSession { return "kitesurfou" }
        if session.isSurfSession { return "surfou" }
        if session.isSwimmingSession { return "nadou" }
        if session.isOutdoorCyclingSession { return "pedalou" }
        if session.isOutdoorWalkingSession { return "caminhou" }
        return "correu"
    }

    private var runningHeadline: String {
        if session.presentsAsIncompleteOnShareCard {
            if session.autoEndedByInactivity {
                return "\(displayName) pausou \(outdoorSessionNoun)"
            }
            return "\(displayName) \(outdoorSessionVerb), mas não concluiu"
        }
        return "\(displayName) fechou \(outdoorSessionNoun)"
    }

    @ViewBuilder
    private var runningStatsGrid: some View {
        if session.isKitesurfSession {
            kiteStatsGrid
        } else if session.isOutdoorCyclingSession {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    shareStat(value: runningBPMValue, label: "BPM")
                    shareStat(value: runningKcalValue, label: "KCAL")
                    shareStat(value: cyclingSpeedValue, label: "KM/H")
                }
                HStack(spacing: 6) {
                    shareStat(value: runningKmValue, label: "KM")
                    shareStat(value: runningTempoValue, label: "TEMPO")
                    Color.clear.frame(maxWidth: .infinity)
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
        } else {
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
    }

    /// Card de postagem Kitesurf: altura, tempo no ar, distância e vel. máxima (com seta).
    private var kiteStatsGrid: some View {
        let metrics = KitePostingMetrics.make(from: session)
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                shareStat(value: metrics.heightText, label: "ALTURA")
                shareStat(value: metrics.airtimeText, label: "TEMPO NO AR")
            }
            HStack(spacing: 6) {
                shareStat(value: metrics.distanceText, label: "DISTÂNCIA")
                shareStat(
                    value: metrics.maxSpeedText,
                    label: "VEL. MÁX",
                    showsPeakArrow: metrics.maxSpeedKmh > 0
                )
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

    private var cyclingSpeedValue: String {
        guard let speed = session.displayAverageSpeedKmh, speed > 0.3 else { return "—" }
        return String(format: "%.1f", speed)
    }

    private var runningTempoValue: String {
        DurationFormatting.format(seconds: Int(session.duration))
    }

    private var headlineFontSize: CGFloat {
        if needsExtraTextSpace { return 18 }
        return 24
    }

    private var headline: String {
        if session.presentsAsIncompleteOnShareCard {
            if session.autoEndedByInactivity {
                return "\(displayName) pausou o treino"
            }
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
                        : isWaterSportShare
                            ? Color.cyan.opacity(0.14)
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

            // Ondas animadas transparentes (Surf / Kitesurf) — decoração sob o texto.
            if isWaterSportShare {
                VStack {
                    Spacer(minLength: 0)
                    TransparentOceanWavesView(
                        tint: Color(red: 0.45, green: 0.82, blue: 0.98),
                        baseOpacity: 0.32,
                        waveCount: 3
                    )
                    .frame(height: 168)
                }
                .allowsHitTesting(false)
            }
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
            if session.isDuoTeamSession {
                Text(duoTeamBadgeLabel)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color("AccentGreen").opacity(0.95))
                    .clipShape(Capsule())
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(formattedDate)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var duoTeamBadgeLabel: String {
        let name = session.duoTeamName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty { return "EQUIPE" }
        if name.count <= 16 { return name.uppercased() }
        return String(name.prefix(14)).uppercased() + "…"
    }

    private var achievementBadge: some View {
        let outer: CGFloat = needsExtraTextSpace ? 48 : 58
        let inner: CGFloat = needsExtraTextSpace ? 38 : 46
        let iconSize: CGFloat = needsExtraTextSpace ? 18 : 22
        let photoSize: CGFloat = needsExtraTextSpace ? 40 : 48
        let accent = modalityAccentColor

        return HStack(spacing: profileImage == nil ? 0 : -8) {
            ZStack {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                accent,
                                Color("AccentOrange"),
                                accent
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
                    .foregroundStyle(accent)
                    .symbolRenderingMode(.hierarchical)
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
                            .strokeBorder(accent.opacity(0.9), lineWidth: 2)
                    )
                    .zIndex(0)
            }
        }
    }

    /// SF Symbol da modalidade do treino (cardio catálogo, outdoor, meditação ou força).
    private var badgeIcon: String {
        if session.presentsAsIncompleteOnShareCard {
            return "flame.fill"
        }
        return Self.modalitySystemImage(for: session)
    }

    private var modalityAccentColor: Color {
        if session.presentsAsIncompleteOnShareCard {
            return Color("AccentOrange")
        }
        if isMeditation {
            return Color.purple.opacity(0.9)
        }
        if session.isOutdoorCyclingSession {
            return Color(red: 1.0, green: 0.78, blue: 0.15)
        }
        if isRunning || isCardio {
            return Color("AccentOrange")
        }
        return Color("AccentGreen")
    }

    /// Ícone por modalidade — usa catálogo de cardio quando o título bate.
    static func modalitySystemImage(for session: WorkoutSession) -> String {
        let title = session.workoutTitle
        let lower = title.lowercased()

        if WeeklyProgressAnalyzer.isMeditationSession(session)
            || lower.hasPrefix("meditação")
            || lower.hasPrefix("meditacao") {
            return "brain.head.profile"
        }

        if session.isKitesurfSession
            || lower.contains("kitesurf")
            || lower.contains("kite surf") {
            return CardioExercise.kitesurfSystemImage
        }
        if session.isSurfSession || lower.contains("surf") {
            return CardioExercise.surfSystemImage
        }

        if session.isOutdoorCyclingSession
            || lower.contains("mountain bike")
            || lower.contains("bicicleta pedal")
            || lower.contains("bike outdoor") {
            return "bicycle"
        }

        if session.isOutdoorWalkingSession
            || lower.contains("caminhada")
            || lower.contains("walking") {
            return "figure.walk"
        }

        if session.isRunningSession || lower.contains("corrida") {
            return "figure.run"
        }

        // Cardio indoor/outdoor: casa com o ícone do exercício no catálogo (nome mais longo primeiro).
        if let catalogMatch = CardioExercise.catalog
            .sorted(by: { $0.name.count > $1.name.count })
            .first(where: { lower.contains($0.name.lowercased()) }) {
            return catalogMatch.icon
        }

        if lower.hasPrefix("cardio") {
            return "figure.mixed.cardio"
        }

        // Musculação / ficha
        return "dumbbell.fill"
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

    private func shareStat(value: String, label: String, showsPeakArrow: Bool = false) -> some View {
        VStack(spacing: needsExtraTextSpace ? 2 : 3) {
            HStack(spacing: 3) {
                if showsPeakArrow {
                    Image(systemName: "arrow.up")
                        .font(.system(size: needsExtraTextSpace ? 8 : 10, weight: .heavy))
                        .foregroundStyle(Color("AccentOrange"))
                }
                Text(value)
                    .font(.system(size: needsExtraTextSpace ? 11 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            }
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

enum ShareCardRouteMapStyle: String, CaseIterable, Identifiable {
    case flat2D
    case perspective3D

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flat2D: return "2D"
        case .perspective3D: return "3D"
        }
    }
}

/// Fundo escuro estilo mapa + polyline colorida por desempenho. Sem MapKit (flaky no ImageRenderer).
/// 2D/3D desenhados em Canvas com projeção manual — `rotation3DEffect` não renderiza bem no export.
struct ShareCardRouteMapView: View {
    let routePoints: [RouteCoordinate]
    var distanceKm: Double = 0
    var performanceMetric: RoutePerformanceMetric = .pace
    var style: ShareCardRouteMapStyle = .flat2D
    /// Kitesurf: marca o ponto da maior velocidade com seta.
    var markMaxSpeedArrow: Bool = false

    private var hasRoute: Bool { routePoints.count >= 2 }

    /// Limita pontos para ImageRenderer / WhatsApp (rota longa).
    private var renderPoints: [RouteCoordinate] {
        Self.downsample(routePoints, maxCount: style == .perspective3D ? 180 : 280)
    }

    private var maxSpeedIndex: Int? {
        guard markMaxSpeedArrow else { return nil }
        return KitePostingMetrics.maxSpeedRouteIndex(in: renderPoints)
    }

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

                if hasRoute {
                    Canvas { context, canvasSize in
                        drawMapGrid(context: &context, size: canvasSize)
                        drawRoute(context: &context, size: canvasSize)
                    }
                } else {
                    mapGrid(in: size)
                    placeholderContent
                }

                if style == .perspective3D, hasRoute {
                    Text("3D")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(8)
                }

                if hasRoute, distanceKm > 0 {
                    Text(String(format: "%.2f km", distanceKm))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("AccentGreen").opacity(0.95))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(8)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func drawMapGrid(context: inout GraphicsContext, size: CGSize) {
        let hStep = size.width / 6
        let vStep = size.height / 4
        var path = Path()
        for i in 1..<6 {
            let x = CGFloat(i) * hStep
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        for i in 1..<4 {
            let y = CGFloat(i) * vStep
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 1)

        var roads = Path()
        roads.move(to: CGPoint(x: 0, y: size.height * 0.35))
        roads.addLine(to: CGPoint(x: size.width, y: size.height * 0.55))
        roads.move(to: CGPoint(x: size.width * 0.2, y: 0))
        roads.addLine(to: CGPoint(x: size.width * 0.75, y: size.height))
        context.stroke(roads, with: .color(.white.opacity(0.05)), lineWidth: 2)
    }

    private func drawRoute(context: inout GraphicsContext, size: CGSize) {
        let flat = projectedFlatPoints(renderPoints, in: size, padding: 18)
        let projected: [CGPoint] = style == .perspective3D
            ? flat.map { projectPerspective($0, in: size) }
            : flat
        guard projected.count >= 2 else { return }

        let segments = RoutePerformanceColoring.segments(from: renderPoints, metric: performanceMetric)
        let lineWidth: CGFloat = style == .perspective3D ? 3.0 : 2.4

        var shadow = Path()
        shadow.move(to: projected[0])
        for point in projected.dropFirst() {
            shadow.addLine(to: point)
        }
        context.stroke(
            shadow,
            with: .color(.black.opacity(0.45)),
            style: StrokeStyle(lineWidth: lineWidth + 2.5, lineCap: .round, lineJoin: .round)
        )

        for index in 0..<(projected.count - 1) {
            var segmentPath = Path()
            segmentPath.move(to: projected[index])
            segmentPath.addLine(to: projected[index + 1])
            let color = index < segments.count ? segments[index].color : Color("AccentOrange")
            context.stroke(
                segmentPath,
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }

        let start = projected[0]
        let end = projected[projected.count - 1]
        let startRect = CGRect(x: start.x - 5, y: start.y - 5, width: 10, height: 10)
        let endRect = CGRect(x: end.x - 5, y: end.y - 5, width: 10, height: 10)
        context.fill(Path(ellipseIn: startRect), with: .color(Color("AccentGreen")))
        context.stroke(Path(ellipseIn: startRect), with: .color(.white), lineWidth: 1.5)
        context.fill(Path(ellipseIn: endRect), with: .color(segments.last?.color ?? Color("AccentOrange")))
        context.stroke(Path(ellipseIn: endRect), with: .color(.white), lineWidth: 1.5)

        if let maxIdx = maxSpeedIndex, maxIdx >= 0, maxIdx < projected.count {
            let peak = projected[maxIdx]
            // Seta apontando para o ponto da maior velocidade.
            let tip = CGPoint(x: peak.x, y: peak.y - 14)
            var arrow = Path()
            arrow.move(to: tip)
            arrow.addLine(to: CGPoint(x: peak.x - 6, y: peak.y - 4))
            arrow.addLine(to: CGPoint(x: peak.x + 6, y: peak.y - 4))
            arrow.closeSubpath()
            context.fill(arrow, with: .color(Color("AccentOrange")))
            context.stroke(arrow, with: .color(.white.opacity(0.9)), lineWidth: 1)
            let peakDot = CGRect(x: peak.x - 4, y: peak.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: peakDot), with: .color(Color("AccentOrange")))
            context.stroke(Path(ellipseIn: peakDot), with: .color(.white), lineWidth: 1.2)
        }
    }

    /// Projeção em perspectiva isométrica leve (sem rotation3DEffect).
    private func projectPerspective(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let nx = (point.x / max(size.width, 1)) - 0.5
        let ny = (point.y / max(size.height, 1)) - 0.5
        let depth = 1.0 + (-ny) * 0.62
        let scale = 1.0 / max(depth, 0.55)
        let x = size.width * 0.5 + nx * size.width * scale * 0.92
        let y = size.height * 0.58 + ny * size.height * scale * 0.42 + size.height * 0.02
        return CGPoint(x: x, y: y)
    }

    private func mapGrid(in _: CGSize) -> some View {
        Canvas { context, canvasSize in
            drawMapGrid(context: &context, size: canvasSize)
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

    private func projectedFlatPoints(_ coords: [RouteCoordinate], in size: CGSize, padding: CGFloat) -> [CGPoint] {
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
            let y = originY + CGFloat((maxLat - point.latitude) / latSpan) * usedHeight
            return CGPoint(x: x, y: y)
        }
    }

    private static func downsample(_ points: [RouteCoordinate], maxCount: Int) -> [RouteCoordinate] {
        guard points.count > maxCount, maxCount > 2 else { return points }
        let step = Double(points.count - 1) / Double(maxCount - 1)
        var result: [RouteCoordinate] = []
        result.reserveCapacity(maxCount)
        for i in 0..<maxCount {
            let index = min(points.count - 1, Int((Double(i) * step).rounded()))
            result.append(points[index])
        }
        return result
    }
}

/// Renderiza o mapa do percurso para Stories / Pulse / e-mail.
/// 2D: canvas leve. 3D: snapshot MapKit híbrido com câmera inclinada (igual à Rota).
enum WorkoutRouteMapRenderer {
    static let emailAttachmentFileName = "rota-treino.png"
    static let emailAttachmentMimeType = "image/png"

    @MainActor
    static func renderImage(
        session: WorkoutSession,
        width: CGFloat = 900,
        height: CGFloat = 560,
        style: ShareCardRouteMapStyle = .flat2D
    ) async -> UIImage? {
        guard session.routePoints.count >= 2 else { return nil }
        if style == .perspective3D {
            return await renderMapKit3DImage(
                routePoints: session.routePoints,
                performanceMetric: session.routePerformanceMetric,
                distanceKm: session.displayDistanceKm,
                markMaxSpeedArrow: session.isKitesurfSession,
                width: width,
                height: height
            )
        }
        return renderFlatCanvasImage(
            routePoints: session.routePoints,
            performanceMetric: session.routePerformanceMetric,
            distanceKm: session.displayDistanceKm,
            markMaxSpeedArrow: session.isKitesurfSession,
            style: .flat2D,
            width: width,
            height: height
        )
    }

    /// Versão síncrona (PDF/mail) — sempre canvas 2D.
    @MainActor
    static func renderFlatImage(
        session: WorkoutSession,
        width: CGFloat = 900,
        height: CGFloat = 560
    ) -> UIImage? {
        guard session.routePoints.count >= 2 else { return nil }
        return renderFlatCanvasImage(
            routePoints: session.routePoints,
            performanceMetric: session.routePerformanceMetric,
            distanceKm: session.displayDistanceKm,
            markMaxSpeedArrow: session.isKitesurfSession,
            style: .flat2D,
            width: width,
            height: height
        )
    }

    @MainActor
    private static func renderFlatCanvasImage(
        routePoints: [RouteCoordinate],
        performanceMetric: RoutePerformanceMetric,
        distanceKm: Double,
        markMaxSpeedArrow: Bool,
        style: ShareCardRouteMapStyle,
        width: CGFloat,
        height: CGFloat
    ) -> UIImage? {
        let map = ShareCardRouteMapView(
            routePoints: routePoints,
            distanceKm: distanceKm,
            performanceMetric: performanceMetric,
            style: style,
            markMaxSpeedArrow: markMaxSpeedArrow
        )
        .frame(width: width, height: height)

        let renderer = ImageRenderer(content: map)
        renderer.scale = 2
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Snapshot MapKit com pitch — mesmo espírito do mapa 3D da seção Rota.
    @MainActor
    private static func renderMapKit3DImage(
        routePoints: [RouteCoordinate],
        performanceMetric: RoutePerformanceMetric,
        distanceKm: Double,
        markMaxSpeedArrow: Bool,
        width: CGFloat,
        height: CGFloat
    ) async -> UIImage? {
        let points = downsample(routePoints, maxCount: 220)
        guard points.count >= 2 else { return nil }

        let size = CGSize(width: width, height: height)
        let options = MKMapSnapshotter.Options()
        options.size = size
        options.scale = UIScreen.main.scale
        options.mapType = .hybridFlyover
        options.showsBuildings = true
        options.camera = mapCamera3D(for: points)

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot: MKMapSnapshotter.Snapshot
        do {
            snapshot = try await snapshotter.start()
        } catch {
            // Fallback: hybrid plano se flyover falhar (offline / região).
            options.mapType = .hybrid
            options.camera = mapCamera3D(for: points)
            do {
                snapshot = try await MKMapSnapshotter(options: options).start()
            } catch {
                return renderFlatCanvasImage(
                    routePoints: routePoints,
                    performanceMetric: performanceMetric,
                    distanceKm: distanceKm,
                    markMaxSpeedArrow: markMaxSpeedArrow,
                    style: .perspective3D,
                    width: width,
                    height: height
                )
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = snapshot.image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            snapshot.image.draw(in: CGRect(origin: .zero, size: size))

            let projected = points.map { snapshot.point(for: $0.coordinate) }
            guard projected.count >= 2 else { return }

            let cg = ctx.cgContext
            let segments = RoutePerformanceColoring.segments(from: points, metric: performanceMetric)

            // Sombra sob a rota (legibilidade no satélite).
            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.45).cgColor)
            cg.setLineWidth(6)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            cg.beginPath()
            cg.move(to: projected[0])
            for p in projected.dropFirst() { cg.addLine(to: p) }
            cg.strokePath()

            for index in 0..<(projected.count - 1) {
                let color = (index < segments.count ? UIColor(segments[index].color) : UIColor.systemOrange)
                cg.setStrokeColor(color.cgColor)
                cg.setLineWidth(3.6)
                cg.setLineCap(.round)
                cg.setLineJoin(.round)
                cg.beginPath()
                cg.move(to: projected[index])
                cg.addLine(to: projected[index + 1])
                cg.strokePath()
            }

            // Início / fim.
            drawEndpoint(cg: cg, at: projected[0], fill: UIColor(Color("AccentGreen")))
            let endColor = segments.last.map { UIColor($0.color) } ?? .systemOrange
            drawEndpoint(cg: cg, at: projected[projected.count - 1], fill: endColor)

            if markMaxSpeedArrow,
               let maxIdx = KitePostingMetrics.maxSpeedRouteIndex(in: points),
               maxIdx >= 0, maxIdx < projected.count {
                let peak = projected[maxIdx]
                let tip = CGPoint(x: peak.x, y: peak.y - 16)
                cg.setFillColor(UIColor(Color("AccentOrange")).cgColor)
                cg.beginPath()
                cg.move(to: tip)
                cg.addLine(to: CGPoint(x: peak.x - 7, y: peak.y - 4))
                cg.addLine(to: CGPoint(x: peak.x + 7, y: peak.y - 4))
                cg.closePath()
                cg.fillPath()
            }

            if distanceKm > 0 {
                let label = String(format: "%.2f km", distanceKm) as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let textSize = label.size(withAttributes: attrs)
                let pad: CGFloat = 8
                let rect = CGRect(
                    x: 12,
                    y: size.height - textSize.height - pad * 2 - 12,
                    width: textSize.width + pad * 2,
                    height: textSize.height + pad
                )
                UIColor.black.withAlphaComponent(0.4).setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
                label.draw(
                    at: CGPoint(x: rect.minX + pad, y: rect.minY + pad / 2),
                    withAttributes: attrs
                )
            }

            // Badge 3D
            let badge = "3D" as NSString
            let badgeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let badgeSize = badge.size(withAttributes: badgeAttrs)
            let badgeRect = CGRect(
                x: size.width - badgeSize.width - 28,
                y: 12,
                width: badgeSize.width + 16,
                height: badgeSize.height + 10
            )
            UIColor.black.withAlphaComponent(0.4).setFill()
            UIBezierPath(roundedRect: badgeRect, cornerRadius: 10).fill()
            badge.draw(
                at: CGPoint(x: badgeRect.minX + 8, y: badgeRect.minY + 5),
                withAttributes: badgeAttrs
            )
        }
    }

    private static func drawEndpoint(cg: CGContext, at point: CGPoint, fill: UIColor) {
        let rect = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
        cg.setFillColor(fill.cgColor)
        cg.fillEllipse(in: rect)
        cg.setStrokeColor(UIColor.white.cgColor)
        cg.setLineWidth(2)
        cg.strokeEllipse(in: rect)
    }

    private static func mapCamera3D(for points: [RouteCoordinate]) -> MKMapCamera {
        var minLat = points[0].latitude, maxLat = points[0].latitude
        var minLon = points[0].longitude, maxLon = points[0].longitude
        for p in points {
            minLat = min(minLat, p.latitude); maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude); maxLon = max(maxLon, p.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latM = max(maxLat - minLat, 0.004) * 111_320
        let lonM = max(maxLon - minLon, 0.004) * 111_320 * max(cos(center.latitude * .pi / 180), 0.2)
        let distance = max(700, min(max(latM, lonM) * 2.6, 18_000))
        return MKMapCamera(
            lookingAtCenter: center,
            fromDistance: distance,
            pitch: 58,
            heading: bearing(for: points)
        )
    }

    private static func bearing(for points: [RouteCoordinate]) -> CLLocationDirection {
        guard points.count >= 2 else { return 20 }
        let sampleCount = min(8, points.count)
        let start = points[points.count - sampleCount]
        let end = points[points.count - 1]
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let dLon = (end.longitude - start.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    private static func downsample(_ points: [RouteCoordinate], maxCount: Int) -> [RouteCoordinate] {
        guard points.count > maxCount, maxCount >= 2 else { return points }
        let step = Double(points.count - 1) / Double(maxCount - 1)
        var result: [RouteCoordinate] = []
        result.reserveCapacity(maxCount)
        for i in 0..<maxCount {
            let index = min(Int((Double(i) * step).rounded()), points.count - 1)
            result.append(points[index])
        }
        if result.last?.id != points.last?.id {
            result[result.count - 1] = points[points.count - 1]
        }
        return result
    }

    @MainActor
    static func pngData(for session: WorkoutSession, style: ShareCardRouteMapStyle = .flat2D) async -> Data? {
        await renderImage(session: session, style: style)?.pngData()
    }

    @MainActor
    static func mailAttachment(
        for session: WorkoutSession,
        style: ShareCardRouteMapStyle = .flat2D
    ) -> MailAttachment? {
        // Anexo de e-mail permanece 2D (síncrono / leve).
        _ = style
        guard let data = renderFlatImage(session: session)?.pngData() else { return nil }
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
            profileImage: profileImage,
            clipsRoundedCorners: false
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
        let modality = session.completedModalityTitle
        let teamName = session.duoTeamName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let teamPart = session.isDuoTeamSession
            ? (teamName.isEmpty ? " · treino em equipe" : " · equipe \(teamName)")
            : ""
        let teamTags = session.isDuoTeamSession ? " #TreinoEmEquipe #Dupla" : ""
        if session.isOutdoorGPSCardio {
            let km = session.displayDistanceKm
            let kmPart = km > 0 ? String(format: " · %.2f km", km) : ""
            let (noun, verb, tag) = outdoorShareCopy(for: session)
            if session.presentsAsIncompleteOnShareCard {
                return """
                \(who) \(verb) (não concluiu): \(modality) · \(duration)\(kmPart)\(teamPart)
                Cada sessão conta — HealthFit 💪
                #HealthFit \(tag) #Treino\(teamTags)
                """
            }
            return """
            \(who) finalizou \(noun): \(modality) · \(duration)\(kmPart)\(teamPart)
            Treinei com HealthFit 💪
            #HealthFit \(tag) #Treino\(teamTags)
            """
        }
        if session.presentsAsIncompleteOnShareCard {
            return """
            \(who) treinou (não concluiu): \(modality) · \(duration)\(teamPart)
            Cada sessão conta — HealthFit 💪
            #HealthFit #Treino #Evolucao\(teamTags)
            """
        }
        return """
        \(who) finalizou: \(modality) · \(duration)\(teamPart)
        Treinei com HealthFit 💪
        #HealthFit #Treino #Evolucao\(teamTags)
        """
    }

    /// Copy de legenda / hashtag alinhado à modalidade outdoor.
    private static func outdoorShareCopy(for session: WorkoutSession) -> (noun: String, verb: String, tag: String) {
        if session.isKitesurfSession {
            return ("o kitesurf", "kitesurfou", "#Kitesurf")
        }
        if session.isSurfSession {
            return ("o surf", "surfou", "#Surf")
        }
        if session.isSwimmingSession {
            return ("a natação", "nadou", "#Natacao")
        }
        if session.isOutdoorCyclingSession {
            return ("o pedal", "pedalou", "#Ciclismo")
        }
        if session.isOutdoorWalkingSession {
            return ("a caminhada", "caminhou", "#Caminhada")
        }
        return ("a corrida", "correu", "#Corrida")
    }

    static func motivationLine(for session: WorkoutSession) -> String {
        if session.presentsAsIncompleteOnShareCard {
            if session.autoEndedByInactivity {
                return "O importante é mostrar up. O próximo você fecha com chave de ouro."
            }
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
                if session.isKitesurfSession {
                    return [
                        "Vento, água e presença. Sessão de kite fechada.",
                        "Cada virada e salto contam. Evolução no kite.",
                        "Você foi à água e kitesurfou. Orgulho merecido.",
                        "O mar responde a quem aparece com o kite.",
                        "Constância no kite, evolução no corpo e na mente."
                    ]
                }
                if session.isSurfSession {
                    return [
                        "Ondas e presença. Sessão de surf fechada.",
                        "Cada wave conta. Ritmo, equilíbrio e foco.",
                        "Você foi à água e surfou. Orgulho merecido.",
                        "O mar responde a quem aparece na prancha.",
                        "Constância no surf, evolução no corpo."
                    ]
                }
                if session.isSwimmingSession {
                    return [
                        "Voltas na água viram disciplina.",
                        "Você nadou com presença. Orgulho merecido.",
                        "Ritmo na piscina, mente focada.",
                        "Cada braçada conta. Evolução na natação.",
                        "Constância na água, progresso no corpo."
                    ]
                }
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
            DispatchQueue.main.async { onComplete?() }
        }
        if let popover = controller.popoverPresentationController {
            // UIView() órfão derruba o app no iPad — ancora na janela ativa.
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)
            popover.sourceView = window ?? controller.view
            if let bounds = window?.bounds ?? controller.view?.bounds {
                popover.sourceRect = CGRect(x: bounds.midX, y: bounds.midY, width: 1, height: 1)
            }
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Apresenta `UIActivityViewController` no VC topo (evita crash de sheet SwiftUI aninhada).
@MainActor
enum ActivitySharePresenter {
    static func present(items: [Any], completion: (() -> Void)? = nil) {
        guard !items.isEmpty else {
            completion?()
            return
        }
        guard let presenter = topViewController() else {
            completion?()
            return
        }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async { completion?() }
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = presenter.view
            let bounds = presenter.view.bounds
            popover.sourceRect = CGRect(x: bounds.midX, y: bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        presenter.present(controller, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
              let root = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
                ?? windowScene.windows.first?.rootViewController
        else { return nil }

        var controller = root
        while let presented = controller.presentedViewController {
            controller = presented
        }
        return controller
    }
}
