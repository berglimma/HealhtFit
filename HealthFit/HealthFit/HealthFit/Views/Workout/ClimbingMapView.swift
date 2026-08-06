import Combine
import CoreLocation
import MapKit
import SwiftUI

/// Mapa com as áreas de escalada — catálogo curado somado à busca do MapKit.
struct ClimbingMapView: View {
    /// Chamado ao confirmar um setor, para preencher o setup da sessão.
    var onSelect: ((ClimbingArea) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var catalog = ClimbingAreaCatalog.shared
    @StateObject private var locator = ClimbingAreaLocator()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedArea: ClimbingArea?
    @State private var showsNearbySearch = false

    private var areas: [ClimbingArea] {
        let curated = catalog.curatedAreas(near: locator.coordinate)
        guard showsNearbySearch else { return curated }
        return catalog.nearbyResults + curated
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()

            Map(position: $cameraPosition, selection: $selectedArea) {
                UserAnnotation()

                ForEach(areas) { area in
                    Marker(area.name, systemImage: "figure.climbing", coordinate: area.coordinate)
                        .tint(AppTheme.accentSecondary)
                        .tag(area)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 12) {
                if let selectedArea {
                    areaCard(selectedArea)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    hintCard
                }
            }
            .padding(16)
            .animation(.easeInOut(duration: 0.2), value: selectedArea)
        }
        .navigationTitle("Áreas de escalada")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsNearbySearch.toggle()
                    if showsNearbySearch, let coordinate = locator.coordinate {
                        Task { await catalog.searchNearby(coordinate: coordinate) }
                    }
                } label: {
                    Image(systemName: showsNearbySearch ? "mappin.circle.fill" : "mappin.circle")
                }
                .accessibilityLabel("Buscar áreas próximas no mapa")
            }
        }
        .task {
            locator.requestLocation()
        }
        .onChange(of: locator.coordinate?.latitude) { _, _ in
            guard let coordinate = locator.coordinate else { return }
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 150_000,
                    longitudinalMeters: 150_000
                )
            )
        }
    }

    private var hintCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap")
                .foregroundStyle(AppTheme.accent)
            Text(catalog.isSearching
                 ? "Buscando setores próximos…"
                 : "Toque em um marcador para ver o setor.")
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
        }
        .padding(14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func areaCard(_ area: ClimbingArea) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(area.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(area.region)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                if let coordinate = locator.coordinate {
                    Text(String(format: "%.0f km", area.distanceKm(from: coordinate)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            HStack(spacing: 12) {
                Label(area.disciplineSummary, systemImage: "figure.climbing")
                if area.routeCount > 0 {
                    Label("\(area.routeCount) vias", systemImage: "list.number")
                }
                Label(area.gradeRange, systemImage: "chart.bar")
            }
            .font(.caption2)
            .foregroundStyle(AppTheme.textSecondary)

            if !area.notes.isEmpty {
                Text(area.notes)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                if onSelect != nil {
                    Button {
                        onSelect?(area)
                        dismiss()
                    } label: {
                        Text("Escalar aqui")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    openInMaps(area)
                } label: {
                    Label("Rotas", systemImage: "car.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: onSelect == nil ? .infinity : nil)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func openInMaps(_ area: ClimbingArea) {
        let placemark = MKPlacemark(coordinate: area.coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = area.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// MARK: - Localização

/// GPS leve só para centralizar o mapa e ordenar por distância.
@MainActor
final class ClimbingAreaLocator: NSObject, ObservableObject {
    @Published private(set) var coordinate: CLLocationCoordinate2D?

    private var manager: CLLocationManager?

    func requestLocation() {
        guard manager == nil else { return }
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        self.manager = manager

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }
}

extension ClimbingAreaLocator: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        manager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = location.coordinate
        Task { @MainActor [weak self] in
            self?.coordinate = coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

/// Rota de navegação para o mapa de áreas.
struct ClimbingMapRoute: Hashable {}
