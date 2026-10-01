import AVFoundation
import CoreImage
import CoreLocation
import MapKit
import SwiftUI
import UIKit

// MARK: - Metrics

struct RouteFlyoverMetrics: Equatable {
    let modalityTitle: String
    let athleteName: String
    let distanceText: String
    let durationText: String
    let secondaryLabel: String
    let secondaryValue: String
    let caption: String

    static func make(session: WorkoutSession, athleteName: String) -> RouteFlyoverMetrics {
        let km = session.displayDistanceKm
        let distanceText = km > 0 ? String(format: "%.2f km", km) : "—"
        let durationText = DurationFormatting.format(seconds: Int(session.duration))

        let secondary: (String, String)
        if session.isOutdoorCyclingSession || session.isWaterSportSession {
            let hours = max(Double(session.activeDurationSeconds), 1) / 3600.0
            let speed = km > 0 ? km / hours : 0
            secondary = ("VELOCIDADE", speed > 0 ? String(format: "%.1f km/h", speed) : "—")
        } else if let pace = session.displayPaceSecondsPerKm, pace > 0 {
            let m = pace / 60
            let s = pace % 60
            secondary = ("RITMO", String(format: "%d'%02d\"/km", m, s))
        } else {
            secondary = ("TEMPO", durationText)
        }

        let name = athleteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = name.isEmpty ? "HealthFit" : name
        let caption = """
        \(who) · \(session.completedModalityTitle) · \(durationText)\(km > 0 ? String(format: " · %.2f km", km) : "")
        Flyover · HealthFit
        #HealthFit #Flyover #Treino
        """

        return RouteFlyoverMetrics(
            modalityTitle: session.completedModalityTitle,
            athleteName: name.isEmpty ? "Atleta" : name,
            distanceText: distanceText,
            durationText: durationText,
            secondaryLabel: secondary.0,
            secondaryValue: secondary.1,
            caption: caption
        )
    }
}

// MARK: - Video exporter (MapKit snapshot + rota animada — Stories 9:16)

enum RouteFlyoverVideoExporter {
    struct Config {
        /// 720p vertical: bem mais leve na memória ao gerar/compartilhar (evita jetsam).
        var size = CGSize(width: 720, height: 1280)
        var fps: Int = 18
        var durationSeconds: Double = 8.0
        var maxRoutePoints: Int = 180
    }

    enum ExportError: LocalizedError {
        case tooFewPoints
        case writerFailed
        case encodingFailed
        case mapSnapshotFailed

        var errorDescription: String? {
            switch self {
            case .tooFewPoints:
                return "É preciso ter rota GPS (2+ pontos) para gerar o Flyover."
            case .writerFailed:
                return "Não foi possível iniciar a gravação do vídeo."
            case .encodingFailed:
                return "Falha ao gerar o vídeo do Flyover."
            case .mapSnapshotFailed:
                return "Não foi possível carregar o mapa do Flyover. Verifique a conexão e tente de novo."
            }
        }
    }

    private struct MapBackdrop {
        let image: UIImage
        let pointsInSnapshot: [CGPoint]

        var size: CGSize { image.size }
    }

    private struct CameraView {
        let scale: CGFloat
        let destCenter: CGPoint
        let sourceCenter: CGPoint
    }

    static func export(
        routePoints: [RouteCoordinate],
        performanceMetric: RoutePerformanceMetric,
        metrics: RouteFlyoverMetrics,
        config: Config = Config(),
        progress: (@MainActor (Double) -> Void)? = nil
    ) async throws -> URL {
        let points = downsample(routePoints, maxCount: config.maxRoutePoints)
        guard points.count >= 2 else { throw ExportError.tooFewPoints }

        await progress?(0.02)
        let backdrop = try await captureMapSnapshot(points: points, outputSize: config.size)
        await progress?(0.08)

        let frameCount = max(Int((config.durationSeconds * Double(config.fps)).rounded()), 60)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("healthfit-flyover-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(config.size.width),
            AVVideoHeightKey: Int(config.size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 4_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        input.transform = .identity
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(config.size.width),
                kCVPixelBufferHeightKey as String: Int(config.size.height)
            ]
        )
        guard writer.canAdd(input) else { throw ExportError.writerFailed }
        writer.add(input)
        guard writer.startWriting() else { throw ExportError.writerFailed }
        writer.startSession(atSourceTime: .zero)

        let brand = UIImage(named: "BrandHeart")
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(config.fps))

