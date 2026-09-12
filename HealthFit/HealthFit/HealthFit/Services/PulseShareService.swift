import SwiftUI
import UIKit

/// Monta mídia + legenda para compartilhar fora do Pulse (Instagram / WhatsApp / etc.).
/// Instagram Feed/Stories não aceitam música nativa nem legenda programática de forma
/// confiável — gravamos a música no card (sticker) e na legenda / pasteboard.
enum PulseShareService {
    struct Package {
        var items: [Any]
        var caption: String
        var previewImage: UIImage?
    }

    static func caption(for post: PulsePost) -> String {
        var lines: [String] = []
        let text = post.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { lines.append(text) }
        if let meta = post.workoutMeta {
            var bits: [String] = []
            if let modality = meta.modality, !modality.isEmpty { bits.append(modality) }
            if let duration = meta.durationSeconds, duration > 0 {
                let minutes = max(1, duration / 60)
                bits.append("\(minutes) min")
            }
            if let intensity = meta.intensity { bits.append("intensidade \(intensity)/10") }
            if let duo = meta.duoTeamName, !duo.isEmpty { bits.append(duo) }
            if !bits.isEmpty { lines.append(bits.joined(separator: " · ")) }
        }
        if let music = post.music {
            lines.append("♪ \(music.title) — \(music.artistName)")
            lines.append("\(music.providerLabel) · \(music.clipRangeLabel)")
            if let link = music.externalURL, !link.isEmpty {
                lines.append(link)
            }
        }
        lines.append("#HealthFitPulse · \(post.community.title)")
        lines.append(PulseExperimental.tagline)
        return lines.joined(separator: "\n")
    }

    /// Pacote pronto para `ActivityShareSheet` (imagem composta + legenda + música no card).
    @MainActor
    static func makeSharePackage(image: UIImage?, post: PulsePost) async -> Package {
        let caption = caption(for: post)
        UIPasteboard.general.string = caption

        let artwork = await loadArtwork(from: post.music?.artworkURL)
        if let image, let card = renderShareCard(
            image: image,
            post: post,
            caption: caption,
            musicArtwork: artwork
        ) {
            return Package(items: [card, caption], caption: caption, previewImage: card)
        }
        if let image {
            return Package(items: [image, caption], caption: caption, previewImage: image)
        }
        return Package(items: [caption], caption: caption, previewImage: nil)
    }

    @MainActor
    static func makeSharePackage(videoURL: URL, post: PulsePost) async -> Package {
        let caption = caption(for: post)
        UIPasteboard.general.string = caption
        // Vídeo: legenda + link da música (Instagram não embute áudio externo no share sheet).
        return Package(items: [videoURL, caption], caption: caption, previewImage: nil)
    }

