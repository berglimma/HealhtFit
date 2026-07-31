import SwiftUI
import UIKit

/// Card visual de conquista para Stories / status (WhatsApp & Instagram).
struct WorkoutShareCardView: View {
    let session: WorkoutSession
    let athleteName: String
    let motivationLine: String
    /// Sessões recentes (opcional) para sparkline de durações no card.
    var recentSessions: [WorkoutSession] = []

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

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd MMM yyyy · HH:mm"
        return formatter.string(from: session.endedAt ?? session.startedAt).uppercased()
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                brandHeader
                    .padding(.top, 22)
                    .padding(.horizontal, 24)

                Spacer(minLength: 10)

                achievementBadge
                    .padding(.bottom, 10)

                Text(headline)
                    .font(.system(size: session.endedEarly ? 22 : 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(session.endedEarly ? 3 : 2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 24)

                if !motivationLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(motivationLine)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 28)
                        .padding(.top, 6)
                }

                Text(session.workoutTitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color("AccentGreen"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                summaryChartSection
                    .padding(.top, 12)
                    .padding(.horizontal, 22)

                statsRow
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                Spacer(minLength: 10)

                footer
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
            }
        }
        .frame(width: 360, height: 450)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
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
                .fill(Color("AccentGreen").opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 50)
                .offset(x: -90, y: -140)

            Circle()
                .fill(Color("AccentOrange").opacity(0.13))
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
        HStack {
            HStack(spacing: 8) {
                Image("BrandHeart")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("HealthFit")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(0.6)
            }
            Spacer()
            Text(formattedDate)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var achievementBadge: some View {
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
                    lineWidth: 2.5
                )
                .frame(width: 64, height: 64)

            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 52, height: 52)

            Image(systemName: badgeIcon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color("AccentGreen"))
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
            VStack(alignment: .leading, spacing: 8) {
                if showsCardioChart {
                    cardioMeditationChart
                } else if showsStrengthChart {
                    strengthExerciseChart
                }

                if showsRecentSparkline {
                    recentDurationSparkline
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
        }
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
                            .frame(height: max(6, CGFloat(item.value / maxValue) * 46))

                        Text(item.label)
                            .font(.system(size: 7, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 62, alignment: .bottom)
        }
    }

    private var cardioMeditationChart: some View {
        let metrics = cardioMetricBars
        let maxValue = max(metrics.map(\.value).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 6) {
            Text(isMeditation ? "SESSÃO" : "PERFORMANCE")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(0.6)

            VStack(spacing: 5) {
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
                                .frame(height: 7)
                            Capsule()
                                .fill(metric.color)
                                .frame(width: 168 * ratio, height: 7)
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
                        .frame(height: max(4, CGFloat(value / maxValue) * 22))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 22, alignment: .bottom)
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
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Treinei com HealthFit")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Text("Disciplina · Evolução · Constância")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

enum WorkoutShareCardRenderer {
    @MainActor
    static func renderImage(
        session: WorkoutSession,
        athleteName: String,
        motivationLine: String,
        recentSessions: [WorkoutSession] = []
    ) -> UIImage? {
        let card = WorkoutShareCardView(
            session: session,
            athleteName: athleteName,
            motivationLine: motivationLine,
            recentSessions: recentSessions
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
