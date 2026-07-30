import Foundation
import PDFKit
import UIKit

enum BodyMeasurementsPDFBuilder {
    static func build(
        evaluation: BodyEvolutionEvaluation,
        athleteName: String
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()
            let cg = context.cgContext

            let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
            let headingFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
            let smallFont = UIFont.systemFont(ofSize: 9, weight: .regular)

            var y: CGFloat = 40
            let left: CGFloat = 40
            let width = pageRect.width - 80

            func draw(_ text: String, font: UIFont, color: UIColor = .black, maxWidth: CGFloat = width) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                ]
                let rect = CGRect(x: left, y: y, width: maxWidth, height: 800)
                let bounding = (text as NSString).boundingRect(
                    with: CGSize(width: maxWidth, height: 800),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                (text as NSString).draw(in: rect, withAttributes: attributes)
                y += ceil(bounding.height) + 8
            }

            draw("HealthFit — Evolução Corporal", font: titleFont)
            draw("Atleta: \(athleteName)", font: headingFont)
            draw(
                "Avaliação em \(formatted(evaluation.createdAt)) · \(evaluation.periodDays) dia(s)",
                font: bodyFont,
                color: .darkGray
            )
            y += 8

            draw("Resumo", font: headingFont)
            draw(evaluation.summaryText, font: bodyFont)
            y += 12

            draw("Medidas corporais (cm)", font: headingFont)

            let headerY = y
            drawTableHeader(at: headerY, left: left, width: width, font: smallFont, context: cg)
            y = headerY + 22

            let labels = evaluation.currentMeasurements.labeledValues.map(\.label)
            for label in labels {
                let previous = value(for: label, in: evaluation.previousMeasurements)
                let current = value(for: label, in: evaluation.currentMeasurements)
                guard previous != nil || current != nil else { continue }

                if y > pageRect.height - 60 {
                    context.beginPage()
                    y = 40
                    draw("HealthFit — Evolução Corporal (cont.)", font: headingFont)
                    y += 4
                    drawTableHeader(at: y, left: left, width: width, font: smallFont, context: cg)
                    y += 22
                }

                let delta: Double? = {
                    guard let previous, let current else { return nil }
                    return current - previous
                }()

                drawRow(
                    label: label,
                    previous: previous.map(BodyMeasurements.formatCm) ?? "—",
                    current: current.map(BodyMeasurements.formatCm) ?? "—",
                    delta: delta.map(BodyMeasurements.formatDelta) ?? "—",
                    at: y,
                    left: left,
                    width: width,
                    font: smallFont
                )
                y += 18
            }

            y += 16
            draw(
                "Fotos de evolução são opcionais e privadas (somente o titular da conta). Fotos antigas são excluídas após cada comparação. Este PDF permanece entre as últimas \(BodyEvolutionEvaluation.maxRetainedEvaluations) avaliações da sua conta.",
                font: smallFont,
                color: .darkGray
            )
            draw(
                "Documento gerado pelo HealthFit. Em caso de dúvida sobre saúde, procure um profissional habilitado.",
                font: smallFont,
                color: .gray
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

    private static func drawTableHeader(
        at y: CGFloat,
        left: CGFloat,
        width: CGFloat,
        font: UIFont,
        context: CGContext
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.darkGray,
        ]
        let col1 = left
        let col2 = left + width * 0.40
        let col3 = left + width * 0.62
        let col4 = left + width * 0.82
        ("Medida" as NSString).draw(at: CGPoint(x: col1, y: y), withAttributes: attrs)
        ("Antes" as NSString).draw(at: CGPoint(x: col2, y: y), withAttributes: attrs)
        ("Depois" as NSString).draw(at: CGPoint(x: col3, y: y), withAttributes: attrs)
        ("Delta" as NSString).draw(at: CGPoint(x: col4, y: y), withAttributes: attrs)

        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: left, y: y + 16))
        context.addLine(to: CGPoint(x: left + width, y: y + 16))
        context.strokePath()
    }

    private static func drawRow(
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
            .foregroundColor: UIColor.black,
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
