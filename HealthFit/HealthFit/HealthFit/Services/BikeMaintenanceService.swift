import Foundation

import Combine
/// Diário da bike: pedais, problemas, manutenções e vida útil de peças.
@MainActor
final class BikeMaintenanceService: ObservableObject {
    static let shared = BikeMaintenanceService()

    private let logKey = "healthfit.bike.logbook.v1"
    private let wearKey = "healthfit.bike.wear.v1"
    private let totalKmKey = "healthfit.bike.totalKm.v1"

    @Published private(set) var entries: [BikeLogEntry] = []
    @Published private(set) var wearByPart: [BikeWearPart: BikeWearState] = [:]
    @Published private(set) var lifetimeKm: Double = 0

    private init() {
        load()
    }

    var recentEntries: [BikeLogEntry] {
        entries.sorted { $0.date > $1.date }
    }

    var problems: [BikeLogEntry] {
        recentEntries.filter { $0.kind == .problem }
    }

    var maintenances: [BikeLogEntry] {
        recentEntries.filter { $0.kind == .maintenance || $0.kind == .partReplace }
    }

    var rideEntries: [BikeLogEntry] {
        recentEntries.filter { $0.kind == .ride }
    }

    var partsNeedingAttention: [BikeWearPart] {
        BikeWearPart.allCases.filter { part in
            (wearByPart[part] ?? .fresh).needsAttention(for: part)
        }
    }

    func recordRide(distanceKm: Double, title: String, intensity: String) {
        let km = max(0, distanceKm)
        guard km > 0.01 else { return }

        lifetimeKm += km
        for part in BikeWearPart.allCases {
            var state = wearByPart[part] ?? .fresh
            state.kmSinceReplace += km
            wearByPart[part] = state
        }

        let entry = BikeLogEntry(
            kind: .ride,
            title: title.isEmpty ? "Pedal" : title,
            detail: "Intensidade \(intensity) · \(formatKm(km))",
            distanceKm: km
        )
        entries.insert(entry, at: 0)
        save()
    }

    func addProblem(title: String, detail: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entries.insert(
            BikeLogEntry(kind: .problem, title: trimmed, detail: detail),
            at: 0
        )
        save()
    }

    func addMaintenance(title: String, detail: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entries.insert(
            BikeLogEntry(kind: .maintenance, title: trimmed, detail: detail),
            at: 0
        )
        save()
    }

    func replacePart(_ part: BikeWearPart, note: String = "") {
        wearByPart[part] = BikeWearState(kmSinceReplace: 0, lastReplacedAt: .now)
        let detail = note.trimmingCharacters(in: .whitespacesAndNewlines)
        entries.insert(
            BikeLogEntry(
                kind: .partReplace,
                title: "Troca: \(part.title)",
                detail: detail.isEmpty ? "Vida útil reiniciada" : detail,
                part: part
            ),
            at: 0
        )
        save()
    }

    func deleteEntry(_ entry: BikeLogEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func wearState(for part: BikeWearPart) -> BikeWearState {
        wearByPart[part] ?? .fresh
    }

    private func formatKm(_ km: Double) -> String {
        if abs(km - km.rounded()) < 0.05 {
            return "\(Int(km.rounded())) km"
        }
        return String(format: "%.1f km", km)
    }

    private func load() {
        lifetimeKm = UserDefaults.standard.double(forKey: totalKmKey)

        if let data = UserDefaults.standard.data(forKey: logKey),
           let decoded = try? JSONDecoder().decode([BikeLogEntry].self, from: data) {
            entries = decoded
        } else {
            entries = []
        }

        if let data = UserDefaults.standard.data(forKey: wearKey),
           let raw = try? JSONDecoder().decode([String: BikeWearState].self, from: data) {
            var map: [BikeWearPart: BikeWearState] = [:]
            for part in BikeWearPart.allCases {
                map[part] = raw[part.rawValue] ?? .fresh
            }
            wearByPart = map
        } else {
            wearByPart = Dictionary(uniqueKeysWithValues: BikeWearPart.allCases.map { ($0, .fresh) })
        }
    }

    private func save() {
        UserDefaults.standard.set(lifetimeKm, forKey: totalKmKey)
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: logKey)
        }
        let raw = Dictionary(uniqueKeysWithValues: wearByPart.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: wearKey)
        }
    }
}
