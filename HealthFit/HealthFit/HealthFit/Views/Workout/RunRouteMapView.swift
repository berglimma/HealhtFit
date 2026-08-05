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
    /// Pontos de salto (surf/kitesurf) para anotar no mapa.
    var jumpEvents: [SurfJumpEvent] = []

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    private var coordinates: [CLLocationCoordinate2D] {
        routePoints.map(\.coordinate)
    }

    private var startCoordinate: CLLocationCoordinate2D? {
        coordinates.first
    }

    private var performanceSegments: [RoutePerformanceSegment] {
        RoutePerformanceColoring.segments(from: routePoints, metric: performanceMetric)
    }

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(performanceSegments) { segment in
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
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
                    Annotation(
                        String(format: "S%d · %.1fm", index + 1, jump.heightMeters),
                        coordinate: coordinate
                    ) {
                        ZStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                                .shadow(radius: 2)
                        }
                    }
                }
            }

            if showsUserLocation {
                UserAnnotation()
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapUserLocationButton()
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
    }

    private func updateCamera(animated: Bool) {
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
        let coords = coordinates
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
