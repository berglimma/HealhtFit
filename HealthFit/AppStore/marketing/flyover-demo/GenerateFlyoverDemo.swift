#!/usr/bin/env swift
/**
 HealthFit Flyover demo (15s) — Stories 9:16 para divulgação.
 Rota sintética: volta na Lagoa Rodrigo de Freitas (Rio de Janeiro).
 Compilar/rodar:
   cd HealthFit/AppStore/marketing/flyover-demo
   swift GenerateFlyoverDemo.swift
 */
import AppKit
import AVFoundation
import CoreImage
import CoreLocation
import Foundation
import MapKit

// MARK: - Config

struct DemoConfig {
    var size = CGSize(width: 720, height: 1280)
    var fps = 24
    var durationSeconds = 15.0
    var brandPath: String
    var outputPath: String
}

struct DemoMetrics {
    let modality = "Caminhada"
    let athlete = "HealthFit"
    let distance = "5.20 km"
    let duration = "42:18"
    let secondaryLabel = "RITMO"
    let secondaryValue = "8'07\"/km"
}

// MARK: - Demo route (contorno fiel OSM da Lagoa Rodrigo de Freitas)

func lagoaRoute() -> [CLLocationCoordinate2D] {
    let candidates = [
        FileManager.default.currentDirectoryPath + "/lagoa_contour.json",
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("lagoa_contour.json").path
    ]
    let path = candidates.first { FileManager.default.fileExists(atPath: $0) }
    guard let path,
          let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let coords = json["coordinates"] as? [[String: Any]] else {
        fputs("Aviso: lagoa_contour.json não encontrado — usando fallback.\n", stderr)
        return lagoaRouteFallback()
    }

    var points: [CLLocationCoordinate2D] = []
    points.reserveCapacity(coords.count)
    for c in coords {
        guard let lat = c["lat"] as? Double, let lon = c["lon"] as? Double else { continue }
        points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }
    guard points.count >= 2 else { return lagoaRouteFallback() }
    print("→ Contorno OSM: \(points.count) pontos (\(path))")
    return points
}

/// Fallback mínimo se o JSON não estiver ao lado do script.
func lagoaRouteFallback() -> [CLLocationCoordinate2D] {
    [
        .init(latitude: -22.9662, longitude: -43.2102),
        .init(latitude: -22.9688, longitude: -43.2027),
        .init(latitude: -22.9752, longitude: -43.2035),
        .init(latitude: -22.9779, longitude: -43.2110),
        .init(latitude: -22.9755, longitude: -43.2185),
        .init(latitude: -22.9705, longitude: -43.2197),
        .init(latitude: -22.9662, longitude: -43.2102)
    ]
}

func paceColor(fraction: Double) -> NSColor {
    // Verde → amarelo → laranja/vermelho (ritmo)
    if fraction < 0.45 {
        return NSColor(calibratedRed: 0.20, green: 0.85, blue: 0.45, alpha: 1)
    } else if fraction < 0.75 {
        return NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.20, alpha: 1)
    } else {
        return NSColor(calibratedRed: 0.98, green: 0.35, blue: 0.20, alpha: 1)
    }
}

// MARK: - Map snapshot

func captureSnapshot(
    coords: [CLLocationCoordinate2D],
    outputSize: CGSize
) async throws -> (NSImage, [CGPoint]) {
    var minLat = coords[0].latitude, maxLat = coords[0].latitude
    var minLon = coords[0].longitude, maxLon = coords[0].longitude
    for c in coords {
        minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
        minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
    }
    let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        ),
        span: MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.45, 0.012),
            longitudeDelta: max((maxLon - minLon) * 1.45, 0.014)
        )
    )

    let snapSize = CGSize(width: outputSize.width * 2, height: outputSize.height * 2)
    let options = MKMapSnapshotter.Options()
    options.size = snapSize
    options.region = region
    options.mapType = .hybrid
    options.showsBuildings = true

    let snapshot = try await MKMapSnapshotter(options: options).start()
    // MKMapSnapshotter usa origem top-left; AppKit desenha com origem embaixo.
    let h = snapshot.image.size.height
    let points = coords.map { c -> CGPoint in
        let p = snapshot.point(for: c)
        return CGPoint(x: p.x, y: h - p.y)
    }
    return (snapshot.image, points)
}

