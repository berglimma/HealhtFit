import CoreLocation
import Foundation

/// Perigos na pista (buracos etc.) — store local + “comunidade” seed próxima ao ciclista.
@MainActor
final class RoadHazardService: ObservableObject {
    static let shared = RoadHazardService()
    static let alertRadiusMeters: CLLocationDistance = 90

    private let key = "healthfit.road.hazards.v1"
    private let seedMetaKey = "healthfit.road.hazards.seedMeta.v1"

    @Published private(set) var hazards: [RoadHazard] = []

    private init() {
        load()
    }

    func report(type: RoadHazardType, coordinate: CLLocationCoordinate2D, note: String) {
        let hazard = RoadHazard(
            type: type,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            isCommunitySeed: false
        )
        hazards.insert(hazard, at: 0)
        save()
    }

    func remove(_ hazard: RoadHazard) {
        hazards.removeAll { $0.id == hazard.id }
        save()
    }

    /// Gera perigos “da comunidade” perto da localização (demo / offline).
    func refreshSeedIfNeeded(near coordinate: CLLocationCoordinate2D?) {
        guard let coordinate else { return }
        let meta = SeedMeta.load(key: seedMetaKey)
        let now = Date()
        if let meta {
            let last = CLLocation(latitude: meta.lat, longitude: meta.lon)
            let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let movedFar = last.distance(from: current) > 2_500
            let stale = now.timeIntervalSince(meta.date) > 6 * 3600
            if !movedFar && !stale { return }
            hazards.removeAll { $0.isCommunitySeed }
        }

        let seeds = Self.makeCommunitySeeds(around: coordinate)
        hazards.append(contentsOf: seeds)
        SeedMeta(lat: coordinate.latitude, lon: coordinate.longitude, date: now).save(key: seedMetaKey)
        save()
    }

    func nearestHazard(
        to coordinate: CLLocationCoordinate2D,
        withinMeters: CLLocationDistance,
        excluding: Set<UUID>
    ) -> RoadHazard? {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return hazards
            .filter { !excluding.contains($0.id) }
            .compactMap { hazard -> (RoadHazard, CLLocationDistance)? in
                let d = origin.distance(from: CLLocation(latitude: hazard.latitude, longitude: hazard.longitude))
                guard d <= withinMeters else { return nil }
                return (hazard, d)
            }
            .sorted { $0.1 < $1.1 }
            .first?
            .0
    }

    private static func makeCommunitySeeds(around coordinate: CLLocationCoordinate2D) -> [RoadHazard] {
        // Offsets ~40–180 m (1° lat ≈ 111 km).
        let specs: [(type: RoadHazardType, dLat: Double, dLon: Double, note: String)] = [
            (.pothole, 0.00055, 0.00012, "Buraco no asfalto — comunidade"),
            (.glass, -0.00035, 0.00048, "Cacos de vidro reportados"),
            (.debris, 0.00022, -0.00062, "Galhos / entulho à beira da via"),
            (.construction, -0.00072, -0.00018, "Obra parcial na ciclovia"),
            (.pothole, 0.00105, 0.00075, "Cratera após chuva")
        ]
        return specs.map { spec in
            RoadHazard(
                type: spec.type,
                latitude: coordinate.latitude + spec.dLat,
                longitude: coordinate.longitude + spec.dLon,
                note: spec.note,
                reportedAt: Date().addingTimeInterval(-Double.random(in: 600...86_400)),
                isCommunitySeed: true
            )
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RoadHazard].self, from: data) else {
            hazards = []
            return
        }
        hazards = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(hazards) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private struct SeedMeta: Codable {
        var lat: Double
        var lon: Double
        var date: Date

        static func load(key: String) -> SeedMeta? {
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(SeedMeta.self, from: data)
        }

        func save(key: String) {
            if let data = try? JSONEncoder().encode(self) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
}
