import UIKit

enum ConsultationReportPDFBuilder {
    static func buildPDF(report: ConsultationAttendanceReport, coachName: String) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 40
            func draw(_ text: String, font: UIFont, color: UIColor = .black) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let rect = CGRect(x: 40, y: y, width: page.width - 80, height: 400)
                (text as NSString).draw(in: rect, withAttributes: attrs)
                let size = (text as NSString).boundingRect(
                    with: CGSize(width: page.width - 80, height: 400),
                    options: [.usesLineFragmentOrigin],
                    attributes: attrs,
                    context: nil
                ).height
                y += size + 8
            }

            let df = DateFormatter()
            df.locale = Locale(identifier: "pt_BR")
            df.dateStyle = .medium

            draw("HealthFit · Relatório de consultas", font: .boldSystemFont(ofSize: 18))
            draw("Profissional: \(coachName)", font: .systemFont(ofSize: 12))
            draw(
                "Período: \(df.string(from: report.periodStart)) – \(df.string(from: report.periodEnd))",
                font: .systemFont(ofSize: 12)
            )
            y += 8
            draw("Resumo de atendimento", font: .boldSystemFont(ofSize: 14))
            draw("Total de agendamentos: \(report.totalBookings)", font: .systemFont(ofSize: 12))
            draw("Confirmadas: \(report.confirmed)", font: .systemFont(ofSize: 12))
            draw("Concluídas: \(report.completed)", font: .systemFont(ofSize: 12))
            draw("Canceladas/recusadas: \(report.cancelled)", font: .systemFont(ofSize: 12))
            draw("Propostas: \(report.proposed)", font: .systemFont(ofSize: 12))
            draw("Taxa de conclusão (sobre confirmadas+concluídas+canceladas): \(report.showRatePercent)%", font: .systemFont(ofSize: 12))
            y += 8
            draw("Por dia da semana", font: .boldSystemFont(ofSize: 14))
            for row in report.byWeekday {
                draw("\(row.label): \(row.count)", font: .systemFont(ofSize: 12))
            }
            y += 8
            draw("Últimos agendamentos", font: .boldSystemFont(ofSize: 14))
            let tf = DateFormatter()
            tf.locale = Locale(identifier: "pt_BR")
            tf.dateFormat = "dd/MM HH:mm"
            for item in report.recent.prefix(12) {
                draw(
                    "\(tf.string(from: item.startAt)) · \(item.studentName) · \(item.status.title)",
                    font: .systemFont(ofSize: 11)
                )
                if y > page.height - 60 {
                    ctx.beginPage()
                    y = 40
                }
            }
        }
    }
}
