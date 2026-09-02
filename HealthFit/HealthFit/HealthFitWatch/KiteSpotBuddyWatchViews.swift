import SwiftUI

#if os(watchOS)
// MARK: - Root

struct KiteSpotBuddyWatchRootView: View {
    @ObservedObject var workoutManager: WatchWorkoutManager
    @State private var crownValue: Double = 0
    @State private var selectedPeer: KiteSpotBuddyPeer?

    var body: some View {
        Group {
            if let alert = workoutManager.spotBuddyIncomingHelp {
                KiteSpotBuddyWatchAlertView(
                    peer: alert,
                    onGoTo: {
                        selectedPeer = alert
                        workoutManager.dismissSpotBuddyHelpAlert()
                    },
                    onIgnore: {
                        workoutManager.dismissSpotBuddyHelpAlert()
                    }
                )
            } else if let peer = selectedPeer {
                KiteSpotBuddyWatchCompassView(peer: peer, onBack: { selectedPeer = nil })
            } else {
                KiteSpotBuddyWatchRadarView(
                    peers: workoutManager.spotBuddyPeers,
                    needsHelp: workoutManager.spotBuddyNeedsHelp,
                    spotBuddyEnabled: workoutManager.spotBuddyEnabled,
                    crownValue: $crownValue,
                    onSelectPeer: { selectedPeer = $0 },
                    onRequestHelp: { workoutManager.requestSpotBuddyHelp() },
                    onCancelHelp: { workoutManager.cancelSpotBuddyHelp() }
                )
            }
        }
    }
}

// MARK: - Avatar

private struct KiteSpotBuddyWatchAvatar: View {
    let name: String
    var photoURL: String?
    var size: CGFloat = 56

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }

    var body: some View {
        Group {
            if let photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure, .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Color.gray.opacity(0.35))
            Text(initial)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Radar

struct KiteSpotBuddyWatchRadarView: View {
    let peers: [KiteSpotBuddyPeer]
    let needsHelp: Bool
    let spotBuddyEnabled: Bool
    @Binding var crownValue: Double
    var onSelectPeer: (KiteSpotBuddyPeer) -> Void
    var onRequestHelp: () -> Void
    var onCancelHelp: () -> Void

    private let radarMaxMeters: Double = 2_000

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                header
                radarDisk
                peerList
                footer
            }
            .padding(.horizontal, 4)
        }
        .focusable(spotBuddyEnabled && !needsHelp)
        .digitalCrownRotation(
            $crownValue,
            from: 0,
            through: 1,
            by: 0.03,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, value in
            guard spotBuddyEnabled, !needsHelp, value >= 0.98 else { return }
            onRequestHelp()
            crownValue = 0
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "wind")
                    .font(.system(size: 11, weight: .semibold))
                Text("Kitesurf · Spot Buddy")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.cyan)

            if spotBuddyEnabled {
                Text(peers.isEmpty ? "Nenhum amigo no spot" : "\(peers.count) amigo\(peers.count == 1 ? "" : "s") no spot")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var radarDisk: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size * 0.36
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .scaleEffect(0.66)
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .scaleEffect(0.33)
                radarCrosshair(size: size * 0.72)
                radarCardinals(size: size * 0.88)

                Circle()
                    .fill(Color.white)
                    .frame(width: 5, height: 5)

                if !spotBuddyEnabled {
                    Text("Ative no iPhone")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 8)
                } else {
                    ForEach(peers.prefix(6)) { peer in
                        radarBlip(peer: peer, radius: radius)
                    }
                }
            }
            .frame(width: size, height: size)
            .clipped()
            .frame(maxWidth: .infinity)
        }
        .frame(height: 100)
    }

    private func radarCrosshair(size: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: size * 0.84)
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: size * 0.84, height: 1)
        }
    }

    private func radarCardinals(size: CGFloat) -> some View {
        let offset = size * 0.44
        return ZStack {
            cardinalLabel("N", x: 0, y: -offset)
            cardinalLabel("S", x: 0, y: offset)
            cardinalLabel("L", x: offset, y: 0)
            cardinalLabel("O", x: -offset, y: 0)
        }
    }

    private func cardinalLabel(_ text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.55))
            .offset(x: x, y: y)
    }

    private func radarBlip(peer: KiteSpotBuddyPeer, radius: CGFloat) -> some View {
        let bearing = (peer.bearingDegrees ?? 0) * .pi / 180
        // Mantém blips para dentro — nome/seta não saem da tela
        let distFactor = min(max(peer.distanceMeters / radarMaxMeters, 0.15), 0.78)
        let x = sin(bearing) * radius * distFactor
        let y = -cos(bearing) * radius * distFactor

        return Image(systemName: "location.north.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(peer.needsHelp ? .orange : .green)
            .rotationEffect(.degrees(peer.bearingDegrees ?? 0))
            .offset(x: x, y: y)
            .accessibilityLabel("\(shortName(peer.displayName)), \(formatDistanceShort(peer.distanceMeters))")
    }

    private var peerList: some View {
        VStack(spacing: 4) {
            ForEach(peers.prefix(4)) { peer in
                Button { onSelectPeer(peer) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(peer.needsHelp ? .orange : .green)
                            .rotationEffect(.degrees(peer.bearingDegrees ?? 0))
                        Text(peer.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(formatDistanceShort(peer.distanceMeters))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.green)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            if needsHelp {
                Text("Pedido de ajuda enviado")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.orange)
                Button("Estou bem") { onCancelHelp() }
                    .font(.system(size: 11, weight: .semibold))
                    .buttonStyle(.bordered)
                    .tint(.orange)
            } else if spotBuddyEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "digitalcrown.horizontal.arrow.counterclockwise.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.cyan)
                    Text("Girar coroa = Pedir ajuda")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.cyan)
                }
                if crownValue > 0.05 {
                    ProgressView(value: min(crownValue, 1))
                        .tint(.orange)
                }
            }
        }
        .padding(.top, 2)
    }

    private func shortName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    private func formatDistanceShort(_ meters: Double) -> String {
        if meters < 1_000 { return String(format: "%.0fm", meters) }
        return String(format: "%.1fkm", meters / 1_000)
    }
}