        for index in 0..<frameCount {
            let t = Double(index) / Double(max(frameCount - 1, 1))
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            let appended: Bool = try autoreleasepool {
                let image = renderFrame(
                    progress: t,
                    points: points,
                    performanceMetric: performanceMetric,
                    metrics: metrics,
                    size: config.size,
                    brand: brand,
                    backdrop: backdrop
                )
                guard let buffer = pixelBuffer(from: image, size: config.size) else {
                    throw ExportError.encodingFailed
                }
                let time = CMTimeMultiply(frameDuration, multiplier: Int32(index))
                return adaptor.append(buffer, withPresentationTime: time)
            }
            if !appended { throw ExportError.encodingFailed }
            if index % 4 == 0 {
                let mapped = 0.08 + t * 0.9
                await progress?(mapped)
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw ExportError.encodingFailed
        }
        await progress?(1)
        return outputURL
    }

    static func downsample(_ points: [RouteCoordinate], maxCount: Int) -> [RouteCoordinate] {
        guard points.count > maxCount, maxCount > 2 else { return points }
        let step = Double(points.count - 1) / Double(maxCount - 1)
        var result: [RouteCoordinate] = []
        result.reserveCapacity(maxCount)
        for i in 0..<maxCount {
            let idx = min(Int((Double(i) * step).rounded()), points.count - 1)
            result.append(points[idx])
        }
        if result.last?.id != points.last?.id {
            result[result.count - 1] = points[points.count - 1]
        }
        return result
    }

    // MARK: - Map snapshot

    private static func captureMapSnapshot(
        points: [RouteCoordinate],
        outputSize: CGSize
    ) async throws -> MapBackdrop {
        // Snapshot maior para manter nitidez ao dar zoom no percurso.
        let snapSize = CGSize(width: outputSize.width * 2, height: outputSize.height * 2)
        let options = MKMapSnapshotter.Options()
        options.size = snapSize
        options.scale = 1
        options.region = paddedRegion(for: points)
        options.mapType = .hybrid
        options.showsBuildings = true

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot: MKMapSnapshotter.Snapshot
        do {
            snapshot = try await snapshotter.start()
        } catch {
            throw ExportError.mapSnapshotFailed
        }

        let projected = points.map { snapshot.point(for: $0.coordinate) }
        return MapBackdrop(image: snapshot.image, pointsInSnapshot: projected)
    }

    private static func paddedRegion(for points: [RouteCoordinate]) -> MKCoordinateRegion {
        guard let first = points.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for p in points {
            minLat = min(minLat, p.latitude); maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude); maxLon = max(maxLon, p.longitude)
        }
        let latDelta = max((maxLat - minLat) * 1.55, 0.004)
        let lonDelta = max((maxLon - minLon) * 1.55, 0.004)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    // MARK: - Frame render

