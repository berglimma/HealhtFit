import MapKit
import SwiftUI

/// Mapa MapKit com polyline colorida por desempenho e marcador de início.
struct RunRouteMapView: View {
    let routePoints: [RouteCoordinate]
    var userCoordinate: CLLocationCoordinate2D?
    var followUser: Bool = true
    var showsUserLocation: Bool = true
    var height: CGFloat = 220
    /// Ritmo (corrida) ou velocidade (bike) — mais rápido = verde.
    var performanceMetric: RoutePerformanceMetric = .pace
    /// Pontos de salto (surf/kitesurf) para anotar no mapa com altura.
    var jumpEvents: [SurfJumpEvent] = []
    /// Exibe controle Mapa 2D / 3D (surf e kitesurf).
    var allows3DMode: Bool = false

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var is3DEnabled = false

    private var coordinates: [CLLocationCoordinate2D] {
        routePoints.map(\.coordinate)
    }

    private var startCoordinate: CLLocationCoordinate2D? {
        coordinates.first
    }

    private var performanceSegments: [RoutePerformanceSegment] {
        RoutePerformanceColoring.segments(from: routePoints, metric: performanceMetric)
    }

    private var mapCenter: CLLocationCoordinate2D? {
        if followUser, let user = userCoordinate { return user }
        if let region = fittingRegion() { return region.center }
        return userCoordinate ?? startCoordinate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if allows3DMode {
                Picker("Mapa", selection: $is3DEnabled) {
                    Text("2D").tag(false)
                    Text("3D").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Modo do mapa")
            }

            Map(position: $cameraPosition) {
                ForEach(performanceSegments) { segment in
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(
                            segment.color,
                            style: StrokeStyle(lineWidth: allows3DMode ? 5.5 : 4.5, lineCap: .round, lineJoin: .round)
                        )
                }

                if let start = startCoordinate {
                    Annotation("Início", coordinate: start) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent)
                                .frame(width: 16, height: 16)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 16, height: 16)
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
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .onAppear {
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
        }
    }

    private var mapStyle: MapStyle {
        if is3DEnabled {
            return .standard(
                elevation: .realistic,
                pointsOfInterest: .excludingAll,
                showsTraffic: false
            )
        }
        return .standard(elevation: .flat, pointsOfInterest: .excludingAll)
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
        if is3DEnabled, let center = mapCenter {
            let camera = MapCamera(
                centerCoordinate: center,
                distance: 900,
                heading: 25,
                pitch: 58
            )
            withAnimation(animated ? .easeInOut(duration: 0.4) : nil) {
                cameraPosition = .camera(camera)
            }
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

    private func fittingRegion() -> MKCoordinateRegion? {
        var coords = coordinates
        for jump in jumpEvents {
            if let c = jump.coordinate {
                coords.append(c)
            }
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
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
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