// MARK: - Camera / draw

struct Cam {
    let scale: CGFloat
    let destCenter: CGPoint
    let sourceCenter: CGPoint
}

func camera(progress: Double, tip: CGPoint, snapSize: CGSize, out: CGSize) -> Cam {
    let cover = max(out.width / max(snapSize.width, 1), out.height / max(snapSize.height, 1))
    let zoom = 1.08 + 0.28 * sin(progress * .pi)
    let scale = cover * zoom
    let halfW = out.width / (2 * scale)
    let halfH = out.height / (2 * scale)
    let clamped = CGPoint(
        x: min(max(tip.x, halfW), max(snapSize.width - halfW, halfW)),
        y: min(max(tip.y, halfH), max(snapSize.height - halfH, halfH))
    )
    return Cam(
        scale: scale,
        destCenter: CGPoint(x: out.width * 0.5, y: out.height * 0.5),
        sourceCenter: clamped
    )
}

func xform(_ p: CGPoint, _ c: Cam) -> CGPoint {
    CGPoint(
        x: c.destCenter.x + (p.x - c.sourceCenter.x) * c.scale,
        y: c.destCenter.y + (p.y - c.sourceCenter.y) * c.scale
    )
}

func renderFrame(
    progress: Double,
    mapImage: NSImage,
    snapPoints: [CGPoint],
    size: CGSize,
    brand: NSImage?,
    metrics: DemoMetrics
) -> NSImage {
    let revealCount = max(2, Int(Double(snapPoints.count - 1) * progress) + 1)
    let lookIndex = min(revealCount - 1, snapPoints.count - 1)
    let cam = camera(
        progress: progress,
        tip: snapPoints[lookIndex],
        snapSize: mapImage.size,
        out: size
    )
    let projected = snapPoints.map { xform($0, cam) }
    let revealed = Array(projected.prefix(revealCount))

    let image = NSImage(size: size)
    image.lockFocus()
    defer { image.unlockFocus() }

    NSColor.black.setFill()
    NSRect(origin: .zero, size: size).fill()

    let drawRect = CGRect(
        x: cam.destCenter.x - cam.sourceCenter.x * cam.scale,
        y: cam.destCenter.y - cam.sourceCenter.y * cam.scale,
        width: mapImage.size.width * cam.scale,
        height: mapImage.size.height * cam.scale
    )
    mapImage.draw(
        in: drawRect,
        from: .zero,
        operation: .copy,
        fraction: 1
    )

    func stroke(_ pts: [CGPoint], color: NSColor, width: CGFloat) {
        guard pts.count >= 2 else { return }
        let path = NSBezierPath()
        path.move(to: pts[0])
        for p in pts.dropFirst() { path.line(to: p) }
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        color.setStroke()
        path.stroke()
    }

    stroke(projected, color: NSColor.white.withAlphaComponent(0.22), width: 7)
    stroke(revealed, color: NSColor.white.withAlphaComponent(0.35), width: 14)

    if revealed.count >= 2 {
        for i in 0..<(revealed.count - 1) {
            let frac = Double(i) / Double(max(revealed.count - 2, 1))
            let path = NSBezierPath()
            path.move(to: revealed[i])
            path.line(to: revealed[i + 1])
            path.lineWidth = 8
            path.lineCapStyle = .round
            paceColor(fraction: frac).setStroke()
            path.stroke()
        }
    }

    if let tip = revealed.last {
        let glow = NSColor(calibratedRed: 0.20, green: 0.85, blue: 0.45, alpha: 1)
        glow.withAlphaComponent(0.35).setFill()
        NSBezierPath(ovalIn: NSRect(x: tip.x - 28, y: tip.y - 28, width: 56, height: 56)).fill()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: tip.x - 10, y: tip.y - 10, width: 20, height: 20)).fill()
        glow.setFill()
        NSBezierPath(ovalIn: NSRect(x: tip.x - 6, y: tip.y - 6, width: 12, height: 12)).fill()
    }

    // Overlay — AppKit origem embaixo; espaçamento claro entre marca e FLYOVER.
    func uy(_ yFromTop: CGFloat) -> CGFloat { size.height - yFromTop }

    if let brand {
        brand.draw(
            in: NSRect(x: 36, y: uy(52 + 44), width: 44, height: 44),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
    }

    let brandAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 30, weight: .heavy),
        .foregroundColor: NSColor.white
    ]
    // Baseline ~86pt do topo — linha da marca.
    ("HealthFit" as NSString).draw(at: NSPoint(x: 92, y: uy(86)), withAttributes: brandAttrs)

    let flyAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.20, green: 0.85, blue: 0.45, alpha: 1)
    ]
    // Baseline ~118pt do topo — bem abaixo de “HealthFit” (sem sobreposição).
    ("FLYOVER" as NSString).draw(at: NSPoint(x: 92, y: uy(118)), withAttributes: flyAttrs)

    let modalityAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 28, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    (metrics.modality as NSString).draw(
        in: NSRect(x: 36, y: uy(size.height - 340 + 40), width: size.width - 72, height: 40),
        withAttributes: modalityAttrs
    )

    let athleteAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.85)
    ]
    (metrics.athlete as NSString).draw(
        in: NSRect(x: 36, y: uy(size.height - 298 + 28), width: size.width - 72, height: 28),
        withAttributes: athleteAttrs
    )

    func drawStat(x: CGFloat, yFromTop: CGFloat, label: String, value: String) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.55)
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 26, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        (label as NSString).draw(at: NSPoint(x: x, y: uy(yFromTop + 14)), withAttributes: labelAttrs)
        (value as NSString).draw(at: NSPoint(x: x, y: uy(yFromTop + 20 + 28)), withAttributes: valueAttrs)
    }

    let col = (size.width - 72) / 3
    let statsY = size.height - 250
    drawStat(x: 36, yFromTop: statsY, label: "DISTÂNCIA", value: metrics.distance)
    drawStat(x: 36 + col, yFromTop: statsY, label: "TEMPO", value: metrics.duration)
    drawStat(x: 36 + col * 2, yFromTop: statsY, label: metrics.secondaryLabel, value: metrics.secondaryValue)

    let barY = uy(96 + 6)
    let bar = NSRect(x: 36, y: barY, width: size.width - 72, height: 6)
    NSColor.white.withAlphaComponent(0.2).setFill()
    bar.fill()
    NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.15, alpha: 1).setFill()
    NSRect(x: bar.minX, y: bar.minY, width: bar.width * progress, height: bar.height).fill()

    return image
}