    private static func renderFrame(
        progress: Double,
        points: [RouteCoordinate],
        performanceMetric: RoutePerformanceMetric,
        metrics: RouteFlyoverMetrics,
        size: CGSize,
        brand: UIImage?,
        backdrop: MapBackdrop? = nil
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            // Preenche o frame inteiro — evita faixas azuis quando o crop do mapa não cobre a tela.
            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            let revealCount = max(2, Int(Double(points.count - 1) * progress) + 1)
            let revealed = Array(points.prefix(revealCount))
            let lookIndex = min(revealed.count - 1, max(0, revealed.count - 1))

            let projected: [CGPoint]
            if let backdrop {
                let camera = cameraView(
                    progress: progress,
                    tipInSnapshot: backdrop.pointsInSnapshot[lookIndex],
                    snapshotSize: backdrop.size,
                    outputSize: size
                )
                drawMapBackground(backdrop.image, camera: camera, in: size)
                projected = backdrop.pointsInSnapshot.map { transform($0, camera: camera) }
            } else {
                drawFallbackBackground(cg, size: size)
                let cameraCenter = points[lookIndex].coordinate
                projected = projectFlat(points, camera: cameraCenter, progress: progress, in: size)
            }

            let revealedFlat = Array(projected.prefix(revealCount))

            if projected.count >= 2 {
                strokePolyline(cg, projected, color: UIColor.white.withAlphaComponent(0.22), width: 7)
            }
            if revealedFlat.count >= 2 {
                strokePolyline(cg, revealedFlat, color: UIColor.white.withAlphaComponent(0.35), width: 14)
                let segments = RoutePerformanceColoring.segments(from: revealed, metric: performanceMetric)
                for i in 0..<(revealedFlat.count - 1) {
                    let uiColor: UIColor
                    if i < segments.count {
                        uiColor = UIColor(segments[i].color)
                    } else {
                        uiColor = UIColor(named: "AccentOrange") ?? .orange
                    }
                    cg.setStrokeColor(uiColor.withAlphaComponent(0.95).cgColor)
                    cg.setLineWidth(8)
                    cg.setLineCap(.round)
                    cg.setLineJoin(.round)
                    cg.move(to: revealedFlat[i])
                    cg.addLine(to: revealedFlat[i + 1])
                    cg.strokePath()
                }
            }

            if let tip = revealedFlat.last {
                let glow = UIColor(named: "AccentGreen") ?? .systemGreen
                cg.setFillColor(glow.withAlphaComponent(0.35).cgColor)
                cg.fillEllipse(in: CGRect(x: tip.x - 28, y: tip.y - 28, width: 56, height: 56))
                cg.setFillColor(UIColor.white.cgColor)
                cg.fillEllipse(in: CGRect(x: tip.x - 10, y: tip.y - 10, width: 20, height: 20))
                cg.setFillColor(glow.cgColor)
                cg.fillEllipse(in: CGRect(x: tip.x - 6, y: tip.y - 6, width: 12, height: 12))
            }

            drawOverlay(cg, size: size, metrics: metrics, brand: brand, progress: progress)
        }
    }

    private static func cameraView(
        progress: Double,
        tipInSnapshot: CGPoint,
        snapshotSize: CGSize,
        outputSize: CGSize
    ) -> CameraView {
        // Aspect-fill: o snapshot sempre cobre o frame (sem bordas vazias/azuis).
        let coverScale = max(
            outputSize.width / max(snapshotSize.width, 1),
            outputSize.height / max(snapshotSize.height, 1)
        )
        // Zoom suave — evita sair demais da área do mapa.
        let zoom = 1.05 + 0.22 * sin(progress * .pi)
        let scale = coverScale * zoom

        let halfW = outputSize.width / (2 * scale)
        let halfH = outputSize.height / (2 * scale)
        let clamped = CGPoint(
            x: min(max(tipInSnapshot.x, halfW), max(snapshotSize.width - halfW, halfW)),
            y: min(max(tipInSnapshot.y, halfH), max(snapshotSize.height - halfH, halfH))
        )

        return CameraView(
            scale: scale,
            destCenter: CGPoint(x: outputSize.width * 0.5, y: outputSize.height * 0.5),
            sourceCenter: clamped
        )
    }

    private static func transform(_ point: CGPoint, camera: CameraView) -> CGPoint {
        CGPoint(
            x: camera.destCenter.x + (point.x - camera.sourceCenter.x) * camera.scale,
            y: camera.destCenter.y + (point.y - camera.sourceCenter.y) * camera.scale
        )
    }

    private static func drawMapBackground(_ image: UIImage, camera: CameraView, in size: CGSize) {
        let drawRect = CGRect(
            x: camera.destCenter.x - camera.sourceCenter.x * camera.scale,
            y: camera.destCenter.y - camera.sourceCenter.y * camera.scale,
            width: image.size.width * camera.scale,
            height: image.size.height * camera.scale
        )
        image.draw(in: drawRect)

        // Vinheta leve para legibilidade da marca/métricas.
        if let dim = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor.black.withAlphaComponent(0.18).cgColor,
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.28).cgColor
            ] as CFArray,
            locations: [0, 0.45, 1]
        ), let cg = UIGraphicsGetCurrentContext() {
            cg.drawLinearGradient(
                dim,
                start: .zero,
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
    }

    private static func drawFallbackBackground(_ cg: CGContext, size: CGSize) {
        let colors = [
            UIColor(red: 0.05, green: 0.10, blue: 0.12, alpha: 1).cgColor,
            UIColor(red: 0.07, green: 0.14, blue: 0.12, alpha: 1).cgColor,
            UIColor(red: 0.04, green: 0.08, blue: 0.09, alpha: 1).cgColor
        ]
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: [0, 0.55, 1]
        ) {
            cg.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }

        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.05).cgColor)
        cg.setLineWidth(2)
        for c in 1..<7 {
            let x = size.width * CGFloat(c) / 7
            cg.move(to: CGPoint(x: x, y: 0))
            cg.addLine(to: CGPoint(x: x, y: size.height))
        }
        for r in 1..<12 {
            let y = size.height * CGFloat(r) / 12
            cg.move(to: CGPoint(x: 0, y: y))
            cg.addLine(to: CGPoint(x: size.width, y: y))
        }
        cg.strokePath()
    }

    private static func projectFlat(
        _ points: [RouteCoordinate],
        camera: CLLocationCoordinate2D,
        progress: Double,
        in size: CGSize
    ) -> [CGPoint] {
        guard let first = points.first else { return [] }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for p in points {
            minLat = min(minLat, p.latitude); maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude); maxLon = max(maxLon, p.longitude)
        }
        let padLat = max((maxLat - minLat) * 0.18, 0.0004)
        let padLon = max((maxLon - minLon) * 0.18, 0.0004)
        minLat -= padLat; maxLat += padLat
        minLon -= padLon; maxLon += padLon

        let mapRect = CGRect(
            x: size.width * 0.06,
            y: size.height * 0.22,
            width: size.width * 0.88,
            height: size.height * 0.48
        )
        let zoom = 1.0 + 0.35 * sin(progress * .pi)
        let camX = (camera.longitude - minLon) / max(maxLon - minLon, 0.0001)
        let camY = (maxLat - camera.latitude) / max(maxLat - minLat, 0.0001)

        return points.map { p in
            let nx = (p.longitude - minLon) / max(maxLon - minLon, 0.0001)
            let ny = (maxLat - p.latitude) / max(maxLat - minLat, 0.0001)
            let centeredX = 0.5 + (nx - camX) * zoom
            let centeredY = 0.5 + (ny - camY) * zoom
            let flat = CGPoint(
                x: mapRect.minX + centeredX * mapRect.width,
                y: mapRect.minY + centeredY * mapRect.height
            )
            return projectPerspective(flat, in: size)
        }
    }

    private static func projectPerspective(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let horizon = size.height * 0.18
        let ground = size.height * 0.88
        let t = max(0, min(1, (point.y - horizon) / max(ground - horizon, 1)))
        let scale = 0.55 + t * 0.85
        let centerX = size.width * 0.5
        let x = centerX + (point.x - centerX) * scale
        let y = horizon + pow(t, 1.15) * (ground - horizon)
        return CGPoint(x: x, y: y)
    }

    private static func strokePolyline(_ cg: CGContext, _ points: [CGPoint], color: UIColor, width: CGFloat) {
        guard points.count >= 2 else { return }
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(width)
        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        cg.move(to: points[0])
        for p in points.dropFirst() { cg.addLine(to: p) }
        cg.strokePath()
    }

    private static func drawOverlay( ,
        _ cg: CGContext,
        size: CGSize,
        metrics: RouteFlyoverMetrics,
        brand: UIImage?,
        progress: Double
    ) {
        if let topGrad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor.black.withAlphaComponent(0.55).cgColor,
                UIColor.clear.cgColor
            ] as CFArray,
            locations: [0, 1]
        ) {
            cg.drawLinearGradient(topGrad, start: .zero, end: CGPoint(x: 0, y: size.height * 0.28), options: [])
        }
        if let botGrad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.72).cgColor
            ] as CFArray,
            locations: [0, 1]
        ) {
            cg.drawLinearGradient(
                botGrad,
                start: CGPoint(x: 0, y: size.height * 0.62),
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }

        if let brand {
            brand.draw(in: CGRect(x: 36, y: 56, width: 48, height: 48))
        }

        let brandAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .heavy),
            .foregroundColor: UIColor.white
        ]
        ("HealthFit" as NSString).draw(at: CGPoint(x: 96, y: 58), withAttributes: brandAttrs)

        let flyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: UIColor(named: "AccentGreen") ?? .systemGreen
        ]
        ("FLYOVER" as NSString).draw(at: CGPoint(x: 96, y: 96), withAttributes: flyAttrs)

        let modalityAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        (metrics.modalityTitle as NSString).draw(
            in: CGRect(x: 36, y: size.height - 340, width: size.width - 72, height: 40),
            withAttributes: modalityAttrs
        )

        let athleteAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]
        (metrics.athleteName as NSString).draw(
            in: CGRect(x: 36, y: size.height - 298, width: size.width - 72, height: 28),
            withAttributes: athleteAttrs
        )

        let col = (size.width - 72) / 3
        drawStat(x: 36, y: size.height - 250, label: "DISTÂNCIA", value: metrics.distanceText)
        drawStat(x: 36 + col, y: size.height - 250, label: "TEMPO", value: metrics.durationText)
        drawStat(x: 36 + col * 2, y: size.height - 250, label: metrics.secondaryLabel, value: metrics.secondaryValue)

        let bar = CGRect(x: 36, y: size.height - 96, width: size.width - 72, height: 6)
        cg.setFillColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        cg.fill(bar)
        cg.setFillColor((UIColor(named: "AccentOrange") ?? .orange).cgColor)
        cg.fill(CGRect(x: bar.minX, y: bar.minY, width: bar.width * progress, height: bar.height))
    }

    private static func drawStat(x: CGFloat, y: CGFloat, label: String, value: String) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.55)
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 26, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        (label as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: labelAttrs)
        (value as NSString).draw(at: CGPoint(x: x, y: y + 20), withAttributes: valueAttrs)
    }

    /// Converte UIImage → CVPixelBuffer BGRA upright via Core Image (evita invertido no player).
    private static func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else { return nil }

        // Fundo preto (sem faixas azuis se o render falhar parcialmente).
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 0, CVPixelBufferGetDataSize(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        guard var ciImage = CIImage(image: image) else { return nil }
        let extent = ciImage.extent.integral
        if extent.width > 0, extent.height > 0,
           abs(extent.width - size.width) > 0.5 || abs(extent.height - size.height) > 0.5 {
            let scaleX = size.width / extent.width
            let scaleY = size.height / extent.height
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        }

        let ciContext = CIContext(options: [
            .workingColorSpace: NSNull(),
            .cacheIntermediates: false
        ])
        // CIImage(image:) + render preserva a orientação UIKit (marca/dados legíveis).
        ciContext.render(
            ciImage,
            to: buffer,
            bounds: CGRect(origin: .zero, size: size),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return buffer
    }
}
