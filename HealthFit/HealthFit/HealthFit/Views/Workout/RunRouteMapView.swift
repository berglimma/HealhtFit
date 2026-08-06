import MapKit
import SwiftUI

/// Mapa MapKit com polyline colorida por desempenho e marcador de início.
/// Inclui seletor 2D / 3D com câmera inclinada sobre o percurso (todas as modalidades com GPS).
struct RunRouteMapView: View {
    let routePoints: [RouteCoordinate]
    var userCoordinate: CLLocationCoordinate2D?
    var followUser: Bool = true
    var showsUserLocation: Bool = true
    var height: CGFloat = 220
    /// Ritmo (corrida) ou velocidade (bike/água) — mais rápido = verde.
    var performanceMetric: RoutePerformanceMetric = .pace
    /// Pontos de salto (surf/kitesurf) para anotar no mapa com altura.
    var jumpEvents: [SurfJumpEvent] = []
    /// Exibe controle Mapa 2D / 3D. Padrão: ligado em todos os mapas de percurso.
    var allows3DMode: Bool = true
    /// SPOT / ponto de partida quando ainda não há rota GPS.
    var spotCoordinate: CLLocationCoordinate2D? = nil
    var spotTitle: String? = nil
    /// Inicia em 3D quando o percurso já tem pontos (resumo / diário), ou se forçado.
    var prefers3DInitially: Bool = false

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var is3DEnabled = false
    @State private var didApplyInitialMode = false

    private var coordinates: [CLLocationCoordinate2D] {
        routePoints.map(\.coordinate)
    }

    private var startCoordinate: CLLocationCoordinate2D? {
        coordinates.first ?? spotCoordinate
    }

    private var endCoordinate: CLLocationCoordinate2D? {
        guard coordinates.count > 1 else { return nil }
        return coordinates.last
    }

    private var performanceSegments: [RoutePerformanceSegment] {
        RoutePerformanceColoring.segments(from: routePoints, metric: performanceMetric)
    }

