import SwiftUI
import AVFoundation
import Combine

struct PulseMusicPickerView: View {
    @Binding var selectedTrack: PulseMusicAttachment?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var searchService = PulseMusicSearchService.shared

    @State private var provider: PulseMusicProvider = .deezer
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if PulseMusicProvider.selectableCases.count > 1 {
                    Picker("Serviço", selection: $provider) {
                        ForEach(PulseMusicProvider.selectableCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .onChange(of: provider) { _, _ in
                        scheduleSearch()
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.accent)
                    TextField(L10n.Pulse.musicSearchPlaceholder, text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { scheduleSearch(immediate: true) }
                }
                .padding(12)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .onChange(of: query) { _, _ in
                    scheduleSearch()
                }

                Text(L10n.Pulse.musicDeezerPreview)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 16)

                if searchService.isSearching {
                    ProgressView("Buscando em \(provider.title)…")
                        .padding(.top, 8)
                } else if let status = searchService.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 16)
                }

                List(searchService.results) { track in
                    Button {
                        var selected = track
                        selected.clipStartSeconds = 0
                        selected.clipDurationSeconds = min(15, PulseExperimental.maxMusicClipSeconds)
                        selectedTrack = selected
                        dismiss()
                    } label: {
                        PulseMusicTrackRow(track: track, isSelected: selectedTrack?.id == track.id)
                    }
                    .listRowBackground(AppTheme.cardBackground)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(L10n.Pulse.musicClipTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Pulse.close) { dismiss() }
                }
                if selectedTrack != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Remover") {
                            selectedTrack = nil
                            dismiss()
                        }
                    }
                }
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        searchTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            guard !Task.isCancelled else { return }
            await searchService.search(query: query, provider: provider)
        }
    }
}

