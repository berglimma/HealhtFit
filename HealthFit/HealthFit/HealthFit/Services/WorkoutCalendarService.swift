import CoreLocation
import EventKit
import Foundation

/// Escreve treinos concluídos no Calendário do iPhone (EventKit).
@MainActor
enum WorkoutCalendarService {
    private static let store = EKEventStore()
    private static let mappedEventsKey = "healthfit.calendar.eventIdsBySession"

    /// Registra a sessão no calendário padrão (idempotente por `session.id`).
    static func registerCompletedSession(_ session: WorkoutSession) {
        Task {
            await registerIfNeeded(session)
        }
    }

    /// Garante que as sessões de hoje já finalizadas apareçam no Calendário.
    static func syncTodaysCompletedSessions(_ sessions: [WorkoutSession]) {
        Task {
            let calendar = Calendar.current
            for session in sessions where session.endedAt != nil {
                guard let end = session.endedAt, calendar.isDateInToday(end) else { continue }
                await registerIfNeeded(session)
            }
        }
    }

    // MARK: - Private

    private static func registerIfNeeded(_ session: WorkoutSession) async {
        guard session.endedAt != nil else { return }
        let sessionKey = session.id.uuidString
        if mappedEventIdentifier(for: sessionKey) != nil { return }

        guard await requestAccess() else { return }
        guard let calendar = store.defaultCalendarForNewEvents ?? store.calendars(for: .event).first(where: \.allowsContentModifications) else {
            print("[HealthFit] Nenhum calendário disponível para gravar treinos.")
            return
        }

        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = "HealthFit · \(session.workoutTitle)"
        event.startDate = session.startedAt
        var end = session.endedAt ?? session.startedAt.addingTimeInterval(max(session.duration, 60))
        if end <= event.startDate {
            end = event.startDate.addingTimeInterval(max(session.duration, 60))
        }
        event.endDate = end
        event.notes = makeNotes(for: session)
        event.url = URL(string: "healthfit://workout/\(session.id.uuidString)")

        if let spot = session.waterSport?.spot {
            let name = spot.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                event.location = name
            }
            if let coordinate = spot.coordinate {
                let structured = EKStructuredLocation(title: name.isEmpty ? "SPOT" : name)
                structured.geoLocation = CLLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                event.structuredLocation = structured
                if event.location == nil || event.location?.isEmpty == true {
                    event.location = String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
                }
            }
        }

        do {
            try store.save(event, span: .thisEvent, commit: true)
            if let identifier = event.eventIdentifier {
                rememberMappedEvent(identifier, for: sessionKey)
            }
        } catch {
            print("[HealthFit] Falha ao salvar treino no Calendário: \(error.localizedDescription)")
        }
    }

    private static func requestAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined, .writeOnly:
            break
        @unknown default:
            break
        }

        do {
            if #available(iOS 17.0, *) {
                // Prefere escrita completa para criar o evento no calendário do usuário.
                return try await store.requestFullAccessToEvents()
            } else {
                return try await store.requestAccess(to: .event)
            }
        } catch {
            print("[HealthFit] Permissão de calendário negada: \(error.localizedDescription)")
            return false
        }
    }

    private static func makeNotes(for session: WorkoutSession) -> String {
        var lines: [String] = [
            "Registrado pelo HealthFit.",
            "Duração: \(formatDuration(session.duration))"
        ]

        let distance = session.displayDistanceKm
        if distance > 0.01 {
            lines.append(String(format: "Distância: %.2f km", distance))
        }
        if session.caloriesBurned > 0 {
            lines.append("Calorias: \(Int(session.caloriesBurned.rounded())) kcal")
        }
        if let water = session.waterSport {
            if water.isKitesurf {
                lines.append("Modalidade: Kitesurf")
                if let eq = water.kiteEquipmentRaw { lines.append("Equipamento: \(eq)") }
                if let mode = water.ridingModeRaw { lines.append("Modo: \(mode)") }
            } else {
                lines.append("Modalidade: Surf")
            }
            if let board = water.boardTypeRaw { lines.append("Prancha: \(board)") }
            if water.jumpCount > 0 {
                lines.append("Saltos: \(water.jumpCount)")
            }
            if water.maxJumpHeightMeters > 0 {
                lines.append(String(format: "Maior salto: %.1f m", water.maxJumpHeightMeters))
            }
        }
        if session.endedEarly {
            lines.append("Encerrado antecipadamente.")
        }
        return lines.joined(separator: "\n")
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%dh %02dmin", h, m) }
        if m > 0 { return String(format: "%dmin %02ds", m, s) }
        return "\(s)s"
    }

    private static func mappedEventIdentifier(for sessionKey: String) -> String? {
        let map = UserDefaults.standard.dictionary(forKey: mappedEventsKey) as? [String: String]
        return map?[sessionKey]
    }

    private static func rememberMappedEvent(_ eventId: String, for sessionKey: String) {
        var map = (UserDefaults.standard.dictionary(forKey: mappedEventsKey) as? [String: String]) ?? [:]
        map[sessionKey] = eventId
        // Evita crescimento infinito de IDs antigos.
        if map.count > 200 {
            let keys = map.keys.sorted()
            for key in keys.prefix(map.count - 200) {
                map.removeValue(forKey: key)
            }
        }
        UserDefaults.standard.set(map, forKey: mappedEventsKey)
    }
}
