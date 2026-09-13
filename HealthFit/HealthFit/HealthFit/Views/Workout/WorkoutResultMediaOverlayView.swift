import AVFoundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Stats for overlay

struct WorkoutResultMediaStat: Identifiable, Equatable {
    let id: String
    let value: String
    let label: String
}

enum WorkoutResultMediaStats {
    static func stats(for session: WorkoutSession, isCardio: Bool) -> [WorkoutResultMediaStat] {
        var result: [WorkoutResultMediaStat] = []

        result.append(WorkoutResultMediaStat(
            id: "duration",
            value: DurationFormatting.format(seconds: Int(session.duration)),
            label: "Duração"
        ))

        if session.caloriesBurned > 0 {
            result.append(WorkoutResultMediaStat(
                id: "kcal",
                value: "\(Int(session.caloriesBurned.rounded()))",
                label: "kcal"
            ))
        }

        if isCardio || session.isOutdoorGPSCardio {
            let km = session.displayDistanceKm
            if km > 0.01 {
                result.append(WorkoutResultMediaStat(
                    id: "km",
                    value: String(format: "%.2f", km),
                    label: "km"
                ))
            }
            if let pace = session.displayPaceSecondsPerKm, pace > 0,
               !session.isOutdoorCyclingSession, !session.isSwimmingSession {
                result.append(WorkoutResultMediaStat(
                    id: "pace",
                    value: PaceFormatting.format(secondsPerKm: pace).replacingOccurrences(of: " /km", with: ""),
                    label: "/km"
                ))
            }
            if session.isSwimmingSession, let swimPace = session.swimPaceSecondsPer100m, swimPace > 0 {
                result.append(WorkoutResultMediaStat(
                    id: "swimPace",
                    value: PaceFormatting.formatSwimPace(secondsPer100m: swimPace)
                        .replacingOccurrences(of: " /100m", with: ""),
                    label: "/100m"
                ))
            }
            if session.averageHeartRate > 0 {
                result.append(WorkoutResultMediaStat(
                    id: "bpm",
                    value: String(format: "%.0f", session.averageHeartRate),
                    label: "BPM"
                ))
            }
            if let steps = session.stepCount, steps > 0 {
                result.append(WorkoutResultMediaStat(
                    id: "steps",
                    value: "\(steps)",
                    label: "passos"
                ))
            }
        } else {
            result.append(WorkoutResultMediaStat(
                id: "exercises",
                value: "\(session.completedExercises)/\(max(session.totalExercises, session.completedExercises))",
                label: "Exercícios"
            ))
        }

        // Cap for clean Strava-like layout.
        return Array(result.prefix(4))
    }
}

// MARK: - Overlay layout (preview + export share the same values)

/// Posição/tamanho dos dados na foto — frações da tela para o export bater com o preview.
struct WorkoutResultMediaOverlayLayout: Equatable {
    /// Deslocamento horizontal/vertical como fração da largura/altura do canvas.
    var offsetFraction: CGSize = .zero
    /// Escala visual dos dados (treino e cardio). Menor = menos espaço na foto.
    var scale: CGFloat = 1

    static let `default` = WorkoutResultMediaOverlayLayout()
    static let minScale: CGFloat = 0.45
    static let maxScale: CGFloat = 1.45
    static let scaleStep: CGFloat = 0.1

    var canDecreaseScale: Bool {
        scale > Self.minScale + 0.001
    }

    var canIncreaseScale: Bool {
        scale < Self.maxScale - 0.001
    }

    mutating func bumpScale(_ delta: CGFloat) {
        let next = (((scale + delta) * 100).rounded()) / 100
        scale = min(Self.maxScale, max(Self.minScale, next))
    }
}

// MARK: - Overlay canvas (preview + export)

/// Photo/video frame with session data + HealthFit brand (Strava-style activity media).
struct WorkoutResultMediaOverlayView: View {
    let image: UIImage
    let session: WorkoutSession
    var isCardioSession: Bool = false
    var showVideoBadge: Bool = false
    /// Layout dos dados (mover / diminuir / aumentar).
    var layout: WorkoutResultMediaOverlayLayout = .default
    /// Quando true, permite arrastar o bloco de dados (preview interativo).
    var allowsMetricsGestures: Bool = false
    var onLayoutChange: ((WorkoutResultMediaOverlayLayout) -> Void)? = nil

    private var stats: [WorkoutResultMediaStat] {
        WorkoutResultMediaStats.stats(for: session, isCardio: isCardioSession)
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.endedAt ?? session.startedAt)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad = max(14, min(w, h) * 0.04)
            let brandSize = max(13, min(w, h) * 0.038)
            let titleSize = max(15, min(w, h) * 0.048)
            let statValueSize = max(16, min(w, h) * 0.052)
            let statLabelSize = max(10, min(w, h) * 0.028)
            let metricsOffset = CGSize(
                width: layout.offsetFraction.width * w,
                height: layout.offsetFraction.height * h
            )

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .clipped()

