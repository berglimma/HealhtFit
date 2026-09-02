import MapKit
import SwiftUI

/// Tela Spot Buddy no iPhone — mapa satélite + lista de amigos (sessão de kitesurf ativa).
struct KiteSpotBuddyLiveMapView: View {
    @ObservedObject var service: KiteSpotBuddyService
    let routePoints: [RouteCoordinate]
    var userCoordinate: CLLocationCoordinate2D?
    var spotCoordinate: CLLocationCoordinate2D?
    var onRequestHelp: () -> Void
    var onCancelHelp: () -> Void
    var onDismiss: () -> Void
    var onInviteFriends: () -> Void
    var onAddFriend: () -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedPeer: KiteSpotBuddyPeer?

    private var helpPeer: KiteSpotBuddyPeer? {
        service.incomingHelpAlert ?? service.peers.first(where: \.needsHelp)
    }

    private var mapCenter: CLLocationCoordinate2D? {
        userCoordinate
            ?? spotCoordinate
            ?? routePoints.last?.coordinate
            ?? service.peers.first.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer

            VStack(spacing: 0) {
                topChrome
                Spacer(minLength: 0)
                bottomSheet
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear { recenterCamera() }
        .onChange(of: service.peers.count) { _, _ in recenterCamera(animated: true) }
        .onChange(of: userCoordinate?.latitude) { _, _ in
            guard selectedPeer == nil else { return }
            recenterCamera(animated: true)
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            if routePoints.count >= 2 {
                MapPolyline(coordinates: routePoints.map(\.coordinate))
                    .stroke(
                        Color.cyan.opacity(0.9),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
            }

            if let userCoordinate {
                Annotation("", coordinate: userCoordinate, anchor: .center) {
                    selfMarker
                }
            }

            ForEach(service.peers) { peer in
                Annotation("", coordinate: peer.coordinate, anchor: .center) {
                    peerMapMarker(peer)
                        .onTapGesture { selectedPeer = peer }
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControlVisibility(.hidden)
        .ignoresSafeArea(edges: .top)
        .safeAreaPadding(.top, 56)
        .safeAreaPadding(.bottom, 280)
        .overlay(alignment: .topTrailing) {
            Button {
                recenterCamera(animated: true)
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.cardBackground.opacity(0.92))
                    .clipShape(Circle())
            }
            .padding(.top, 56)
            .padding(.trailing, 16)
        }
    }

    private var selfMarker: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.25))
                .frame(width: 28, height: 28)
            Circle()
                .fill(AppTheme.accent)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
        }
        .frame(width: 28, height: 28)
    }

    private func peerMapMarker(_ peer: KiteSpotBuddyPeer) -> some View {
        ZStack {
            if peer.needsHelp {
                Circle()
                    .stroke(Color.red.opacity(0.4), lineWidth: 2)
                    .frame(width: 52, height: 52)
            }
            KiteSpotBuddyAvatar(
                name: peer.displayName,
                photoURL: peer.photoURL,
                size: 36,
                statusDot: peer.needsHelp ? .red : AppTheme.accent
            )
        }
        .frame(width: 52, height: 52)
        .clipped()
    }

    // MARK: - Top chrome