// MARK: - Help alert

struct KiteSpotBuddyWatchAlertView: View {
    let peer: KiteSpotBuddyPeer
    var onGoTo: () -> Void
    var onIgnore: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("PRECISA DE AJUDA")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.red)
                    .padding(.top, 2)

                KiteSpotBuddyWatchAvatar(
                    name: peer.displayName,
                    photoURL: peer.photoURL,
                    size: 64
                )

                Text(peer.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 36, height: 36)
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(peer.bearingDegrees ?? 0))
                }

                Text(formatDistance(peer.distanceMeters))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Button(action: onGoTo) {
                    Text("Ir até \(firstName(peer.displayName))")
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button("Ignorar", action: onIgnore)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .tint(.gray)
            }
            .padding(.horizontal, 6)
        }
    }

    private func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    private func formatDistance(_ meters: Double) -> String {
        String(format: "%.0f m", meters)
    }
}

// MARK: - Compass navigation

struct KiteSpotBuddyWatchCompassView: View {
    let peer: KiteSpotBuddyPeer
    var onBack: () -> Void

    private var approachProgress: Double {
        1 - min(max(peer.distanceMeters / 2_000, 0), 1)
    }

    private var bearing: Double { peer.bearingDegrees ?? 0 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let roseSize = min(w * 0.78, h * 0.48, 92)

            VStack(spacing: 2) {
                // Header compacto
                HStack(spacing: 2) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.plain)

                    Text(firstName(peer.displayName))
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(formatDistance(peer.distanceMeters))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.cyan)
                        .lineLimit(1)
                        .fixedSize()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 2)

                // Rosa + seta (sem texto rotacionando — evita sair da tela)
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        .frame(width: roseSize, height: roseSize)

                    // Apenas 4 pontos cardeais — cabem no Watch
                    ForEach(cardinalPoints, id: \.label) { point in
                        Text(point.label)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.55))
                            .offset(
                                x: sin(point.angle) * (roseSize * 0.42),
                                y: -cos(point.angle) * (roseSize * 0.42)
                            )
                    }

                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)

                    // Seta apontando para o amigo (só ícone, sem nome)
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.green)
                        .offset(y: -(roseSize * 0.22))
                        .rotationEffect(.degrees(bearing))
                }
                .frame(width: roseSize + 8, height: roseSize + 8)
                .clipped()
                .frame(maxWidth: .infinity)

                Text("aproximando...")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)

                GeometryReader { barGeo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                        Capsule()
                            .fill(Color.cyan)
                            .frame(width: max(4, barGeo.size.width * approachProgress))
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 10)
            }
            .frame(width: w, height: h, alignment: .top)
        }
        .padding(.horizontal, 2)
    }

    private var cardinalPoints: [(label: String, angle: Double)] {
        [
            ("N", 0),
            ("L", 90),
            ("S", 180),
            ("O", 270),
        ].map { ($0.0, $0.1 * .pi / 180) }
    }

    private func firstName(_ name: String) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? name
        return String(first.prefix(10))
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1_000 { return String(format: "%.0fm", meters) }
        return String(format: "%.1fkm", meters / 1_000)
    }
}
#endif