// MARK: - Pixel buffer / encode

func pixelBuffer(from image: NSImage, size: CGSize) -> CVPixelBuffer? {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let cgImage = rep.cgImage else { return nil }

    var buffer: CVPixelBuffer?
    let attrs: [CFString: Any] = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
    ]
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        Int(size.width),
        Int(size.height),
        kCVPixelFormatType_32BGRA,
        attrs as CFDictionary,
        &buffer
    )
    guard status == kCVReturnSuccess, let buffer else { return nil }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    guard let ctx = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo
    ) else { return nil }

    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fill(CGRect(origin: .zero, size: size))
    // NSBitmapImageRep já vem top→bottom; NÃO espelhar Y (senão marca/métricas ficam invertidas).
    ctx.interpolationQuality = .high
    ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))
    return buffer
}

func exportVideo(config: DemoConfig) async throws {
    print("→ Capturando mapa híbrido (Lagoa Rodrigo de Freitas)…")
    let coords = lagoaRoute()
    let (mapImage, snapPoints) = try await captureSnapshot(coords: coords, outputSize: config.size)
    print("→ Mapa OK (\(Int(mapImage.size.width))×\(Int(mapImage.size.height)))")

    let brand = NSImage(contentsOfFile: config.brandPath)
    let metrics = DemoMetrics()
    let frameCount = Int((config.durationSeconds * Double(config.fps)).rounded())
    let outputURL = URL(fileURLWithPath: config.outputPath)
    try? FileManager.default.removeItem(at: outputURL)

    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: Int(config.size.width),
        AVVideoHeightKey: Int(config.size.height),
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 5_500_000,
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
    guard writer.canAdd(input) else { throw NSError(domain: "FlyoverDemo", code: 1) }
    writer.add(input)
    guard writer.startWriting() else { throw writer.error ?? NSError(domain: "FlyoverDemo", code: 2) }
    writer.startSession(atSourceTime: .zero)

    let frameDuration = CMTime(value: 1, timescale: CMTimeScale(config.fps))
    print("→ Renderizando \(frameCount) frames (\(config.durationSeconds)s @ \(config.fps)fps)…")

    for index in 0..<frameCount {
        let t = Double(index) / Double(max(frameCount - 1, 1))
        while !input.isReadyForMoreMediaData {
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        let ok: Bool = try autoreleasepool {
            let frame = renderFrame(
                progress: t,
                mapImage: mapImage,
                snapPoints: snapPoints,
                size: config.size,
                brand: brand,
                metrics: metrics
            )
            guard let buffer = pixelBuffer(from: frame, size: config.size) else {
                throw NSError(domain: "FlyoverDemo", code: 3)
            }
            let time = CMTimeMultiply(frameDuration, multiplier: Int32(index))
            return adaptor.append(buffer, withPresentationTime: time)
        }
        if !ok { throw NSError(domain: "FlyoverDemo", code: 4) }
        if index % 24 == 0 {
            print(String(format: "   %3.0f%%", t * 100))
        }
    }

    input.markAsFinished()
    await writer.finishWriting()
    guard writer.status == .completed else {
        throw writer.error ?? NSError(domain: "FlyoverDemo", code: 5)
    }
    print("✅ Vídeo salvo em:\n   \(outputURL.path)")
}

// MARK: - Main

let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let scriptDir: URL = {
    // Quando rodado via `swift file.swift`, cwd costuma ser a pasta do script se você cd nela.
    here
}()

let brandCandidates = [
    scriptDir
        .appendingPathComponent("../../../../HealthFit/HealthFit/Assets.xcassets/BrandHeart.imageset/BrandHeart.png").path,
    scriptDir
        .appendingPathComponent("../../../HealthFit/HealthFit/Assets.xcassets/BrandHeart.imageset/BrandHeart.png").path,
    "/Users/lindenbergbrito/Documents/HealhtFit/HealthFit/HealthFit/HealthFit/Assets.xcassets/BrandHeart.imageset/BrandHeart.png"
]

let brandPath = brandCandidates.first { FileManager.default.fileExists(atPath: $0) } ?? brandCandidates.last!
let outputPath = scriptDir.appendingPathComponent("healthfit-flyover-demo-15s.mp4").path

let config = DemoConfig(brandPath: brandPath, outputPath: outputPath)

var runError: Error?
var finished = false

Task { @MainActor in
    do {
        try await exportVideo(config: config)
    } catch {
        runError = error
        fputs("Erro: \(error.localizedDescription)\n", stderr)
    }
    finished = true
    CFRunLoopStop(CFRunLoopGetMain())
}

// MapKit precisa do RunLoop principal — semáforo no main deadlockaria o snapshot.
while !finished {
    RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
}
if runError != nil { exit(1) }