    private var topChrome: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.cardBackground.opacity(0.92))
                        .clipShape(Circle())
                }

                Label("Kitesurf", systemImage: CardioExercise.kitesurfSystemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.cardBackground.opacity(0.9))
                    .clipShape(Capsule())

                Spacer(minLength: 8)

                Label("\(service.peers.count)", systemImage: "person.2.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.cardBackground.opacity(0.9))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)

            if let help = helpPeer {
                helpBanner(help)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
    }

    private func helpBanner(_ peer: KiteSpotBuddyPeer) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "wind")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .fixedSize()

            Text("\(firstName(peer.displayName)) precisa de ajuda · \(formatDistance(peer.distanceMeters))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "location.north.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .rotationEffect(.degrees(peer.bearingDegrees ?? 0))
                .frame(width: 22, height: 22)
                .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.red.opacity(0.55), lineWidth: 1)
        )
        .onTapGesture { selectedPeer = peer }
    }

    // MARK: - Bottom sheet

    private var bottomSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spot Buddy")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Text("Amigos no seu alcance")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if service.needsHelp {
                    Button("Estou bem", action: onCancelHelp)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                        .fixedSize()
                } else {
                    Button(action: onRequestHelp) {
                        Label("Ajuda", systemImage: "sos")
                            .font(.caption.weight(.bold))
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .fixedSize()
                }
            }

            if service.peers.isEmpty {
                Text("Nenhum amigo com Spot Buddy ativo por perto (até 2 km). Convide a equipe Duo com modalidade kitesurf.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(service.peers) { peer in
                            peerRow(peer)
                            if peer.id != service.peers.last?.id {
                                Divider().background(Color.white.opacity(0.08))
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            HStack(spacing: 10) {
                Button(action: onInviteFriends) {
                    Label("Convidar", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accent)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.accent, lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.cardBackground)
                        )
                )

                Button(action: onAddFriend) {
                    Label("Adicionar", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 28,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 28,
                style: .continuous
            )
            .fill(AppTheme.background.opacity(0.97))
            .overlay(alignment: .top) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 28,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 28,
                    style: .continuous
                )
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
        )
    }

    private func peerRow(_ peer: KiteSpotBuddyPeer) -> some View {
        Button {
            selectedPeer = peer
            focus(on: peer)
        } label: {
            HStack(spacing: 12) {
                KiteSpotBuddyAvatar(
                    name: peer.displayName,
                    photoURL: peer.photoURL,
                    size: 48,
                    statusDot: peer.needsHelp ? .red : AppTheme.accent
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(firstName(peer.displayName))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(peer.needsHelp ? Color.red : AppTheme.textPrimary)
                        .lineLimit(1)
                    Text(peer.needsHelp ? "Precisando de ajuda" : "Tudo certo")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(peer.needsHelp ? Color.red : AppTheme.accent)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(formatDistance(peer.distanceMeters))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
                    .fixedSize()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                    .fixedSize()
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func recenterCamera(animated: Bool = false) {
        guard let center = mapCenter else { return }
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 1_200,
            longitudinalMeters: 1_200
        )
        withAnimation(animated ? .easeInOut(duration: 0.35) : nil) {
            cameraPosition = .region(region)
        }
    }

    private func focus(on peer: KiteSpotBuddyPeer) {
        let region = MKCoordinateRegion(
            center: peer.coordinate,
            latitudinalMeters: 600,
            longitudinalMeters: 600
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(region)
        }
    }

    private func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1_000 {
            return String(format: "%.0f m", meters)
        }
        let km = meters / 1_000
        return String(format: km < 10 ? "%.1f km" : "%.0f km", km)
            .replacingOccurrences(of: ".", with: ",")
    }
}

// MARK: - Avatar

struct KiteSpotBuddyAvatar: View {
    let name: String
    var photoURL: String?
    var size: CGFloat = 44
    var statusDot: Color? = nil

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5))

            if let statusDot {
                Circle()
                    .fill(statusDot)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().stroke(AppTheme.background, lineWidth: 2))
                    .offset(x: 2, y: 2)
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(AppTheme.accent.opacity(0.25))
            Text(initial)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(AppTheme.accent)
        }
    }
}

// MARK: - Entry card (sessão ao vivo)

struct KiteSpotBuddyEntryCard: View {
    @ObservedObject var service: KiteSpotBuddyService
    var onOpen: () -> Void
    var onRequestHelp: () -> Void
    var onCancelHelp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Spot Buddy", systemImage: "person.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(service.peers.count) no alcance")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
            }

            if let help = service.incomingHelpAlert ?? service.peers.first(where: \.needsHelp) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("\(help.displayName) precisa de ajuda · \(format(help.distanceMeters))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            } else if service.peers.isEmpty {
                Text("Mapa e amigos da equipe com Spot Buddy ativo (até 2 km).")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(service.peers.prefix(3)) { peer in
                    HStack {
                        Text(peer.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(format(peer.distanceMeters))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }

            HStack(spacing: 10) {
                Button(action: onOpen) {
                    Label("Abrir mapa", systemImage: "map.fill")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if service.needsHelp {
                    Button("Estou bem", action: onCancelHelp)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Button(action: onRequestHelp) {
                        Label("Ajuda", systemImage: "sos")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func format(_ meters: Double) -> String {
        meters < 1_000
            ? String(format: "%.0f m", meters)
            : String(format: "%.1f km", meters / 1_000)
    }
}

private extension KiteSpotBuddyPeer {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
