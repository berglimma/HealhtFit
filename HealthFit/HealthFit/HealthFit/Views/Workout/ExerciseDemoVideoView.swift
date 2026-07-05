import AVKit
import SwiftUI

struct ExerciseDemoVideoView: View {
    let video: ExerciseDemoVideo
    var compact: Bool = false

    @EnvironmentObject private var exerciseVideoRepository: ExerciseVideoRepository
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            Label("Vídeo Demonstrativo", systemImage: "play.rectangle.fill")
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

            Text(video.title)
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            Group {
                if let player {
                    VideoPlayer(player: player)
                        .frame(height: compact ? 180 : 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if isLoading {
                    loadingView
                } else {
                    unavailableView
                }
            }

            if loadFailed {
                Text("Envie o arquivo MP4 para Firebase Storage em: \(video.storagePath)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(compact ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: video.storagePath) {
            await loadVideo()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private var loadingView: some View {
        ZStack {
            AppTheme.accent.opacity(0.12)
            ProgressView("Carregando vídeo...")
                .tint(AppTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 180 : 220)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var unavailableView: some View {
        ZStack {
            AppTheme.accent.opacity(0.12)
            VStack(spacing: 8) {
                Image(systemName: "video.slash")
                    .font(.title2)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Vídeo indisponível no Firebase")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 180 : 220)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @MainActor
    private func loadVideo() async {
        isLoading = true
        loadFailed = false
        player?.pause()
        player = nil

        guard let url = await exerciseVideoRepository.playbackURL(for: video) else {
            isLoading = false
            loadFailed = true
            return
        }

        let avPlayer = AVPlayer(url: url)
        avPlayer.actionAtItemEnd = .pause
        player = avPlayer
        isLoading = false
    }
}
