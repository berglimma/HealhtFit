import UIKit

    /// PDF do relatório de treino (mesmo conteúdo textual do e-mail ao personal).
@MainActor
enum WorkoutSessionPDFBuilder {
    static func makePDF(
        session: WorkoutSession,
        athlete: UserProfile,
        allSessions: [WorkoutSession] = []
    ) -> URL? {
        let body = WorkoutReportBuilder.emailBody(
            session: session,
            athlete: athlete,
            allSessions: allSessions,
            routeMapAttachmentIncluded: WorkoutReportBuilder.hasRouteMapForEmail(session)
        )
        let subject = WorkoutReportBuilder.emailSubject(
            session: session,
            athleteName: athlete.greetingName.isEmpty ? athlete.name : athlete.greetingName
        )

        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HealthFit-Treino-\(UUID().uuidString.prefix(8)).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: page)
        do {
            try renderer.writePDF(to: url) { context in
                var y: CGFloat = 48
                let left: CGFloat = 48
                let width = page.width - 96

                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 18),
                    .foregroundColor: UIColor.label
                ]
                let bodyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.label
                ]
                let metaAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.secondaryLabel
                ]

                func draw(_ text: String, attrs: [NSAttributedString.Key: Any]) {
                    let bounding = (text as NSString).boundingRect(
                        with: CGSize(width: width, height: 2000),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attrs,
                        context: nil
                    )
                    if y + bounding.height > page.height - 48 {
                        context.beginPage()
                        y = 48
                    }
                    (text as NSString).draw(
                        in: CGRect(x: left, y: y, width: width, height: ceil(bounding.height) + 2),
                        withAttributes: attrs
                    )
                    y += ceil(bounding.height) + 6
                }

                context.beginPage()
                draw("HealthFit — Relatório de Treino", attrs: titleAttrs)
                y += 4
                draw(subject, attrs: metaAttrs)
                y += 10

                for line in body.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        y += 8
                        continue
                    }
                    draw(line, attrs: bodyAttrs)
                }

                if let map = WorkoutRouteMapRenderer.renderImage(session: session, width: 1024, height: 640) {
                    y += 12
                    if y + 220 > page.height - 48 {
                        context.beginPage()
                        y = 48
                    }
                    draw("Mapa da rota", attrs: titleAttrs)
                    let mapRect = CGRect(x: left, y: y, width: width, height: 200)
                    map.draw(in: mapRect)
                    y += 208
                }
            }
            return url
        } catch {
            return nil
        }
    }
}

/// PDF do relatório semanal (Dashboard).
enum WeeklyReportPDFBuilder {
    static func makePDF(
        report: WeeklyProgressReport,
        athleteName: String
    ) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HealthFit-Semanal-\(UUID().uuidString.prefix(8)).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: page)
        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                var y: CGFloat = 48
                let left: CGFloat = 48
                let width = page.width - 96

                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 20),
                    .foregroundColor: UIColor.label
                ]
                let headingAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.label
                ]
                let bodyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.label
                ]

                func draw(_ text: String, attrs: [NSAttributedString.Key: Any]) {
                    let bounding = (text as NSString).boundingRect(
                        with: CGSize(width: width, height: 800),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attrs,
                        context: nil
                    )
                    if y + bounding.height > page.height - 48 {
                        context.beginPage()
                        y = 48
                    }
                    (text as NSString).draw(
                        in: CGRect(x: left, y: y, width: width, height: ceil(bounding.height) + 2),
                        withAttributes: attrs
                    )
                    y += ceil(bounding.height) + 8
                }

                draw("HealthFit — Relatório Semanal", attrs: titleAttrs)
                draw("Atleta: \(athleteName)", attrs: bodyAttrs)
                draw(report.periodLabel, attrs: bodyAttrs)
                draw("Pontuação: \(report.overallScore)/100", attrs: headingAttrs)
                y += 8

                draw("Estatísticas", attrs: headingAttrs)
                draw("Treinos: \(report.currentWeek.workoutCount)", attrs: bodyAttrs)
                draw("Minutos: \(report.currentWeek.totalMinutes)", attrs: bodyAttrs)
                draw("Calorias: \(Int(report.currentWeek.totalCalories))", attrs: bodyAttrs)
                draw("Dias ativos: \(report.currentWeek.activeDays)", attrs: bodyAttrs)
                y += 8

                if !report.highlights.isEmpty {
                    draw("Destaques", attrs: headingAttrs)
                    for item in report.highlights {
                        draw("• \(item)", attrs: bodyAttrs)
                    }
                    y += 4
                }

                if !report.improvements.isEmpty {
                    draw("O que melhorar", attrs: headingAttrs)
                    for item in report.improvements {
                        draw("• \(item.title): \(item.detail)", attrs: bodyAttrs)
                    }
                }
            }
            return url
        } catch {
            return nil
        }
    }
}
