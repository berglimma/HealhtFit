import UIKit

/// Laudo de avaliação física (1 página A4) no modelo HealthFit.
enum PhysicalAssessmentPDFBuilder {
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let headerHeight: CGFloat = 70
    private static let footerHeight: CGFloat = 46

    private static let ink = UIColor(red: 0.16, green: 0.18, blue: 0.20, alpha: 1)
    private static let inkMuted = UIColor(red: 0.42, green: 0.44, blue: 0.46, alpha: 1)
    private static let brandGreen = UIColor(red: 0.45, green: 0.75, blue: 0.27, alpha: 1)
    private static let headerFill = UIColor(red: 0.18, green: 0.20, blue: 0.22, alpha: 1)
    private static let cardFill = UIColor(red: 0.96, green: 0.97, blue: 0.97, alpha: 1)
    private static let cardStroke = UIColor(red: 0.86, green: 0.87, blue: 0.88, alpha: 1)

    /// Logo reduzido (evita redesenhar BrandHeart 1024×1024 a cada export).
    private static let logoLock = NSLock()
    private static var _cachedLogo: UIImage?

    /// Prefira chamar na main antes de gerar o PDF em background.
    static func prepareForExport() {
        _ = brandLogo()
    }

    private static func brandLogo() -> UIImage? {
        logoLock.lock()
        defer { logoLock.unlock() }
        if let _cachedLogo { return _cachedLogo }
        guard let source = UIImage(named: "BrandHeart") else { return nil }
        let side: CGFloat = 96
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let reduced = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            source.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        _cachedLogo = reduced
        return reduced
    }

    static func writeTemporaryPDF(profile: UserProfile, measurements: BodyMeasurements) -> URL? {
        guard measurements.hasAnyValue || profile.weight > 0,
              let data = build(profile: profile, measurements: measurements) else { return nil }
        let slug = profile.shownName
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .replacingOccurrences(of: " ", with: "_")
        let stamp = Int(Date().timeIntervalSince1970)
        let file = "Avaliacao_Fisica_\(slug.isEmpty ? "HealthFit" : slug)_\(stamp).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(file)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func build(profile: UserProfile, measurements: BodyMeasurements) -> Data? {
        let rows = AssessmentRow.make(profile: profile, measurements: measurements)
        let evaluated = profile.shownName
        let evaluator = profile.personalTrainerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let date = measurements.measuredAt ?? Date()
        let code = assessmentCode(date: date, userId: profile.id)
        let notes = observations(rows: rows, gender: profile.gender)
        let evaluations = profile.recentMeasurementEvaluations(current: measurements)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { context in
            context.beginPage()
            let cg = context.cgContext
            UIColor.white.setFill()
            cg.fill(CGRect(origin: .zero, size: pageSize))
            drawWatermark(in: CGRect(origin: .zero, size: pageSize), context: cg)
            drawHeader(date: date, code: code, context: cg)
            drawFooter(context: cg)

            let margin: CGFloat = 22
            let contentWidth = pageSize.width - margin * 2
            var y = headerHeight + 12

            y = drawInfoRow(
                y: y,
                margin: margin,
                width: contentWidth,
                evaluated: evaluated,
                age: profile.age,
                gender: profile.gender,
                evaluator: evaluator
            )

            let tableWidth = contentWidth * 0.46
            let mapWidth = contentWidth - tableWidth - 10
            let midHeight: CGFloat = 248
            drawMeasurementsTable(
                rows: rows,
                in: CGRect(x: margin, y: y, width: tableWidth, height: midHeight)
            )
            drawBodyMap(
                rows: rows,
                gender: profile.gender,
                in: CGRect(x: margin + tableWidth + 10, y: y, width: mapWidth, height: midHeight)
            )
            y += midHeight + 8

            let chartWidth = contentWidth * 0.55
            let refWidth = contentWidth - chartWidth - 10
            let bottomHeight: CGFloat = 118
            drawBarChart(
                rows: rows,
                in: CGRect(x: margin, y: y, width: chartWidth, height: bottomHeight)
            )
            drawReferenceTable(
                gender: profile.gender,
                in: CGRect(x: margin + chartWidth + 10, y: y, width: refWidth, height: bottomHeight)
            )
            y += bottomHeight + 8

            let historyHeight: CGFloat = 110
            drawHistoryTable(
                evaluations: evaluations,
                in: CGRect(x: margin, y: y, width: contentWidth, height: historyHeight)
            )
            y += historyHeight + 8

            drawNotesAndSignatures(
                notes: notes,
                evaluator: evaluator,
                evaluated: evaluated,
                gender: profile.gender,
                in: CGRect(
                    x: margin,
                    y: y,
                    width: contentWidth,
                    height: pageSize.height - footerHeight - y - 8
                )
            )
        }
    }

