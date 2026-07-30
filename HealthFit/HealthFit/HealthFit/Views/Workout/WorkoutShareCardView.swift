import SwiftUI
import UIKit

/// Card visual de conquista para Stories / status (WhatsApp & Instagram).
struct WorkoutShareCardView: View {
    let session: WorkoutSession
    let athleteName: String
    let motivationLine: String

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
                    .padding(.top, 28)
                    .padding(.horizontal, 28)

                Spacer(minLength: 20)

                achievementBadge
                    .padding(.bottom, 18)

                Text(headline)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Text(motivationLine)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.top, 10)

                Text(session.workoutTitle)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color("AccentGreen"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 16)

                statsRow
                    .padding(.top, 28)
                    .padding(.horizontal, 24)

                Spacer(minLength: 20)

                footer
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            }
        }
        .frame(width: 360, height: 450)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var headline: String {
        if session.endedEarly && !session.autoEndedByInactivity {
            return "\(displayName) treinou hoje"
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
                    Color(red: 0.05, green: 0.08, blue: 0.07),
                    Color(red: 0.08, green: 0.14, blue: 0.11),
                    Color(red: 0.06, green: 0.10, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color("AccentGreen").opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 50)
                .offset(x: -90, y: -140)

            Circle()
                .fill(Color("AccentOrange").opacity(0.18))
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
                    .frame(width: 22, height: 22)
                Text("HealthFit")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(0.6)
            }
            Spacer()
            Text(formattedDate)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
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
                    lineWidth: 3
                )
                .frame(width: 88, height: 88)

            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 72, height: 72)

            Image(systemName: badgeIcon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color("AccentGreen"))
        }
    }

    private var badgeIcon: String {
        if isMeditation { return "brain.head.profile" }
        if isCardio { return "figure.run" }
        return "trophy.fill"
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
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
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Treinei com HealthFit")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Text("Disciplina · Evolução · Constância")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

enum WorkoutShareCardRenderer {
    @MainActor
    static func renderImage(
        session: WorkoutSession,
        athleteName: String,
        motivationLine: String
    ) -> UIImage? {
        let card = WorkoutShareCardView(
            session: session,
            athleteName: athleteName,
            motivationLine: motivationLine
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
            return "Cada sessão conta. Voltar amanhã já é vitória."
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