                LinearGradient(
                    colors: [
                        .black.opacity(0.40),
                        .clear,
                        .clear,
                        .black.opacity(0.68)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                HStack(alignment: .top, spacing: 10) {
                    brandMark(fontSize: brandSize)
                    Spacer(minLength: 8)
                    if showVideoBadge {
                        Label("Vídeo", systemImage: "video.fill")
                            .font(.system(size: brandSize * 0.75, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, pad)
                .padding(.top, pad)
                .allowsHitTesting(false)

                metricsBlock(
                    titleSize: titleSize,
                    brandSize: brandSize,
                    statValueSize: statValueSize,
                    statLabelSize: statLabelSize,
                    pad: pad
                )
                .scaleEffect(layout.scale, anchor: .bottomLeading)
                .offset(metricsOffset)
                .overlay {
                    if allowsMetricsGestures {
                        InteractiveMetricsDragOverlay(
                            canvasSize: geo.size,
                            layout: layout,
                            onLayoutChange: onLayoutChange
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.horizontal, pad)
                .padding(.bottom, pad)
            }
            .compositingGroup()
        }
    }

    private func metricsBlock(
        titleSize: CGFloat,
        brandSize: CGFloat,
        statValueSize: CGFloat,
        statLabelSize: CGFloat,
        pad: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: max(8, pad * 0.45)) {
            Text(session.completedModalityTitle)
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(dateLine)
                .font(.system(size: brandSize * 0.85, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 {
                        Rectangle()
                            .fill(.white.opacity(0.28))
                            .frame(width: 1, height: statValueSize + statLabelSize + 6)
                            .padding(.horizontal, 6)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.value)
                            .font(.system(size: statValueSize, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text(stat.label)
                            .font(.system(size: statLabelSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .compositingGroup()
        .padding(.top, 6)
        .contentShape(Rectangle())
    }

    private func brandMark(fontSize: CGFloat) -> some View {
        HStack(spacing: 7) {
            Image("BrandHeart")
                .resizable()
                .scaledToFit()
                .frame(width: fontSize * 1.15, height: fontSize * 1.15)
            Text("HealthFit")
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .tracking(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.black.opacity(0.45))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color("AccentGreen").opacity(0.9), Color("AccentOrange").opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
        .compositingGroup()
    }
}

/// Drag separado: guarda o offset no início do gesto para não acumular erro.
private struct InteractiveMetricsDragOverlay: View {
    let canvasSize: CGSize
    let layout: WorkoutResultMediaOverlayLayout
    var onLayoutChange: ((WorkoutResultMediaOverlayLayout) -> Void)?

    @State private var dragStartFraction: CGSize?

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        guard canvasSize.width > 1, canvasSize.height > 1 else { return }
                        if dragStartFraction == nil {
                            dragStartFraction = layout.offsetFraction
                        }
                        let start = dragStartFraction ?? .zero
                        var next = layout
                        next.offsetFraction = CGSize(
                            width: min(0.55, max(-0.15, start.width + value.translation.width / canvasSize.width)),
                            height: min(0.15, max(-0.75, start.height + value.translation.height / canvasSize.height))
                        )
                        onLayoutChange?(next)
                    }
                    .onEnded { _ in
                        dragStartFraction = nil
                    }
            )
    }
}

// MARK: - Renderer / share helpers

enum WorkoutResultMediaOverlayRenderer {
    /// Export size: keep aspect ratio, cap long edge for share quality.
    static func exportSize(for image: UIImage, maxLongEdge: CGFloat = 1440) -> CGSize {
        let pixelW = max(image.size.width * image.scale, 1)
        let pixelH = max(image.size.height * image.scale, 1)
        let longEdge = max(pixelW, pixelH)
        let scale = min(1, maxLongEdge / longEdge)
        return CGSize(width: (pixelW * scale).rounded(), height: (pixelH * scale).rounded())
    }

    @MainActor
    static func renderComposedImage(
        image: UIImage,
        session: WorkoutSession,
        isCardioSession: Bool,
        showVideoBadge: Bool = false,
        layout: WorkoutResultMediaOverlayLayout = .default
    ) -> UIImage? {
        let size = exportSize(for: image)
        let view = WorkoutResultMediaOverlayView(
            image: image,
            session: session,
            isCardioSession: isCardioSession,
            showVideoBadge: showVideoBadge,
            layout: layout,
            allowsMetricsGestures: false
        )
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        // 1x no frame já em pixels export — evita reescala que amolece o texto.
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// First (or near-first) frame for video poster overlays.
    static func posterFrame(fromVideoURL url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1440, height: 1440)

        let times: [CMTime] = [
            .zero,
            CMTime(seconds: 0.15, preferredTimescale: 600),
            CMTime(seconds: 1.0, preferredTimescale: 600)
        ]

        for time in times {
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }

    static func shareCaption(session: WorkoutSession, athleteName: String) -> String {
        WorkoutShareCardRenderer.shareCaption(session: session, athleteName: athleteName)
    }

    static func videoShareCaption(session: WorkoutSession, athleteName: String) -> String {
        let base = shareCaption(session: session, athleteName: athleteName)
        return base + "\n🎥 Vídeo do treino"
    }
}

// MARK: - Picked media model

enum WorkoutResultPickedMedia {
    case photo(UIImage)
    case video(url: URL, poster: UIImage)

    var previewImage: UIImage {
        switch self {
        case .photo(let image): return image
        case .video(_, let poster): return poster
        }
    }

    var isVideo: Bool {
        if case .video = self { return true }
        return false
    }
}