struct PulseMusicTrackRow: View {
    let track: PulseMusicAttachment
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            PulseMusicArtworkView(urlString: track.artworkURL, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Label(track.providerLabel, systemImage: track.provider.systemImage)
                    if track.previewURL != nil {
                        Text("· preview")
                    }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PulseMusicArtworkView: View {
    let urlString: String?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var placeholder: some View {
        ZStack {
            AppTheme.accent.opacity(0.2)
            Image(systemName: "music.note")
                .foregroundStyle(AppTheme.accent)
        }
    }
}

struct PulseMusicStickerView: View {
    let music: PulseMusicAttachment
    @ObservedObject var previewPlayer: PulseMusicPreviewPlayer
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            PulseMusicArtworkView(urlString: music.artworkURL, size: compact ? 36 : 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(music.title)
                    .font(compact ? .caption.weight(.bold) : .subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(music.artistName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                Text("\(music.providerLabel) · \(music.clipRangeLabel)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            Spacer(minLength: 8)
            if music.previewURL != nil {
                Button {
                    previewPlayer.toggle(music: music, loop: true)
                } label: {
                    Image(systemName: previewPlayer.isPlayingMusic(music) ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.accent)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(previewPlayer.isPlayingMusic(music) ? L10n.Pulse.stopMusic : L10n.Pulse.playMusic)
            }
            if let external = music.externalURL, let url = URL(string: external) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(AppTheme.accent.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(AppTheme.accent.opacity(0.45), lineWidth: 1)
        )
    }
}

/// Escolhe o trecho da música (máx. 30s) com scrub ao vivo, estilo Instagram.
struct PulseMusicClipEditor: View {
    @Binding var music: PulseMusicAttachment
    @ObservedObject private var player = PulseMusicPreviewPlayer.shared
    @State private var previewDuration: Double = PulseExperimental.maxMusicClipSeconds
    @State private var isLoadingDuration = false
    @State private var dragStartOrigin: Double?

    private var windowDuration: Double {
        min(max(music.clipDurationSeconds, PulseExperimental.minMusicClipSeconds), maxClipDuration)
    }

    private var maxStart: Double {
        max(0, previewDuration - windowDuration)
    }

    private var maxClipDuration: Double {
        min(PulseExperimental.maxMusicClipSeconds, max(PulseExperimental.minMusicClipSeconds, previewDuration))
    }

    private var playheadInClip: Double {
        guard player.isPlayingMusic(music) else { return 0 }
        return min(max(0, player.currentSeconds - music.clipStartSeconds), windowDuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Pulse.musicClipTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Arraste a janela · \(music.clipRangeLabel) · \(Int(windowDuration.rounded()))s")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Button {
                    if player.isPlayingMusic(music) {
                        player.pause()
                    } else {
                        player.playClipPreview(music: music)
                    }
                } label: {
                    Image(systemName: player.isPlayingMusic(music) ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.accent)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .disabled(music.previewURL == nil || isLoadingDuration)
                .accessibilityLabel(player.isPlayingMusic(music) ? L10n.Pulse.stopMusic : L10n.Pulse.playMusic)
            }

            if isLoadingDuration {
                ProgressView("Carregando preview…")
                    .font(.caption)
            } else if music.previewURL == nil {
                Text("Esta faixa não tem preview para cortar o trecho.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                clipTimeline

                HStack {
                    Text(PulseMusicAttachment.formatTime(music.clipStartSeconds))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(player.isPlayingMusic(music)
                           ? "▶ \(PulseMusicAttachment.formatTime(player.currentSeconds))"
                           : "Toque play ou arraste para ouvir")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                    Spacer()
                    Text(PulseMusicAttachment.formatTime(music.clipEndSeconds))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Duração do trecho (\(Int(windowDuration.rounded()))s)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Slider(
                        value: Binding(
                            get: { music.clipDurationSeconds },
                            set: { newValue in
                                music.clipDurationSeconds = newValue
                                music.normalizeClip(againstPreviewDuration: previewDuration)
                                player.playClipPreview(music: music)
                            }
                        ),
                        in: PulseExperimental.minMusicClipSeconds...max(PulseExperimental.minMusicClipSeconds, maxClipDuration),
                        step: 1
                    )
                    .tint(AppTheme.accent)
                }
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: music.previewURL) {
            await loadPreviewDuration()
        }
        .onDisappear {
            player.stop()
        }
    }

    private var clipTimeline: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let full = max(previewDuration, 0.01)
            let startX = width * (music.clipStartSeconds / full)
            let windowW = max(28, width * (windowDuration / full))
            let playheadX = startX + width * (playheadInClip / full)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.10))

                HStack(spacing: 2) {
                    ForEach(0..<24, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 3, height: CGFloat(10 + (i % 5) * 4))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)

                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.accent.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(AppTheme.accent, lineWidth: 2)
                    )
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.white)
                            .frame(width: 3, height: 22)
                            .padding(.leading, 6)
                    }
                    .overlay(alignment: .trailing) {
                        Capsule()
                            .fill(.white)
                            .frame(width: 3, height: 22)
                            .padding(.trailing, 6)
                    }
                    .frame(width: windowW, height: 44)
                    .offset(x: startX)

                if player.isPlayingMusic(music) {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 2, height: 48)
                        .offset(x: min(max(0, playheadX), width - 2))
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 0)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 48)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartOrigin == nil {
                            // Se tocou fora da janela, ancora no ponto; se dentro, arrasta a janela.
                            let touchSeconds = Double(value.startLocation.x) / Double(width) * full
                            let windowEnd = music.clipStartSeconds + windowDuration
                            if touchSeconds < music.clipStartSeconds || touchSeconds > windowEnd {
                                dragStartOrigin = min(max(0, touchSeconds), maxStart)
                                music.clipStartSeconds = dragStartOrigin ?? 0
                            } else {
                                dragStartOrigin = music.clipStartSeconds
                            }
                        }
                        let origin = dragStartOrigin ?? music.clipStartSeconds
                        let deltaSeconds = Double(value.translation.width) / Double(width) * full
                        let next = min(max(0, origin + deltaSeconds), maxStart)
                        music.clipStartSeconds = next
                        music.normalizeClip(againstPreviewDuration: previewDuration)
                        player.playClipPreview(music: music)
                    }
                    .onEnded { _ in
                        dragStartOrigin = nil
                        player.playClipPreview(music: music)
                    }
            )
        }
        .frame(height: 48)
        .animation(.linear(duration: 0.05), value: player.currentSeconds)
    }

    private func loadPreviewDuration() async {
        guard let urlString = music.previewURL, let url = URL(string: urlString) else {
            previewDuration = PulseExperimental.maxMusicClipSeconds
            return
        }
        isLoadingDuration = true
        defer { isLoadingDuration = false }
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = duration.seconds
            previewDuration = seconds.isFinite && seconds > 0
                ? seconds
                : PulseExperimental.maxMusicClipSeconds
        } catch {
            previewDuration = PulseExperimental.maxMusicClipSeconds
        }
        // Janela menor que o preview inteiro para poder “avançar” o trecho.
        if music.clipDurationSeconds >= previewDuration - 0.25 {
            music.clipDurationSeconds = min(15, max(PulseExperimental.minMusicClipSeconds, previewDuration))
        }
        music.normalizeClip(againstPreviewDuration: previewDuration)
        player.playClipPreview(music: music)
    }
}

@MainActor
final class PulseMusicPreviewPlayer: ObservableObject {
    static let shared = PulseMusicPreviewPlayer()