    // MARK: Header / footer

    private static func drawHeader(date: Date, code: String, context: CGContext) {
        context.setFillColor(headerFill.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pageSize.width, height: headerHeight))

        let logoRect = CGRect(x: 18, y: 16, width: 36, height: 36)
        if let logo = brandLogo() {
            context.saveGState()
            UIBezierPath(roundedRect: logoRect, cornerRadius: 8).addClip()
            logo.draw(in: logoRect)
            context.restoreGState()
        }

        let brandX = logoRect.maxX + 8
        ("HealthFit" as NSString).draw(
            at: CGPoint(x: brandX, y: 16),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
        )
        ("CUIDAR DE VOCÊ É NOSSA MISSÃO" as NSString).draw(
            at: CGPoint(x: brandX, y: 36),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 7, weight: .semibold),
                .foregroundColor: brandGreen
            ]
        )

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let title = "AVALIAÇÃO FÍSICA" as NSString
        let titleSize = title.size(withAttributes: titleAttrs)
        title.draw(at: CGPoint(x: (pageSize.width - titleSize.width) / 2, y: 18), withAttributes: titleAttrs)

        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: brandGreen
        ]
        let subtitle = "Relatório de Composição Corporal" as NSString
        let subSize = subtitle.size(withAttributes: subAttrs)
        subtitle.draw(at: CGPoint(x: (pageSize.width - subSize.width) / 2, y: 40), withAttributes: subAttrs)

        let rightAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]
        let greenAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: brandGreen
        ]
        let dateLabel = "Data da Avaliação" as NSString
        let dateValue = formattedDate(date) as NSString
        let codeLabel = "Código da Avaliação" as NSString
        let codeValue = code as NSString
        let blockW = max(
            dateLabel.size(withAttributes: rightAttrs).width,
            dateValue.size(withAttributes: greenAttrs).width,
            codeLabel.size(withAttributes: rightAttrs).width,
            codeValue.size(withAttributes: greenAttrs).width
        )
        let rightX = pageSize.width - 18 - blockW
        dateLabel.draw(at: CGPoint(x: rightX, y: 12), withAttributes: rightAttrs)
        dateValue.draw(at: CGPoint(x: rightX, y: 24), withAttributes: greenAttrs)
        codeLabel.draw(at: CGPoint(x: rightX, y: 40), withAttributes: rightAttrs)
        codeValue.draw(at: CGPoint(x: rightX, y: 52), withAttributes: greenAttrs)
    }

    private static func drawFooter(context: CGContext) {
        let rect = CGRect(x: 0, y: pageSize.height - footerHeight, width: pageSize.width, height: footerHeight)
        context.setFillColor(headerFill.cgColor)
        context.fill(rect)

        let logoRect = CGRect(x: 18, y: rect.minY + 8, width: 28, height: 28)
        if let logo = brandLogo() {
            context.saveGState()
            UIBezierPath(roundedRect: logoRect, cornerRadius: 6).addClip()
            logo.draw(in: logoRect)
            context.restoreGState()
        }
        ("HealthFit" as NSString).draw(
            at: CGPoint(x: logoRect.maxX + 8, y: rect.minY + 8),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: UIColor.white
            ]
        )
        ("Transformando hábitos, transformando vidas" as NSString).draw(
            at: CGPoint(x: logoRect.maxX + 8, y: rect.minY + 24),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 7, weight: .medium),
                .foregroundColor: brandGreen
            ]
        )
        let contact = "healthfit.app  ·  contato@healthfit.app" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.8)
        ]
        let size = contact.size(withAttributes: attrs)
        contact.draw(at: CGPoint(x: pageSize.width - 18 - size.width, y: rect.midY - 5), withAttributes: attrs)
    }

    private static func drawWatermark(in page: CGRect, context: CGContext) {
        // Só texto — evita escalar PNG 1024×1024 na geração do PDF.
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: page.midX, y: page.midY)
        context.rotate(by: -.pi / 6)
        let mark = "HealthFit" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 54, weight: .heavy),
            .foregroundColor: UIColor.black.withAlphaComponent(0.045)
        ]
        let size = mark.size(withAttributes: attrs)
        mark.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
    }

    // MARK: Info

    @discardableResult
    private static func drawInfoRow(
        y: CGFloat,
        margin: CGFloat,
        width: CGFloat,
        evaluated: String,
        age: Int,
        gender: Gender,
        evaluator: String
    ) -> CGFloat {
        let height: CGFloat = 72
        let photoW: CGFloat = 72
        let gap: CGFloat = 8
        let remaining = width - photoW - gap * 2
        let cardW = remaining / 2

        let evaluatedRect = CGRect(x: margin, y: y, width: cardW, height: height)
        let evaluatorRect = CGRect(x: margin + cardW + gap, y: y, width: cardW, height: height)
        let photoRect = CGRect(x: margin + width - photoW, y: y, width: photoW, height: height)

        drawCard(evaluatedRect)
        drawCard(evaluatorRect)
        drawPortrait(gender: gender, in: photoRect)

        let caption = gender == .female ? "Dados da Avaliada" : "Dados do Avaliado"
        drawCardTitle(caption, in: evaluatedRect)
        drawKeyValue("Nome", evaluated, at: CGPoint(x: evaluatedRect.minX + 8, y: evaluatedRect.minY + 22))
        drawKeyValue("Idade", "\(age) anos", at: CGPoint(x: evaluatedRect.minX + 8, y: evaluatedRect.minY + 38))
        drawKeyValue("Sexo", gender.rawValue, at: CGPoint(x: evaluatedRect.minX + 8, y: evaluatedRect.minY + 54))

        drawCardTitle("Dados do Avaliador", in: evaluatorRect)
        drawKeyValue("Nome", evaluator, at: CGPoint(x: evaluatorRect.minX + 8, y: evaluatorRect.minY + 28))
        drawKeyValue("Função", "Personal trainer", at: CGPoint(x: evaluatorRect.minX + 8, y: evaluatorRect.minY + 46))

        return y + height + 10
    }

    private static func drawPortrait(gender: Gender, in rect: CGRect) {
        drawCard(rect)
        let inset = rect.insetBy(dx: 6, dy: 4)
        drawGenderMannequin(gender: gender, in: inset)
    }

    // MARK: Table

    private static func drawMeasurementsTable(rows: [AssessmentRow], in rect: CGRect) {
        drawCard(rect)
        drawCardTitle("Medidas Antropométricas", in: rect)

        let headerY = rect.minY + 22
        let col1 = rect.minX + 8
        let col2 = rect.minX + rect.width * 0.48
        let col3 = rect.minX + rect.width * 0.70
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7, weight: .semibold),
            .foregroundColor: inkMuted
        ]
        ("Região" as NSString).draw(at: CGPoint(x: col1, y: headerY), withAttributes: headerAttrs)
        ("Medida" as NSString).draw(at: CGPoint(x: col2, y: headerY), withAttributes: headerAttrs)
        ("Classificação" as NSString).draw(at: CGPoint(x: col3, y: headerY), withAttributes: headerAttrs)

        let rowH = (rect.maxY - headerY - 16) / CGFloat(max(rows.count, 1))
        for (index, row) in rows.enumerated() {
            let y = headerY + 12 + CGFloat(index) * rowH
            if index % 2 == 0 {
                cardFill.setFill()
                UIBezierPath(rect: CGRect(x: rect.minX + 4, y: y - 1, width: rect.width - 8, height: rowH - 1)).fill()
            }
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: ink
            ]
            (row.title as NSString).draw(at: CGPoint(x: col1, y: y), withAttributes: nameAttrs)
            (row.displayValue as NSString).draw(at: CGPoint(x: col2, y: y), withAttributes: nameAttrs)
            let classAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                .foregroundColor: row.classification.color
            ]
            (row.classification.label as NSString).draw(at: CGPoint(x: col3, y: y), withAttributes: classAttrs)
        }
    }

    // MARK: Body map

    private static func drawBodyMap(rows: [AssessmentRow], gender: Gender, in rect: CGRect) {
        drawCard(rect)
        drawCardTitle("Localização das Medidas", in: rect)

        let inner = CGRect(x: rect.minX + 6, y: rect.minY + 22, width: rect.width - 12, height: rect.height - 28)
        let figureRect = CGRect(
            x: inner.midX - inner.width * 0.18,
            y: inner.minY + 4,
            width: inner.width * 0.36,
            height: inner.height - 8
        )
        drawGenderFigure(gender: gender, in: figureRect)

        let callouts: [(String, CGFloat)] = [
            ("Pescoço", 0.10),
            ("Ombros", 0.20),
            ("Peito", 0.32),
            ("Braços", 0.40),
            ("Cintura", 0.50),
            ("Abdômen", 0.58),
            ("Quadril", 0.66),
            ("Coxas", 0.78),
            ("Panturrilhas", 0.90)
        ]

        for (index, item) in callouts.enumerated() {
            let row = rows.first { $0.mapKey == item.0 }
            let y = inner.minY + inner.height * item.1
            let leftSide = index % 2 == 0
            let boxW: CGFloat = 78
            let boxH: CGFloat = 22
            let x = leftSide ? inner.minX : inner.maxX - boxW
            let box = CGRect(x: x, y: y - boxH / 2, width: boxW, height: boxH)
            let color = row?.classification.color ?? inkMuted
            color.withAlphaComponent(0.18).setFill()
            color.setStroke()
            let path = UIBezierPath(roundedRect: box, cornerRadius: 4)
            path.lineWidth = 1.1
            path.fill()
            path.stroke()

            (item.0 as NSString).draw(
                at: CGPoint(x: box.minX + 4, y: box.minY + 1),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 6, weight: .semibold),
                    .foregroundColor: ink
                ]
            )
            ((row?.displayValue ?? "—") as NSString).draw(
                at: CGPoint(x: box.minX + 4, y: box.minY + 11),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 7, weight: .bold),
                    .foregroundColor: color
                ]
            )

            let line = UIBezierPath()
            if leftSide {
                line.move(to: CGPoint(x: box.maxX, y: box.midY))
                line.addLine(to: CGPoint(x: figureRect.minX + 6, y: y))
            } else {
                line.move(to: CGPoint(x: box.minX, y: box.midY))
                line.addLine(to: CGPoint(x: figureRect.maxX - 6, y: y))
            }
            color.withAlphaComponent(0.55).setStroke()
            line.lineWidth = 0.8
            line.stroke()
        }
    }

    private static func drawGenderFigure(gender: Gender, in rect: CGRect) {
        drawGenderMannequin(gender: gender, in: rect)
    }

    /// Manequim antropométrico (não foto) — masculino ou feminino conforme o sexo do perfil.
    private static func drawGenderMannequin(gender: Gender, in rect: CGRect) {
        let isFemale = gender == .female
        let cx = rect.midX
        let top = rect.minY + max(2, rect.height * 0.02)
        let h = rect.height - max(4, rect.height * 0.04)
        let fill = brandGreen.withAlphaComponent(0.38)
        let stroke = brandGreen.withAlphaComponent(0.72)
        fill.setFill()
        stroke.setStroke()

        // Cabeça
        let headR = h * 0.065
        let head = UIBezierPath(ovalIn: CGRect(x: cx - headR, y: top, width: headR * 2, height: headR * 2))
        head.fill()
        head.lineWidth = 0.8
        head.stroke()

        // Pescoço
        let neckW = rect.width * (isFemale ? 0.10 : 0.12)
        let neckH = h * 0.04
        let neckY = top + headR * 2 - 1
        let neck = UIBezierPath(
            roundedRect: CGRect(x: cx - neckW / 2, y: neckY, width: neckW, height: neckH),
            cornerRadius: 2
        )
        neck.fill()

        // Ombros / tronco (proporções de manequim de avaliação física)
        let shoulderY = neckY + neckH
        let waistY = top + h * (isFemale ? 0.42 : 0.40)
        let hipY = top + h * (isFemale ? 0.52 : 0.48)
        let shoulderW = rect.width * (isFemale ? 0.42 : 0.52)
        let waistW = rect.width * (isFemale ? 0.28 : 0.30)
        let hipW = rect.width * (isFemale ? 0.46 : 0.36)

        let torso = UIBezierPath()
        torso.move(to: CGPoint(x: cx - shoulderW / 2, y: shoulderY))
        torso.addLine(to: CGPoint(x: cx + shoulderW / 2, y: shoulderY))
        torso.addLine(to: CGPoint(x: cx + waistW / 2, y: waistY))
        torso.addLine(to: CGPoint(x: cx + hipW / 2, y: hipY))
        torso.addLine(to: CGPoint(x: cx - hipW / 2, y: hipY))
        torso.addLine(to: CGPoint(x: cx - waistW / 2, y: waistY))
        torso.close()
        torso.fill()
        torso.lineWidth = 0.9
        torso.stroke()

        // Braços
        let armW = max(5, rect.width * 0.07)
        let armH = h * 0.30
        let leftArm = UIBezierPath(
            roundedRect: CGRect(x: cx - shoulderW / 2 - armW - 1, y: shoulderY + 2, width: armW, height: armH),
            cornerRadius: armW / 2
        )
        let rightArm = UIBezierPath(
            roundedRect: CGRect(x: cx + shoulderW / 2 + 1, y: shoulderY + 2, width: armW, height: armH),
            cornerRadius: armW / 2
        )
        leftArm.fill(); leftArm.lineWidth = 0.7; leftArm.stroke()
        rightArm.fill(); rightArm.lineWidth = 0.7; rightArm.stroke()

        // Coxas / panturrilhas
        let thighW = max(8, rect.width * (isFemale ? 0.13 : 0.15))
        let calfW = thighW * 0.72
        let thighH = h * 0.22
        let calfH = h * 0.22
        let legGap = max(2, hipW * 0.08)
        let leftThighX = cx - legGap / 2 - thighW
        let rightThighX = cx + legGap / 2

        let leftThigh = UIBezierPath(
            roundedRect: CGRect(x: leftThighX, y: hipY - 1, width: thighW, height: thighH),
            cornerRadius: 4
        )
        let rightThigh = UIBezierPath(
            roundedRect: CGRect(x: rightThighX, y: hipY - 1, width: thighW, height: thighH),
            cornerRadius: 4
        )
        leftThigh.fill(); leftThigh.lineWidth = 0.7; leftThigh.stroke()
        rightThigh.fill(); rightThigh.lineWidth = 0.7; rightThigh.stroke()

        let calfY = hipY + thighH - 2
        let leftCalf = UIBezierPath(
            roundedRect: CGRect(
                x: leftThighX + (thighW - calfW) / 2,
                y: calfY,
                width: calfW,
                height: calfH
            ),
            cornerRadius: 3
        )
        let rightCalf = UIBezierPath(
            roundedRect: CGRect(
                x: rightThighX + (thighW - calfW) / 2,
                y: calfY,
                width: calfW,
                height: calfH
            ),
            cornerRadius: 3
        )
        leftCalf.fill(); leftCalf.lineWidth = 0.7; leftCalf.stroke()
        rightCalf.fill(); rightCalf.lineWidth = 0.7; rightCalf.stroke()
    }

    // MARK: Chart + reference

    private static func drawBarChart(rows: [AssessmentRow], in rect: CGRect) {
        drawCard(rect)
        drawCardTitle("Análise Gráfica das Medidas", in: rect)

        let cmRows = rows.filter { $0.unit == "cm" && $0.value != nil }
        let plot = CGRect(x: rect.minX + 8, y: rect.minY + 24, width: rect.width - 16, height: rect.height - 52)
        let maxValue = max(cmRows.compactMap(\.value).max() ?? 1, 1)
        let rowH = plot.height / CGFloat(max(cmRows.count, 1))

        for (index, row) in cmRows.enumerated() {
            let y = plot.minY + CGFloat(index) * rowH
            (row.title as NSString).draw(
                at: CGPoint(x: plot.minX, y: y),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 6, weight: .medium),
                    .foregroundColor: inkMuted
                ]
            )
            let barX = plot.minX + 58
            let barMaxW = plot.width - 70
            let barW = barMaxW * CGFloat((row.value ?? 0) / maxValue)
            row.classification.color.setFill()
            UIBezierPath(
                roundedRect: CGRect(x: barX, y: y + 2, width: max(barW, 2), height: 8),
                cornerRadius: 2
            ).fill()
        }

        let legendY = rect.maxY - 18
        var lx = rect.minX + 8
        for item in MeasurementClassification.allCases {
            item.color.setFill()
            UIBezierPath(ovalIn: CGRect(x: lx, y: legendY + 2, width: 6, height: 6)).fill()
            (item.label as NSString).draw(
                at: CGPoint(x: lx + 8, y: legendY),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 6, weight: .medium),
                    .foregroundColor: inkMuted
                ]
            )
            lx += 62
        }
    }

    private static func drawReferenceTable(gender: Gender, in rect: CGRect) {
        drawCard(rect)
        drawCardTitle("Tabela de Referência", in: rect)

        let bands = ReferenceBand.table(for: gender)
        let headerY = rect.minY + 22
        let cols: [CGFloat] = [0.0, 0.28, 0.50, 0.72]
        let headers = ["Região", "Abaixo", "Adequado", "Atenção"]
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6, weight: .semibold),
            .foregroundColor: inkMuted
        ]
        for (i, title) in headers.enumerated() {
            (title as NSString).draw(
                at: CGPoint(x: rect.minX + 6 + cols[i] * (rect.width - 12), y: headerY),
                withAttributes: headerAttrs
            )
        }

        let rowH = (rect.maxY - headerY - 14) / CGFloat(max(bands.count, 1))
        for (index, band) in bands.enumerated() {
            let y = headerY + 12 + CGFloat(index) * rowH
            let values = [band.region, band.below, band.adequate, band.attention]
            for (i, text) in values.enumerated() {
                (text as NSString).draw(
                    at: CGPoint(x: rect.minX + 6 + cols[i] * (rect.width - 12), y: y),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 6, weight: i == 0 ? .semibold : .regular),
                        .foregroundColor: ink
                    ]
                )
            }
        }
    }

    private static func drawNotesAndSignatures(
        notes: String,
        evaluator: String,
        evaluated: String,
        gender: Gender,
        in rect: CGRect
    ) {
        let notesW = rect.width * 0.58
        let notesRect = CGRect(x: rect.minX, y: rect.minY, width: notesW, height: rect.height)
        drawCard(notesRect)
        drawCardTitle("Observações", in: notesRect)
        (notes as NSString).draw(
            in: notesRect.insetBy(dx: 8, dy: 22),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                .foregroundColor: ink
            ]
        )

        let signRect = CGRect(
            x: rect.minX + notesW + 8,
            y: rect.minY,
            width: rect.width - notesW - 8,
            height: rect.height
        )
        drawCard(signRect)
        drawCardTitle("Assinaturas", in: signRect)
        let lineAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7, weight: .medium),
            .foregroundColor: inkMuted
        ]
        let y1 = signRect.minY + 36
        let evaluatorTitle = evaluator.isEmpty ? "Avaliador (personal trainer)" : "Avaliador — \(evaluator)"
        drawSignatureLine(at: y1, in: signRect, title: evaluatorTitle, attrs: lineAttrs)
        let evaluatedLabel = gender == .female ? "Avaliada" : "Avaliado"
        drawSignatureLine(at: y1 + 36, in: signRect, title: "\(evaluatedLabel) — \(evaluated)", attrs: lineAttrs)
    }

    private static func drawSignatureLine(
        at y: CGFloat,
        in rect: CGRect,
        title: String,
        attrs: [NSAttributedString.Key: Any]
    ) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + 10, y: y))
        path.addLine(to: CGPoint(x: rect.maxX - 10, y: y))
        inkMuted.withAlphaComponent(0.45).setStroke()
        path.lineWidth = 0.8
        path.stroke()
        (title as NSString).draw(at: CGPoint(x: rect.minX + 10, y: y + 4), withAttributes: attrs)
    }

    // MARK: History (last 3 evaluations)

    private static func drawHistoryTable(evaluations: [BodyMeasurements], in rect: CGRect) {
        drawCard(rect)
        drawCardTitle("Últimas 3 avaliações", in: rect)

        let columns = Array(evaluations.prefix(UserProfile.maxMeasurementEvaluationsInPDF))
        let headerY = rect.minY + 20
        let labels = ["Pescoço", "Ombros", "Peito", "Braços", "Cintura", "Abdômen", "Quadril", "Coxas", "Panturrilhas"]
        let colCount = max(columns.count, 1)
        let labelW = rect.width * 0.28
        let valueW = (rect.width - labelW - 16) / CGFloat(colCount)

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6.5, weight: .semibold),
            .foregroundColor: inkMuted
        ]
        ("Região" as NSString).draw(at: CGPoint(x: rect.minX + 8, y: headerY), withAttributes: headerAttrs)

        if columns.isEmpty {
            ("Ainda não há histórico — esta será a 1ª avaliação." as NSString).draw(
                at: CGPoint(x: rect.minX + 8, y: headerY + 16),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                    .foregroundColor: inkMuted
                ]
            )
            return
        }

        for (index, evaluation) in columns.enumerated() {
            let prefix = index == 0 ? "Atual" : "Av. \(index + 1)"
            let title = "\(prefix) \(shortDate(evaluation.measuredAt))"
            let x = rect.minX + labelW + CGFloat(index) * valueW
            (title as NSString).draw(at: CGPoint(x: x, y: headerY), withAttributes: headerAttrs)
        }

        let rowH = (rect.maxY - headerY - 16) / CGFloat(labels.count)
        let cellAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6, weight: .regular),
            .foregroundColor: ink
        ]
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6, weight: .medium),
            .foregroundColor: ink
        ]
        for (rowIndex, label) in labels.enumerated() {
            let y = headerY + 12 + CGFloat(rowIndex) * rowH
            (label as NSString).draw(at: CGPoint(x: rect.minX + 8, y: y), withAttributes: nameAttrs)
            for (colIndex, evaluation) in columns.enumerated() {
                let text = historyValue(label: label, in: evaluation)
                let x = rect.minX + labelW + CGFloat(colIndex) * valueW
                (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: cellAttrs)
            }
        }
    }

    private static func historyValue(label: String, in measurements: BodyMeasurements) -> String {
        let value: Double?
        switch label {
        case "Pescoço": value = measurements.neckCm
        case "Ombros": value = measurements.shouldersCm
        case "Peito": value = measurements.chestCm
        case "Braços": value = average(measurements.rightArmCm, measurements.leftArmCm)
        case "Cintura": value = measurements.waistCm
        case "Abdômen": value = measurements.abdomenCm
        case "Quadril": value = measurements.hipCm
        case "Coxas": value = average(measurements.rightThighCm, measurements.leftThighCm)
        case "Panturrilhas": value = average(measurements.rightCalfCm, measurements.leftCalfCm)
        default: value = nil
        }
        guard let value else { return "—" }
        return BodyMeasurements.formatCm(value)
    }

    private static func average(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (left?, right?): return (left + right) / 2
        case let (left?, nil): return left
        case let (nil, right?): return right
        default: return nil
        }
    }

    private static func shortDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return formattedDate(date)
    }

    // MARK: Helpers

    private static func drawCard(_ rect: CGRect) {
        cardFill.setFill()
        cardStroke.setStroke()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        path.lineWidth = 0.7
        path.fill()
        path.stroke()
    }

    private static func drawCardTitle(_ title: String, in rect: CGRect) {
        (title as NSString).draw(
            at: CGPoint(x: rect.minX + 8, y: rect.minY + 6),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: brandGreen
            ]
        )
    }

    private static func drawKeyValue(_ key: String, _ value: String, at point: CGPoint) {
        ("\(key):" as NSString).draw(
            at: point,
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 7, weight: .regular),
                .foregroundColor: inkMuted
            ]
        )
        (value as NSString).draw(
            at: CGPoint(x: point.x + 42, y: point.y - 1),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                .foregroundColor: ink
            ]
        )
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    private static func assessmentCode(date: Date, userId: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddMMyy"
        let suffix = abs(userId.hashValue) % 1000
        return String(format: "HF-%@-%03d", formatter.string(from: date), suffix)
    }

    private static func observations(rows: [AssessmentRow], gender: Gender) -> String {
        let attention = rows.filter { $0.classification == .attention || $0.classification == .above }
        var text = "Sugestão educativa do HealthFit — não substitui avaliação de educador físico, nutricionista ou médico.\n\n"
        if attention.isEmpty {
            text += "As medidas observadas estão, no geral, em faixa adequada para o perfil informado. Mantenha hábitos consistentes de treino, alimentação e sono."
        } else {
            let names = attention.map(\.title).joined(separator: ", ")
            text += "Pontos de atenção: \(names). Considere acompanhamento profissional para interpretar essas medidas no contexto do seu objetivo."
        }
        text += "\n\nReavaliação sugerida em 30 dias."
        if gender == .female {
            text += " Em fase de retenção do ciclo, evite comparar evolução só por circunferências."
        }
        return text
    }
}

