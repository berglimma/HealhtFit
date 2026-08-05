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

// MARK: - Overlay canvas (preview + export)

/// Photo/video frame with session data + HealthFit brand (Strava-style activity media).
struct WorkoutResultMediaOverlayView: View {
    let image: UIImage
    let session: WorkoutSession
    var isCardioSession: Bool = false
    var showVideoBadge: Bool = false

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

            ZStack(alignment: .bottom) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .clipped()

                // Soft vignette for readability
                LinearGradient(
                    colors: [
                        .black.opacity(0.45),
                        .clear,
                        .clear,
                        .black.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 10) {
                        brandMark(fontSize: brandSize)

                        Spacer(minLength: 8)

                        if showVideoBadge {
                            Label("Vídeo", systemImage: "video.fill")
                                .font(.system(size: brandSize * 0.75, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial.opacity(0.55))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, pad)
                    .padding(.top, pad)

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: max(8, pad * 0.45)) {
                        Text(session.workoutTitle)
                            .font(.system(size: titleSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.45), radius: 4, y: 1)

                        Text(dateLine)
                            .font(.system(size: brandSize * 0.85, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))

                        HStack(spacing: 0) {
                            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                                if index > 0 {
                                    Rectangle()
                                        .fill(.white.opacity(0.22))
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
                                        .foregroundStyle(.white.opacity(0.7))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, pad)
                    .padding(.bottom, pad)
                }
            }
        }
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
                .fill(.black.opacity(0.35))
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
        showVideoBadge: Bool = false
    ) -> UIImage? {
        let size = exportSize(for: image)
        let view = WorkoutResultMediaOverlayView(
            image: image,
            session: session,
            isCardioSession: isCardioSession,
            showVideoBadge: showVideoBadge
        )
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
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
