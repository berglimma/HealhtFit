import MapKit
import SwiftUI

/// Mapa MapKit com polyline colorida por desempenho e marcador de início.
/// Inclui seletor 2D / 3D com câmera inclinada sobre o percurso (todas as modalidades com GPS).
/// Em kitesurf/surf, desenha curvas de subida/descida dos saltos ancoradas na trilha GPS.
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
    /// Pin "Fim" só após finalizar (resumo); durante o treino fica oculto.
    var showsEndPin: Bool = false

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
        guard coordinates.count >= 2 else { return nil }
        let last = coordinates[coordinates.count - 1]
        let first = coordinates[0]
        // Evita pin de fim colado no início no começo da sessão.
        let startLoc = CLLocation(latitude: first.latitude, longitude: first.longitude)
        let endLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
        guard startLoc.distance(from: endLoc) >= 3 else { return nil }
        return last
    }

    private var performanceSegments: [RoutePerformanceSegment] {
        RoutePerformanceColoring.segments(from: routePoints, metric: performanceMetric)
    }

    /// Arcos de salto (subida/descida) sobre a linha GPS.
    private var jumpArcs: [JumpRouteArc] {
        JumpRouteArcBuilder.buildArcs(jumps: jumpEvents, route: routePoints)
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
                    Text(jumpArcs.isEmpty
                         ? (coordinates.count >= 2
                            ? "3D: percurso no terreno"
                            : "3D: vista inclinada do local")
                         : "3D: rota GPS + curvas de salto (subida/descida)")
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

                // Saltos: linha GPS base + arco subida (ciano) e descida (laranja).
                ForEach(jumpArcs) { arc in
                    if arc.groundPath.count >= 2 {
                        MapPolyline(coordinates: arc.groundPath)
                            .stroke(
                                Color.white.opacity(is3DEnabled ? 0.75 : 0.55),
                                style: StrokeStyle(
                                    lineWidth: is3DEnabled ? 5 : 3.5,
                                    lineCap: .round,
                                    lineJoin: .round,
                                    dash: [6, 5]
                                )
                            )
                    }

                    if arc.ascentCurve.count >= 2 {
                        MapPolyline(coordinates: arc.ascentCurve)
                            .stroke(
                                Color.cyan,
                                style: StrokeStyle(
                                    lineWidth: is3DEnabled ? 6.5 : 5,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                    }

                    if arc.descentCurve.count >= 2 {
                        MapPolyline(coordinates: arc.descentCurve)
                            .stroke(
                                Color.orange,
                                style: StrokeStyle(
                                    lineWidth: is3DEnabled ? 6.5 : 5,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                    }

                    Annotation("Decolagem \(arc.index)", coordinate: arc.takeoffCoordinate) {
                        jumpPhaseDot(color: .cyan, symbol: "arrow.up")
                    }
                    Annotation("Pouso \(arc.index)", coordinate: arc.landingCoordinate) {
                        jumpPhaseDot(color: .orange, symbol: "arrow.down")
                    }
                    Annotation("", coordinate: arc.apexCoordinate) {
                        jumpMarker(index: arc.index, heightMeters: arc.heightMeters)
                    }
                }

                if let start = startCoordinate {
                    Annotation("Início", coordinate: start) {
                        routeEndpointMarker(systemImage: "flag.fill", color: AppTheme.accent, label: "Início")
                    }
                }

                // Pin "Fim" apenas no resumo (após Encerrar), não durante a corrida ao vivo.
                if showsEndPin, let end = endCoordinate {
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

                // Marcadores de salto sem arco (sem GPS próximo ou sem coordenadas).
                ForEach(jumpEventsWithoutArc, id: \.id) { jump in
                    if let coordinate = jump.coordinate {
                        let displayIndex = (jumpEvents.firstIndex(where: { $0.id == jump.id }) ?? 0) + 1
                        Annotation("", coordinate: coordinate) {
                            jumpMarker(index: displayIndex, heightMeters: jump.heightMeters)
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

            if !jumpArcs.isEmpty {
                jumpArcLegend
            }
        }
    }

    /// Saltos que não geraram arco (só pin no ponto).
    private var jumpEventsWithoutArc: [SurfJumpEvent] {
        let arcIDs = Set(jumpArcs.map(\.id))
        return jumpEvents.filter { !arcIDs.contains($0.id) && $0.coordinate != nil }
    }

    private var jumpArcLegend: some View {
        HStack(spacing: 12) {
            legendSwatch(color: .cyan, label: "Subida")
            legendSwatch(color: .orange, label: "Descida")
            legendSwatch(color: .white.opacity(0.7), label: "GPS", dashed: true)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(AppTheme.textSecondary)
    }

    private func legendSwatch(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 4) {
            Capsule()
                .fill(color)
                .frame(width: dashed ? 16 : 14, height: 3)
                .opacity(dashed ? 0.7 : 1)
            Text(label)
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

    private func jumpPhaseDot(color: Color, symbol: String) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
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
        for arc in jumpArcs {
            coords.append(contentsOf: arc.ascentCurve)
            coords.append(contentsOf: arc.descentCurve)
            coords.append(contentsOf: arc.groundPath)
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

// MARK: - Geometria de saltos sobre a trilha GPS

/// Segmento de salto para o mapa: subida e descida ancoradas na trilha GPS.
private struct JumpRouteArc: Identifiable {
    let id: UUID
    let index: Int
    let heightMeters: Double
    let groundPath: [CLLocationCoordinate2D]
    let ascentCurve: [CLLocationCoordinate2D]
    let descentCurve: [CLLocationCoordinate2D]
    let apexCoordinate: CLLocationCoordinate2D
    let takeoffCoordinate: CLLocationCoordinate2D
    let landingCoordinate: CLLocationCoordinate2D
}

/// Gera arcos de salto (subida/descida) a partir de eventos + trilha GPS.
private enum JumpRouteArcBuilder {
    static func buildArcs(
        jumps: [SurfJumpEvent],
        route: [RouteCoordinate]
    ) -> [JumpRouteArc] {
        guard !jumps.isEmpty else { return [] }
        return jumps.enumerated().compactMap { offset, jump in
            buildArc(jump: jump, index: offset + 1, route: route)
        }
    }

    private static func buildArc(
        jump: SurfJumpEvent,
        index: Int,
        route: [RouteCoordinate]
    ) -> JumpRouteArc? {
        let height = max(jump.heightMeters, 0.35)
        let airtime = max(jump.airtimeSeconds ?? estimatedAirtime(height: height), 0.45)

        let anchorIndex: Int
        let anchorCoord: CLLocationCoordinate2D

        if let nearest = nearestRouteIndex(for: jump, route: route) {
            anchorIndex = nearest
            anchorCoord = route[nearest].coordinate
        } else if let jumpCoord = jump.coordinate {
            anchorIndex = 0
            anchorCoord = jumpCoord
        } else {
            return nil
        }

        let speed = max(
            route.indices.contains(anchorIndex)
                ? (route[anchorIndex].speedMetersPerSecond ?? 0)
                : 0,
            4
        )
        let halfSpanMeters = max(14, min(90, max(speed * airtime * 0.55, sqrt(height) * 9)))

        let groundPath: [CLLocationCoordinate2D]
        if route.count >= 2, route.indices.contains(anchorIndex) {
            groundPath = extractGroundPath(
                route: route,
                around: anchorIndex,
                halfSpanMeters: halfSpanMeters
            )
        } else {
            groundPath = syntheticGroundPath(
                center: anchorCoord,
                halfSpanMeters: halfSpanMeters,
                headingDegrees: syntheticHeading(from: route, around: anchorIndex)
            )
        }

        guard groundPath.count >= 2 else { return nil }

        let samples = densifyPath(groundPath, desiredCount: 20)
        guard samples.count >= 3 else { return nil }

        // Escala visual: projeção lateral da altura (MapPolyline é 2D; o arco mostra o perfil).
        let apexOffsetMeters = max(12, min(100, height * 4.2))

        var curve: [CLLocationCoordinate2D] = []
        curve.reserveCapacity(samples.count)

        for i in samples.indices {
            let t = Double(i) / Double(samples.count - 1)
            let heightFraction = 4 * t * (1 - t)
            let offsetMeters = heightFraction * apexOffsetMeters
            let heading = localHeading(along: samples, at: i)
            curve.append(
                offsetCoordinate(samples[i], meters: offsetMeters, bearingDegrees: heading + 90)
            )
        }

        let apexIndex = max(1, min(curve.count - 2, curve.count / 2))
        let ascent = Array(curve[0...apexIndex])
        var descent = Array(curve[apexIndex...])
        if descent.count < 2, let last = ascent.last {
            descent = [last, curve.last ?? last]
        }

        return JumpRouteArc(
            id: jump.id,
            index: index,
            heightMeters: height,
            groundPath: samples,
            ascentCurve: ascent,
            descentCurve: descent,
            apexCoordinate: curve[apexIndex],
            takeoffCoordinate: samples.first ?? anchorCoord,
            landingCoordinate: samples.last ?? anchorCoord
        )
    }

    private static func extractGroundPath(
        route: [RouteCoordinate],
        around index: Int,
        halfSpanMeters: Double
    ) -> [CLLocationCoordinate2D] {
        var before: [CLLocationCoordinate2D] = [route[index].coordinate]
        var accumulated = 0.0
        var i = index
        while i > 0, accumulated < halfSpanMeters {
            let a = route[i].clLocation
            let b = route[i - 1].clLocation
            accumulated += a.distance(from: b)
            before.insert(route[i - 1].coordinate, at: 0)
            i -= 1
        }

        var after: [CLLocationCoordinate2D] = []
        accumulated = 0
        i = index
        while i < route.count - 1, accumulated < halfSpanMeters {
            let a = route[i].clLocation
            let b = route[i + 1].clLocation
            accumulated += a.distance(from: b)
            after.append(route[i + 1].coordinate)
            i += 1
        }

        return before + after
    }

    private static func syntheticGroundPath(
        center: CLLocationCoordinate2D,
        halfSpanMeters: Double,
        headingDegrees: Double
    ) -> [CLLocationCoordinate2D] {
        let takeoff = offsetCoordinate(center, meters: halfSpanMeters, bearingDegrees: headingDegrees + 180)
        let landing = offsetCoordinate(center, meters: halfSpanMeters, bearingDegrees: headingDegrees)
        return densifyPath([takeoff, center, landing], desiredCount: 12)
    }

    private static func syntheticHeading(from route: [RouteCoordinate], around index: Int) -> Double {
        guard route.count >= 2 else { return 0 }
        if route.indices.contains(index), index > 0 {
            return bearing(from: route[index - 1].coordinate, to: route[index].coordinate)
        }
        if route.count >= 2 {
            return bearing(
                from: route[max(0, route.count - 2)].coordinate,
                to: route[route.count - 1].coordinate
            )
        }
        return 0
    }

    private static func nearestRouteIndex(for jump: SurfJumpEvent, route: [RouteCoordinate]) -> Int? {
        guard !route.isEmpty else { return nil }

        if let jumpCoord = jump.coordinate {
            var bestIdx = 0
            var bestDist = Double.greatestFiniteMagnitude
            let jumpLoc = CLLocation(latitude: jumpCoord.latitude, longitude: jumpCoord.longitude)
            for (idx, point) in route.enumerated() {
                let d = jumpLoc.distance(from: point.clLocation)
                if d < bestDist {
                    bestDist = d
                    bestIdx = idx
                }
            }
            if bestDist <= 250 { return bestIdx }
        }

        var bestIdx = 0
        var bestDelta = TimeInterval.greatestFiniteMagnitude
        for (idx, point) in route.enumerated() {
            let delta = abs(point.timestamp.timeIntervalSince(jump.timestamp))
            if delta < bestDelta {
                bestDelta = delta
                bestIdx = idx
            }
        }
        if bestDelta <= 45 { return bestIdx }
        return jump.coordinate != nil ? bestIdx : nil
    }

    private static func densifyPath(
        _ path: [CLLocationCoordinate2D],
        desiredCount: Int
    ) -> [CLLocationCoordinate2D] {
        guard path.count >= 2, desiredCount > 2 else { return path }

        var distances: [Double] = [0]
        var total = 0.0
        for i in 1..<path.count {
            let d = CLLocation(latitude: path[i - 1].latitude, longitude: path[i - 1].longitude)
                .distance(from: CLLocation(latitude: path[i].latitude, longitude: path[i].longitude))
            total += d
            distances.append(total)
        }
        guard total > 0.5 else { return path }

        var result: [CLLocationCoordinate2D] = []
        result.reserveCapacity(desiredCount)
        for s in 0..<desiredCount {
            let target = total * Double(s) / Double(desiredCount - 1)
            result.append(pointAlong(path: path, distances: distances, targetDistance: target))
        }
        return result
    }

    private static func pointAlong(
        path: [CLLocationCoordinate2D],
        distances: [Double],
        targetDistance: Double
    ) -> CLLocationCoordinate2D {
        guard path.count == distances.count, path.count >= 2 else {
            return path.last ?? path[0]
        }
        if targetDistance <= 0 { return path[0] }
        if let last = distances.last, targetDistance >= last { return path[path.count - 1] }

        var i = 1
        while i < distances.count, distances[i] < targetDistance {
            i += 1
        }
        let d0 = distances[i - 1]
        let d1 = distances[i]
        let span = max(d1 - d0, 0.0001)
        let t = (targetDistance - d0) / span
        let a = path[i - 1]
        let b = path[i]
        return CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t
        )
    }

    private static func localHeading(
        along samples: [CLLocationCoordinate2D],
        at index: Int
    ) -> Double {
        if index + 1 < samples.count {
            return bearing(from: samples[index], to: samples[index + 1])
        }
        if index > 0 {
            return bearing(from: samples[index - 1], to: samples[index])
        }
        return 0
    }

    private static func bearing(
        from a: CLLocationCoordinate2D,
        to b: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }

    private static func offsetCoordinate(
        _ coordinate: CLLocationCoordinate2D,
        meters: Double,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        guard meters > 0.05 else { return coordinate }
        let R = 6_371_000.0
        let brng = bearingDegrees * .pi / 180
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180
        let ang = meters / R

        let lat2 = asin(sin(lat1) * cos(ang) + cos(lat1) * sin(ang) * cos(brng))
        let lon2 = lon1 + atan2(
            sin(brng) * sin(ang) * cos(lat1),
            cos(ang) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }

    private static func estimatedAirtime(height: Double) -> TimeInterval {
        max(0.5, 2 * sqrt(2 * height / 9.81))
    }
}
