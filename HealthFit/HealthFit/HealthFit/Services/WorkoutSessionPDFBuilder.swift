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

        let page = HealthFitPDFChrome.pageRect
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HealthFit-Treino-\(UUID().uuidString.prefix(8)).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: page)
        do {
            try renderer.writePDF(to: url) { context in
                let layout = HealthFitPDFPageLayout(
                    context: context,
                    documentTitle: "Relatório de Treino"
                )
                layout.beginPage()

                layout.draw("Relatório de Treino", attrs: HealthFitPDFChrome.titleAttributes())
                layout.draw(subject, attrs: HealthFitPDFChrome.metaAttributes(), spacingAfter: 12)

                for line in body.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        layout.addVerticalSpace(8)
                        continue
                    }
                    layout.draw(line, attrs: HealthFitPDFChrome.bodyAttributes())
                }

                if let map = WorkoutRouteMapRenderer.renderImage(session: session, width: 1024, height: 640) {
                    layout.addVerticalSpace(8)
                    layout.drawImage(map, height: 200, caption: "Mapa da rota")
                }
            }
            return url
        } catch {
            return nil
        }
    }
}