private enum MeasurementClassification: CaseIterable {
    case below, adequate, attention, above

    var label: String {
        switch self {
        case .below: return "Abaixo"
        case .adequate: return "Adequado"
        case .attention: return "Atenção"
        case .above: return "Acima"
        }
    }

    var color: UIColor {
        switch self {
        case .below: return UIColor(red: 0.20, green: 0.55, blue: 0.90, alpha: 1)
        case .adequate: return UIColor(red: 0.30, green: 0.70, blue: 0.28, alpha: 1)
        case .attention: return UIColor(red: 0.95, green: 0.62, blue: 0.12, alpha: 1)
        case .above: return UIColor(red: 0.90, green: 0.28, blue: 0.24, alpha: 1)
        }
    }

    static func classify(_ value: Double, low: Double, high: Double, caution: Double) -> MeasurementClassification {
        if value < low { return .below }
        if value <= high { return .adequate }
        if value <= caution { return .attention }
        return .above
    }
}

private struct AssessmentRow {
    var title: String
    var mapKey: String
    var value: Double?
    var unit: String
    var classification: MeasurementClassification

    var displayValue: String {
        guard let value else { return "—" }
        let formatted = value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
        return "\(formatted) \(unit)"
    }

    static func make(profile: UserProfile, measurements: BodyMeasurements) -> [AssessmentRow] {
        let female = profile.gender == .female
        let arms = average(measurements.rightArmCm, measurements.leftArmCm)
        let thighs = average(measurements.rightThighCm, measurements.leftThighCm)
        let calves = average(measurements.rightCalfCm, measurements.leftCalfCm)

        func row(
            _ title: String,
            _ value: Double?,
            unit: String,
            low: Double,
            high: Double,
            caution: Double
        ) -> AssessmentRow {
            let classification: MeasurementClassification = {
                guard let value else { return .adequate }
                return .classify(value, low: low, high: high, caution: caution)
            }()
            return AssessmentRow(title: title, mapKey: title, value: value, unit: unit, classification: classification)
        }

        let weightClass: MeasurementClassification = {
            let bmi = profile.bmi
            if bmi < 18.5 { return .below }
            if bmi < 25 { return .adequate }
            if bmi < 30 { return .attention }
            return .above
        }()

        return [
            AssessmentRow(
                title: "Peso",
                mapKey: "Peso",
                value: profile.weight,
                unit: "kg",
                classification: weightClass
            ),
            row("Pescoço", measurements.neckCm, unit: "cm",
                low: female ? 30 : 35, high: female ? 36 : 42, caution: female ? 38 : 45),
            row("Ombros", measurements.shouldersCm, unit: "cm",
                low: female ? 88 : 105, high: female ? 110 : 128, caution: female ? 118 : 136),
            row("Peito", measurements.chestCm, unit: "cm",
                low: female ? 78 : 92, high: female ? 100 : 115, caution: female ? 108 : 124),
            row("Braços", arms, unit: "cm",
                low: female ? 23 : 28, high: female ? 32 : 40, caution: female ? 36 : 44),
            row("Cintura", measurements.waistCm, unit: "cm",
                low: female ? 60 : 70, high: female ? 80 : 94, caution: female ? 88 : 102),
            row("Abdômen", measurements.abdomenCm, unit: "cm",
                low: female ? 62 : 72, high: female ? 84 : 98, caution: female ? 92 : 108),
            row("Quadril", measurements.hipCm, unit: "cm",
                low: female ? 86 : 88, high: female ? 110 : 108, caution: female ? 118 : 116),
            row("Coxas", thighs, unit: "cm",
                low: female ? 48 : 50, high: female ? 62 : 66, caution: female ? 68 : 72),
            row("Panturrilhas", calves, unit: "cm",
                low: female ? 30 : 33, high: female ? 40 : 42, caution: female ? 44 : 46)
        ]
    }

