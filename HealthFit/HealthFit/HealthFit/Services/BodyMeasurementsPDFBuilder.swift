import Foundation
import PDFKit
import UIKit

enum BodyMeasurementsPDFBuilder {
    @MainActor static func build(
        evaluation: BodyEvolutionEvaluation,
        athleteName: String,
        cycleNote: String? = nil
    ) -> Data {
        let pageRect = HealthFitPDFChrome.pageRect
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            let layout = HealthFitPDFPageLayout(
                context: context,
                documentTitle: "Evolução Corporal"
            )
            layout.beginPage()

            layout.draw("Evolução Corporal", attrs: HealthFitPDFChrome.titleAttributes())
            layout.draw("Atleta: \(athleteName)", attrs: HealthFitPDFChrome.headingAttributes())
            layout.draw(
                "Avaliação em \(formatted(evaluation.createdAt)) · \(evaluation.periodDays) dia(s)",
                attrs: HealthFitPDFChrome.metaAttributes(),
                spacingAfter: 12
            )

            layout.draw("Resumo", attrs: HealthFitPDFChrome.accentHeadingAttributes())
            layout.draw(evaluation.summaryText, attrs: HealthFitPDFChrome.bodyAttributes(), spacingAfter: 14)

            layout.draw("Medidas corporais (cm)", attrs: HealthFitPDFChrome.accentHeadingAttributes())

            let cg = context.cgContext
            drawTableHeader(
                at: layout.y,
                left: layout.left,
                width: layout.width,
                font: HealthFitPDFChrome.captionFont(),
                context: cg
            )
            layout.y += 22

            let labels = evaluation.currentMeasurements.labeledValues.map(\.label)
            for label in labels {
                let previous = value(for: label, in: evaluation.previousMeasurements)
                let current = value(for: label, in: evaluation.currentMeasurements)
                guard previous != nil || current != nil else { continue }

                layout.ensureSpace(22)

                let delta: Double? = {
                    guard let previous, let current else { return nil }
                    return current - previous
                }()

                drawRow(
                    label: label,
                    previous: previous.map(BodyMeasurements.formatCm) ?? "—",
                    current: current.map(BodyMeasurements.formatCm) ?? "—",
                    delta: delta.map(BodyMeasurements.formatDelta) ?? "—",
                    at: layout.y,
                    left: layout.left,
                    width: layout.width,
                    font: HealthFitPDFChrome.captionFont()
                )
                layout.y += 18
            }

            layout.addVerticalSpace(16)
            if let cycleNote, !cycleNote.isEmpty {
                layout.draw("Ciclo menstrual", attrs: HealthFitPDFChrome.accentHeadingAttributes())
                layout.draw(cycleNote, attrs: HealthFitPDFChrome.bodyAttributes(), spacingAfter: 14)
            }
            layout.draw(
                "Fotos de evolução são opcionais e privadas (somente o titular da conta). Fotos antigas são excluídas após cada comparação. Este PDF permanece entre as últimas \(BodyEvolutionEvaluation.maxRetainedEvaluations) avaliações da sua conta.",
                attrs: HealthFitPDFChrome.metaAttributes()
            )
            layout.draw(
                "Documento gerado pelo HealthFit. Em caso de dúvida sobre saúde, procure um profissional habilitado.",
                attrs: HealthFitPDFChrome.metaAttributes()
            )
        }
    }

    private static func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func value(for label: String, in measurements: BodyMeasurements) -> Double? {
        measurements.labeledValues.first { $0.label == label }?.value
    }

    @MainActor private static func drawTableHeader(
        at y: CGFloat,
        left: CGFloat,
        width: CGFloat,
        font: UIFont,
        context: CGContext
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: HealthFitPDFChrome.textSecondary,
        ]
        let col1 = left
        let col2 = left + width * 0.40
        let col3 = left + width * 0.62
        let col4 = left + width * 0.82
        ("Medida" as NSString).draw(at: CGPoint(x: col1, y: y), withAttributes: attrs)
        ("Antes" as NSString).draw(at: CGPoint(x: col2, y: y), withAttributes: attrs)
        ("Depois" as NSString).draw(at: CGPoint(x: col3, y: y), withAttributes: attrs)
        ("Delta" as NSString).draw(at: CGPoint(x: col4, y: y), withAttributes: attrs)

        context.setStrokeColor(HealthFitPDFChrome.accentGreen.withAlphaComponent(0.45).cgColor)
        context.setLineWidth(0.8)
        context.move(to: CGPoint(x: left, y: y + 16))
        context.addLine(to: CGPoint(x: left + width, y: y + 16))
        context.strokePath()
    }

    @MainActor private static func drawRow(
        label: String,
        previous: String,
        current: String,
        delta: String,
        at y: CGFloat,
        left: CGFloat,
        width: CGFloat,
        font: UIFont
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: HealthFitPDFChrome.textPrimary,
        ]
        let col1 = left
        let col2 = left + width * 0.40
        let col3 = left + width * 0.62
        let col4 = left + width * 0.82
        (label as NSString).draw(at: CGPoint(x: col1, y: y), withAttributes: attrs)
        (previous as NSString).draw(at: CGPoint(x: col2, y: y), withAttributes: attrs)
        (current as NSString).draw(at: CGPoint(x: col3, y: y), withAttributes: attrs)
        (delta as NSString).draw(at: CGPoint(x: col4, y: y), withAttributes: attrs)
    }
}