    @Published private(set) var isPlaying = false
    @Published private(set) var activeURL: String?
    @Published private(set) var activeMusicID: String?
    @Published private(set) var currentSeconds: Double = 0

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var clipEndSeconds: Double = PulseExperimental.maxMusicClipSeconds
    private var clipStartSeconds: Double = 0
    private var shouldLoop = true
    private var activeMusic: PulseMusicAttachment?
    private var scrubGeneration = 0

    private init() {}

    func isPlayingMusic(_ music: PulseMusicAttachment) -> Bool {
        isPlaying && activeMusicID == music.id
    }

    func toggle(music: PulseMusicAttachment, loop: Bool = true) {
        if isPlayingMusic(music) {
            pause()
            return
        }
        play(music: music, loop: loop)
    }

    /// Compatibilidade com calls antigos por URL.
    func toggle(urlString: String?) {
        guard let urlString else { return }
        if activeURL == urlString, isPlaying {
            pause()
            return
        }
        guard URL(string: urlString) != nil else { return }
        var stub = PulseMusicAttachment(
            provider: .deezer,
            trackId: urlString,
            title: "",
            artistName: "",
            previewURL: urlString
        )
        stub.clipStartSeconds = 0
        stub.clipDurationSeconds = PulseExperimental.maxMusicClipSeconds
        play(music: stub, loop: true)
    }

    /// Scrub Instagram-like: sempre busca o início do trecho e toca.
    func playClipPreview(music: PulseMusicAttachment) {
        scrubGeneration += 1
        let generation = scrubGeneration
        guard let urlString = music.previewURL, let url = URL(string: urlString) else { return }

        activateAudioSession()
        shouldLoop = true
        clipStartSeconds = max(0, music.clipStartSeconds)
        clipEndSeconds = music.clipStartSeconds + min(
            music.clipDurationSeconds,
            PulseExperimental.maxMusicClipSeconds
        )

        if activeURL == urlString, player != nil {
            activeMusic = music
            activeMusicID = music.id
            currentSeconds = clipStartSeconds
            // Atualiza o botão imediatamente (antes do seek assíncrono).
            isPlaying = true
            seekAndPlay(to: clipStartSeconds, generation: generation)
            return
        }

        stopKeepingGeneration()
        scrubGeneration = generation
        // Restaurar identidade DEPOIS do stop (senão o sticker fica em “play”).
        activeMusic = music
        activeMusicID = music.id
        currentSeconds = clipStartSeconds
        isPlaying = true
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        activeURL = urlString
        attachObservers(to: newPlayer, item: item)
        seekAndPlay(to: clipStartSeconds, generation: generation)
    }

    func play(music: PulseMusicAttachment, loop: Bool = true) {
        shouldLoop = loop
        playClipPreview(music: music)
    }

    func seekToClipStart(music: PulseMusicAttachment, autoplay: Bool) {
        activeMusic = music
        clipStartSeconds = max(0, music.clipStartSeconds)
        clipEndSeconds = music.clipStartSeconds + min(
            music.clipDurationSeconds,
            PulseExperimental.maxMusicClipSeconds
        )
        if autoplay {
            playClipPreview(music: music)
        } else if activeURL == music.previewURL {
            let start = CMTime(seconds: clipStartSeconds, preferredTimescale: 600)
            player?.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
            currentSeconds = clipStartSeconds
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        deactivateAudioSession()
    }

    func stop() {
        scrubGeneration += 1
        stopKeepingGeneration()
    }

    private func stopKeepingGeneration() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        activeURL = nil
        activeMusicID = nil
        activeMusic = nil
        currentSeconds = 0
        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func attachObservers(to newPlayer: AVPlayer, item: AVPlayerItem) {
        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [box = WeakMainActorBox(self)] time in
            box.run { this in
                let seconds = time.seconds
                guard seconds.isFinite else { return }
                this.currentSeconds = seconds
                guard this.isPlaying else { return }
                if seconds >= this.clipEndSeconds - 0.05 {
                    this.handleClipEnd()
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [box = WeakMainActorBox(self)] _ in
            box.run { this in
                this.handleClipEnd()
            }
        }
    }

    private func seekAndPlay(to seconds: Double, generation: Int) {
        let start = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero) { [box = WeakMainActorBox(self)] finished in
            guard finished else { return }
            box.run { this in
                guard this.scrubGeneration == generation else { return }
                this.player?.play()
                this.isPlaying = true
                this.currentSeconds = seconds
            }
        }
    }

    private func handleClipEnd() {
        if shouldLoop, let music = activeMusic {
            playClipPreview(music: music)
        } else {
            pause()
        }
    }

    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Preview still attempts to play with system defaults.
        }
    }

    deinit {
        // Cleanup via stop() on disappear.
    }
}