    private static func average(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (left?, right?): return (left + right) / 2
        case let (left?, nil): return left
        case let (nil, right?): return right
        default: return nil
        }
    }
}

private struct ReferenceBand {
    var region: String
    var below: String
    var adequate: String
    var attention: String

    static func table(for gender: Gender) -> [ReferenceBand] {
        if gender == .female {
            return [
                .init(region: "Cintura", below: "< 60", adequate: "60–80", attention: "80–88"),
                .init(region: "Abdômen", below: "< 62", adequate: "62–84", attention: "84–92"),
                .init(region: "Quadril", below: "< 86", adequate: "86–110", attention: "110–118"),
                .init(region: "Braços", below: "< 23", adequate: "23–32", attention: "32–36"),
                .init(region: "Coxas", below: "< 48", adequate: "48–62", attention: "62–68"),
                .init(region: "IMC", below: "< 18,5", adequate: "18,5–24,9", attention: "25–29,9")
            ]
        }
        return [
            .init(region: "Cintura", below: "< 70", adequate: "70–94", attention: "94–102"),
            .init(region: "Abdômen", below: "< 72", adequate: "72–98", attention: "98–108"),
            .init(region: "Quadril", below: "< 88", adequate: "88–108", attention: "108–116"),
            .init(region: "Braços", below: "< 28", adequate: "28–40", attention: "40–44"),
            .init(region: "Coxas", below: "< 50", adequate: "50–66", attention: "66–72"),
            .init(region: "IMC", below: "< 18,5", adequate: "18,5–24,9", attention: "25–29,9")
        ]
    }
}
