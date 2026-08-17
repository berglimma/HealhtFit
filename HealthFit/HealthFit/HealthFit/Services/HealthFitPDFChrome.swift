import CoreImage
import SwiftUI
import UIKit

/// Identidade visual compartilhada de todos os PDFs do HealthFit
/// (logo BrandHeart, cores do app, tipografia SF, cabeçalho / rodapé / marca d'água).
@MainActor
enum HealthFitPDFChrome {
    static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter

    static let margin: CGFloat = 44
    static let headerBand: CGFloat = 58
    static let footerBand: CGFloat = 44

    /// Cores alinhadas a `AccentGreen` / `AccentOrange` (Assets).
    static let accentGreen = UIColor(red: 0.20, green: 0.85, blue: 0.18, alpha: 1)
    static let accentOrange = UIColor(red: 1.00, green: 0.55, blue: 0.20, alpha: 1)
    static let textPrimary = UIColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1)
    static let textSecondary = UIColor(red: 0.38, green: 0.40, blue: 0.43, alpha: 1)
    static let pageFill = UIColor.white
    static let hairline = UIColor(red: 0.20, green: 0.85, blue: 0.18, alpha: 0.45)

    static var contentTop: CGFloat { margin + headerBand + 6 }
    static var contentBottomLimit: CGFloat { pageRect.height - margin - footerBand }
    static var contentLeft: CGFloat { margin }
    static var contentWidth: CGFloat { pageRect.width - margin * 2 }

    // MARK: - Tipografia (San Francisco / sistema Apple)

    static func titleFont(size: CGFloat = 20) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .bold)
    }

    static func headingFont(size: CGFloat = 14) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .semibold)
    }

    static func bodyFont(size: CGFloat = 11) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .regular)
    }

    static func metaFont(size: CGFloat = 10) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .medium)
    }

    static func captionFont(size: CGFloat = 9) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .regular)
    }

    static func brandFont(size: CGFloat = 16) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .heavy)
    }

    static func titleAttributes(size: CGFloat = 20) -> [NSAttributedString.Key: Any] {
        [.font: titleFont(size: size), .foregroundColor: textPrimary]
    }

    static func headingAttributes(size: CGFloat = 14) -> [NSAttributedString.Key: Any] {
        [.font: headingFont(size: size), .foregroundColor: textPrimary]
    }

    static func bodyAttributes(size: CGFloat = 11) -> [NSAttributedString.Key: Any] {
        [.font: bodyFont(size: size), .foregroundColor: textPrimary]
    }

    static func metaAttributes(size: CGFloat = 10) -> [NSAttributedString.Key: Any] {
        [.font: metaFont(size: size), .foregroundColor: textSecondary]
    }

    static func accentHeadingAttributes(size: CGFloat = 14) -> [NSAttributedString.Key: Any] {
        [.font: headingFont(size: size), .foregroundColor: accentGreen]
    }

    // MARK: - Decoração de página

    /// Fundo branco + marca d'água + cabeçalho + rodapé. Chamar após cada `beginPage()`.
    static func decoratePage(
        context: UIGraphicsPDFRendererContext,
        documentTitle: String,
        pageNumber: Int
    ) {
        let page = pageRect
        let cg = context.cgContext

        pageFill.setFill()
        cg.fill(page)

        drawWatermark(in: page, context: cg)
        drawHeader(documentTitle: documentTitle, in: page, context: cg)
        drawFooter(pageNumber: pageNumber, in: page, context: cg)
    }

    private static func logoImage() -> UIImage? {
        UIImage(named: "BrandHeart")
    }

    private static func drawWatermark(in page: CGRect, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        let center = CGPoint(x: page.midX, y: page.midY)
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: -CGFloat.pi / 6)

        let logoSide: CGFloat = 280
        let rect = CGRect(x: -logoSide / 2, y: -logoSide / 2 - 24, width: logoSide, height: logoSide)

        // Ícone neutro (cinza), sem verde da marca — só silhueta bem transparente.
        if let logo = watermarkSilhouetteImage() {
            logo.draw(in: rect, blendMode: .normal, alpha: 0.05)
        }

        let mark = "HealthFit" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .heavy),
            .foregroundColor: UIColor.black.withAlphaComponent(0.045)
        ]
        let size = mark.size(withAttributes: attrs)
        mark.draw(
            at: CGPoint(x: -size.width / 2, y: logoSide / 2 - 40),
            withAttributes: attrs
        )
    }

    /// Versão monocromática do BrandHeart para marca d'água (sem cor verde).
    private static func watermarkSilhouetteImage() -> UIImage? {
        guard let source = logoImage(),
              let cgImage = source.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIColorControls") else {
            return source
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(0, forKey: kCIInputSaturationKey) // remove verde / cor
        filter.setValue(0.15, forKey: kCIInputBrightnessKey)
        filter.setValue(1.05, forKey: kCIInputContrastKey)

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let output = filter.outputImage,
              let outCG = context.createCGImage(output, from: output.extent) else {
            return source
        }
        return UIImage(cgImage: outCG, scale: source.scale, orientation: source.imageOrientation)
    }

    private static func drawHeader(documentTitle: String, in page: CGRect, context: CGContext) {
        let top = margin
        let logoSide: CGFloat = 32
        let logoRect = CGRect(x: margin, y: top + 4, width: logoSide, height: logoSide)

        if let logo = logoImage() {
            context.saveGState()
            let path = UIBezierPath(roundedRect: logoRect, cornerRadius: 8)
            path.addClip()
            logo.draw(in: logoRect)
            context.restoreGState()
        }

        let brandX = logoRect.maxX + 10
        let brandAttrs: [NSAttributedString.Key: Any] = [
            .font: brandFont(size: 17),
            .foregroundColor: accentGreen,
            .kern: 0.6
        ]
        ("HealthFit" as NSString).draw(
            at: CGPoint(x: brandX, y: top + 2),
            withAttributes: brandAttrs
        )

        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: captionFont(size: 9),
            .foregroundColor: textSecondary
        ]
        let subtitle = documentTitle as NSString
        subtitle.draw(
            at: CGPoint(x: brandX, y: top + 24),
            withAttributes: subtitleAttrs
        )

        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: captionFont(size: 9),
            .foregroundColor: textSecondary
        ]
        let dateText = Self.formattedNow() as NSString
        let dateSize = dateText.size(withAttributes: dateAttrs)
        dateText.draw(
            at: CGPoint(x: page.width - margin - dateSize.width, y: top + 10),
            withAttributes: dateAttrs
        )

        let ruleY = margin + headerBand - 6
        drawAccentRule(from: CGPoint(x: margin, y: ruleY), to: CGPoint(x: page.width - margin, y: ruleY), context: context)
    }

    private static func drawFooter(pageNumber: Int, in page: CGRect, context: CGContext) {
        let ruleY = page.height - margin - footerBand + 8
        drawAccentRule(
            from: CGPoint(x: margin, y: ruleY),
            to: CGPoint(x: page.width - margin, y: ruleY),
            context: context
        )

        let leftAttrs: [NSAttributedString.Key: Any] = [
            .font: captionFont(size: 8),
            .foregroundColor: textSecondary
        ]
        ("HealthFit · Relatório confidencial do atleta" as NSString).draw(
            at: CGPoint(x: margin, y: ruleY + 12),
            withAttributes: leftAttrs
        )

        let pageText = "Página \(pageNumber)" as NSString
        let pageAttrs: [NSAttributedString.Key: Any] = [
            .font: captionFont(size: 8),
            .foregroundColor: accentOrange
        ]
        let pageSize = pageText.size(withAttributes: pageAttrs)
        pageText.draw(
            at: CGPoint(x: page.width - margin - pageSize.width, y: ruleY + 12),
            withAttributes: pageAttrs
        )
    }

    private static func drawAccentRule(from: CGPoint, to: CGPoint, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        // Verde → laranja (cores do app), em duas metades.
        let mid = CGPoint(x: from.x + (to.x - from.x) * 0.62, y: from.y)
        context.setLineWidth(1.25)
        context.setLineCap(.round)

        context.setStrokeColor(accentGreen.cgColor)
        context.move(to: from)
        context.addLine(to: mid)
        context.strokePath()

        context.setStrokeColor(accentOrange.cgColor)
        context.move(to: mid)
        context.addLine(to: to)
        context.strokePath()
    }

    private static func formattedNow() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