    private var mapContentHeight: CGFloat {
        // Um pouco mais de altura no 3D para a polilinha do percurso caber na perspectiva.
        allows3DMode && is3DEnabled ? max(height, 280) : height
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if allows3DMode {
                Picker("Mapa", selection: $is3DEnabled) {
                    Text("2D").tag(false)
                    Text("3D").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Modo do mapa — 2D ou 3D com percurso")

                if is3DEnabled {
                    Text(coordinates.count >= 2
                         ? "3D: percurso no terreno"
                         : "3D: vista inclinada do local")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Map(position: $cameraPosition) {
                // Sombra sob a rota (só 3D) — desenhada primeiro, por baixo.
                if is3DEnabled, coordinates.count >= 2 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(
                            Color.white.opacity(0.4),
                            style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round)
                        )
                }

                ForEach(performanceSegments) { segment in
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(
                            segment.color,
                            style: StrokeStyle(
                                lineWidth: is3DEnabled ? 7 : (allows3DMode ? 5.5 : 4.5),
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }

                if let start = coordinates.first {
                    Annotation("Início", coordinate: start) {
                        routeEndpointMarker(systemImage: "flag.fill", color: AppTheme.accent, label: "Início")
                    }
                }

                if let end = endCoordinate, !followUser || !showsUserLocation {
                    Annotation("Fim", coordinate: end) {
                        routeEndpointMarker(systemImage: "flag.checkered", color: .orange, label: "Fim")
                    }
                }

                if let spot = spotCoordinate {
                    Annotation(spotTitle?.isEmpty == false ? (spotTitle ?? "SPOT") : "SPOT", coordinate: spot) {
                        VStack(spacing: 2) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.cyan)
                                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                            if let spotTitle, !spotTitle.isEmpty {
                                Text(spotTitle)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.55))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                ForEach(Array(jumpEvents.enumerated()), id: \.element.id) { index, jump in
                    if let coordinate = jump.coordinate {
                        Annotation("", coordinate: coordinate) {
                            jumpMarker(index: index + 1, heightMeters: jump.heightMeters)
                        }
                    }
                }

                if showsUserLocation {
                    UserAnnotation()
                }
            }
            .mapStyle(mapStyle)
            .mapControls {
                MapCompass()
                MapUserLocationButton()
                if is3DEnabled {
                    MapPitchToggle()
                }
            }
            .frame(height: mapContentHeight)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .onAppear {
                // Só força 3D no resumo/diário quando o caller pede; ao vivo o usuário escolhe 2D/3D.
                if allows3DMode, prefers3DInitially, !didApplyInitialMode {
                    is3DEnabled = true
                    didApplyInitialMode = true
                }
                updateCamera(animated: false)
            }
            .onChange(of: routePoints.count) { _, _ in
                updateCamera(animated: true)
            }
            .onChange(of: userCoordinate?.latitude) { _, _ in
                guard followUser else { return }
                updateCamera(animated: true)
            }
            .onChange(of: is3DEnabled) { _, _ in
                updateCamera(animated: true)
            }
            .onChange(of: jumpEvents.count) { _, _ in
                updateCamera(animated: true)
            }
            .onChange(of: spotCoordinate?.latitude) { _, _ in
                updateCamera(animated: true)
            }
        }
    }

    private var mapStyle: MapStyle {
        if is3DEnabled {
            // Hybrid + elevação: percurso e costa legíveis no surf/kite.
            return .hybrid(elevation: .realistic)
        }
        return .standard(elevation: .flat, pointsOfInterest: .excludingAll)
    }

    private func routeEndpointMarker(systemImage: String, color: Color, label: String) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 22, height: 22)
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
        }
    }

    private func jumpMarker(index: Int, heightMeters: Double) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%.1f m", heightMeters))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.red.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)

            ZStack {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 22, height: 22)
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )

            Text("#\(index)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
        }
    }

    private func updateCamera(animated: Bool) {
        if is3DEnabled {
            apply3DCamera(animated: animated)
            return
        }

        if followUser, let user = userCoordinate {
            let region = MKCoordinateRegion(
                center: user,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            )
            withAnimation(animated ? .easeInOut(duration: 0.35) : nil) {
                cameraPosition = .region(region)
            }
            return
        }

        guard let region = fittingRegion() else { return }
        withAnimation(animated ? .easeInOut(duration: 0.35) : nil) {
            cameraPosition = .region(region)
        }
    }

    /// Câmera inclinada enquadrando o percurso completo (ou o SPOT / usuário).
    private func apply3DCamera(animated: Bool) {
        let center: CLLocationCoordinate2D
        var distance: CLLocationDistance = 1_000

        if let region = fittingRegion() {
            if followUser, let user = userCoordinate {
                // Durante a sessão: centro no atleta, distância cobre o rastro recente.
                center = user
                let latM = max(region.span.latitudeDelta, 0.003) * 111_320
                let lonM = max(region.span.longitudeDelta, 0.003) * 111_320
                    * max(cos(region.center.latitude * .pi / 180), 0.2)
                distance = max(800, min(max(latM, lonM) * 2.0, 6_000))
            } else {
                center = region.center
                let latM = max(region.span.latitudeDelta, 0.004) * 111_320
                let lonM = max(region.span.longitudeDelta, 0.004) * 111_320
                    * max(cos(region.center.latitude * .pi / 180), 0.2)
                let spanM = max(latM, lonM)
                // Distância para o percurso inteiro caber na vista com pitch.
                distance = max(700, min(spanM * 2.6, 18_000))
            }
        } else if followUser, let user = userCoordinate {
            center = user
            distance = 900
        } else if let spot = spotCoordinate {
            center = spot
            distance = 1_400
        } else if let last = coordinates.last {
            center = last
            distance = 1_000
        } else {
            return
        }

        let camera = MapCamera(
            centerCoordinate: center,
            distance: distance,
            heading: bearingAlongRoute(),
            pitch: 58
        )
        withAnimation(animated ? .easeInOut(duration: 0.45) : nil) {
            cameraPosition = .camera(camera)
        }
    }

    /// Direção do último trecho do GPS (0–360°) para “voar” ao longo do percurso.
    private func bearingAlongRoute() -> CLLocationDirection {
        guard coordinates.count >= 2 else { return 20 }
        let sampleCount = min(8, coordinates.count)
        let start = coordinates[coordinates.count - sampleCount]
        let end = coordinates[coordinates.count - 1]
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let dLon = (end.longitude - start.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    private func fittingRegion() -> MKCoordinateRegion? {
        var coords = coordinates
        for jump in jumpEvents {
            if let c = jump.coordinate {
                coords.append(c)
            }
        }
        if let spot = spotCoordinate {
            coords.append(spot)
        }

        guard let first = coords.first else {
            if let user = userCoordinate {
                return MKCoordinateRegion(
                    center: user,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
            return nil
        }
        guard coords.count > 1 else {
            return MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            )
        }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for c in coords.dropFirst() {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.006),
            longitudeDelta: max((maxLon - minLon) * 1.6, 0.006)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