    /// Card vertical estilo Stories com foto + sticker de música + legenda.
    static func renderShareCard(
        image: UIImage,
        post: PulsePost,
        caption: String,
        musicArtwork: UIImage? = nil
    ) -> UIImage? {
        let width: CGFloat = 1080
        let height: CGFloat = 1920
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor.black.setFill()
            cg.fill(CGRect(x: 0, y: 0, width: width, height: height))

            let hasMusic = post.music != nil
            let mediaHeight = height * (hasMusic ? 0.54 : 0.62)
            let mediaRect = CGRect(x: 0, y: 0, width: width, height: mediaHeight)
            image.draw(in: aspectFillRect(for: image.size, in: mediaRect))

            let colors = [
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.85).cgColor,
                UIColor.black.cgColor,
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 0.45, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: height * 0.40),
                    end: CGPoint(x: 0, y: height),
                    options: []
                )
            }

            let accent = UIColor(red: 0.35, green: 0.85, blue: 0.55, alpha: 1)
            let textColor = UIColor.white
            let muted = UIColor.white.withAlphaComponent(0.78)
            var y = mediaHeight + 28
            let inset: CGFloat = 56
            let maxTextWidth = width - inset * 2

            drawText(
                "HealthFit Pulse",
                font: .systemFont(ofSize: 28, weight: .bold),
                color: accent,
                in: CGRect(x: inset, y: y, width: maxTextWidth, height: 36)
            )
            y += 42

            drawText(
                post.community.title.uppercased(),
                font: .systemFont(ofSize: 22, weight: .semibold),
                color: muted,
                in: CGRect(x: inset, y: y, width: maxTextWidth, height: 30)
            )
            y += 36

            if let music = post.music {
                y = drawMusicSticker(
                    music: music,
                    artwork: musicArtwork,
                    accent: accent,
                    atY: y,
                    inset: inset,
                    width: width,
                    in: cg
                ) + 28
            }

            let bodyCaption = captionWithoutMusicLines(caption)
            let captionHeight = max(80, height - y - 80)
            drawText(
                bodyCaption,
                font: .systemFont(ofSize: 34, weight: .semibold),
                color: textColor,
                in: CGRect(x: inset, y: y, width: maxTextWidth, height: captionHeight),
                lineBreakMode: .byWordWrapping
            )
        }
    }

    /// Remove linhas de música da legenda do card (já estão no sticker).
    private static func captionWithoutMusicLines(_ caption: String) -> String {
        caption
            .components(separatedBy: "\n")
            .filter { line in
                let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.hasPrefix("♪") { return false }
                if t.lowercased().hasPrefix("http") { return false }
                if t.contains(" · ") && (t.contains("0:") || t.contains("Deezer") || t.contains("Spotify")) {
                    return false
                }
                return true
            }
            .joined(separator: "\n")
    }

    @discardableResult
    private static func drawMusicSticker(
        music: PulseMusicAttachment,
        artwork: UIImage?,
        accent: UIColor,
        atY y: CGFloat,
        inset: CGFloat,
        width: CGFloat,
        in cg: CGContext
    ) -> CGFloat {
        let stickerHeight: CGFloat = 148
        let stickerRect = CGRect(
            x: inset,
            y: y,
            width: width - inset * 2,
            height: stickerHeight
        )
        let path = UIBezierPath(roundedRect: stickerRect, cornerRadius: 28)
        accent.withAlphaComponent(0.22).setFill()
        path.fill()
        accent.withAlphaComponent(0.55).setStroke()
        path.lineWidth = 3
        path.stroke()

        let artSize: CGFloat = 108
        let artRect = CGRect(
            x: stickerRect.minX + 20,
            y: stickerRect.midY - artSize / 2,
            width: artSize,
            height: artSize
        )
        let artPath = UIBezierPath(roundedRect: artRect, cornerRadius: 18)
        cg.saveGState()
        artPath.addClip()
        if let artwork {
            artwork.draw(in: aspectFillRect(for: artwork.size, in: artRect))
        } else {
            UIColor.white.withAlphaComponent(0.12).setFill()
            cg.fill(artRect)
            drawText(
                "♪",
                font: .systemFont(ofSize: 44, weight: .bold),
                color: .white,
                in: artRect.insetBy(dx: 28, dy: 28)
            )
        }
        cg.restoreGState()

        let textX = artRect.maxX + 24
        let textW = stickerRect.maxX - textX - 24
        drawText(
            music.title,
            font: .systemFont(ofSize: 32, weight: .bold),
            color: .white,
            in: CGRect(x: textX, y: stickerRect.minY + 28, width: textW, height: 40)
        )
        drawText(
            music.artistName,
            font: .systemFont(ofSize: 26, weight: .semibold),
            color: UIColor.white.withAlphaComponent(0.85),
            in: CGRect(x: textX, y: stickerRect.minY + 70, width: textW, height: 32)
        )
        drawText(
            "\(music.providerLabel) · \(music.clipRangeLabel)",
            font: .systemFont(ofSize: 22, weight: .semibold),
            color: accent,
            in: CGRect(x: textX, y: stickerRect.minY + 104, width: textW, height: 28)
        )

        return stickerRect.maxY
    }

    private static func loadArtwork(from urlString: String?) async -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private static func aspectFillRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(
            x: bounds.midX - w / 2,
            y: bounds.midY - h / 2,
            width: w,
            height: h
        )
    }

    private static func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        in rect: CGRect,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = lineBreakMode
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
    }
}