/// Layout paginado com chrome HealthFit em cada página.
@MainActor
final class HealthFitPDFPageLayout {
    let context: UIGraphicsPDFRendererContext
    let documentTitle: String
    private(set) var pageNumber = 0
    var y: CGFloat = 0

    var left: CGFloat { HealthFitPDFChrome.contentLeft }
    var width: CGFloat { HealthFitPDFChrome.contentWidth }
    var bottomLimit: CGFloat { HealthFitPDFChrome.contentBottomLimit }

    init(context: UIGraphicsPDFRendererContext, documentTitle: String) {
        self.context = context
        self.documentTitle = documentTitle
    }

    func beginPage() {
        context.beginPage()
        pageNumber += 1
        HealthFitPDFChrome.decoratePage(
            context: context,
            documentTitle: documentTitle,
            pageNumber: pageNumber
        )
        y = HealthFitPDFChrome.contentTop
    }

    func ensureSpace(_ needed: CGFloat) {
        if y + needed > bottomLimit {
            beginPage()
        }
    }

    @discardableResult
    func draw(
        _ text: String,
        attrs: [NSAttributedString.Key: Any],
        spacingAfter: CGFloat = 6
    ) -> CGFloat {
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: width, height: 4_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        let height = ceil(bounding.height) + 2
        ensureSpace(height + spacingAfter)
        (text as NSString).draw(
            in: CGRect(x: left, y: y, width: width, height: height),
            withAttributes: attrs
        )
        y += height + spacingAfter
        return height
    }

    func addVerticalSpace(_ amount: CGFloat) {
        ensureSpace(amount)
        y += amount
    }

    func drawImage(_ image: UIImage, height: CGFloat, caption: String? = nil) {
        let needed = height + (caption == nil ? 0 : 28) + 12
        ensureSpace(needed)
        if let caption {
            draw(caption, attrs: HealthFitPDFChrome.accentHeadingAttributes(), spacingAfter: 8)
        }
        let rect = CGRect(x: left, y: y, width: width, height: height)
        image.draw(in: rect)
        y += height + 12
    }
}

// MARK: - Snapshot SwiftUI → PDF multipágina

@MainActor
enum HealthFitPDFSnapshot {
    /// Constante não isolada: valores padrão de parâmetro exigem contexto `nonisolated` (Swift 6).
    nonisolated static let renderWidth: CGFloat = 520

    /// Renderiza o layout SwiftUI (gráficos Charts inclusos) em imagem de alta resolução.
    static func render<V: View>(_ view: V, width: CGFloat = renderWidth, scale: CGFloat = 2) -> UIImage? {
        let content = view
            .frame(width: width)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return renderer.uiImage
    }

    /// Gera PDF com chrome HealthFit, fatiando a imagem alta em várias páginas.
    static func writePaginatedPDF(
        image: UIImage,
        documentTitle: String,
        fileNamePrefix: String
    ) -> URL? {
        let page = HealthFitPDFChrome.pageRect
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileNamePrefix)-\(UUID().uuidString.prefix(8)).pdf")

        let contentWidth = HealthFitPDFChrome.contentWidth
        let contentTop = HealthFitPDFChrome.contentTop
        let contentBottom = HealthFitPDFChrome.contentBottomLimit
        let maxSliceHeight = contentBottom - contentTop
        guard maxSliceHeight > 40, image.size.width > 0 else { return nil }

        let drawWidth = contentWidth
        let drawHeight = image.size.height * (drawWidth / image.size.width)
        guard drawHeight > 0 else { return nil }

        let renderer = UIGraphicsPDFRenderer(bounds: page)
        do {
            try renderer.writePDF(to: url) { context in
                var offset: CGFloat = 0
                var pageNumber = 0

                while offset < drawHeight - 0.5 {
                    context.beginPage()
                    pageNumber += 1
                    HealthFitPDFChrome.decoratePage(
                        context: context,
                        documentTitle: documentTitle,
                        pageNumber: pageNumber
                    )

                    let sliceHeight = min(maxSliceHeight, drawHeight - offset)
                    let cg = context.cgContext
                    cg.saveGState()
                    let clip = CGRect(
                        x: HealthFitPDFChrome.contentLeft,
                        y: contentTop,
                        width: drawWidth,
                        height: sliceHeight
                    )
                    cg.clip(to: clip)
                    image.draw(
                        in: CGRect(
                            x: HealthFitPDFChrome.contentLeft,
                            y: contentTop - offset,
                            width: drawWidth,
                            height: drawHeight
                        )
                    )
                    cg.restoreGState()

                    offset += sliceHeight
                }
            }
            return url
        } catch {
            return nil
        }
    }
}

/// Paleta clara para impressão / PDF (mantém verdes e laranjas do app).
enum ReportPDFPrintTheme {
    static let background = Color.white
    static let card = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let textPrimary = Color(red: 0.10, green: 0.11, blue: 0.12)
    static let textSecondary = Color(red: 0.40, green: 0.42, blue: 0.45)
    static let accent = Color(red: 0.20, green: 0.85, blue: 0.18)
    static let accentSecondary = Color(red: 1.00, green: 0.55, blue: 0.20)
    static let purple = Color(red: 0.56, green: 0.27, blue: 0.85)
    static let indigo = Color(red: 0.35, green: 0.34, blue: 0.84)
    static let teal = Color(red: 0.20, green: 0.66, blue: 0.66)
    static let orange = Color(red: 1.00, green: 0.58, blue: 0.00)
    static let blue = Color(red: 0.25, green: 0.47, blue: 0.95)
    static let corner: CGFloat = 14
}
