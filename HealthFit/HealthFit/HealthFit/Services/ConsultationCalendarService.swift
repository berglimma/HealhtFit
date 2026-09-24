import EventKit
import Foundation

/// Consultas no Calendário do iPhone + leitura de horários ocupados (slots livres).
@MainActor
enum ConsultationCalendarService {
    private static let store = EKEventStore()
    private static let mappedKey = "healthfit.calendar.eventIdsByConsultation"

    static var hasExistingAccess: Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized, .writeOnly:
            return true
        default:
            return false
        }
    }

    static var canReadBusyTimes: Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            return true
        default:
            return false
        }
    }

    @discardableResult
    static func requestAccess(promptIfNeeded: Bool) async -> Bool {
        if hasExistingAccess { return true }
        guard promptIfNeeded else { return false }
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .denied || status == .restricted { return false }
        do {
            if #available(iOS 17.0, *) {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await store.requestAccess(to: .event)
            }
        } catch {
            return false
        }
    }

    /// Grava ou atualiza consulta no calendário do aparelho (com alarmes).
    @discardableResult
    static func syncBooking(_ booking: ConsultationBooking, promptIfNeeded: Bool = true) async -> String? {
        guard booking.status == .proposed || booking.status == .confirmed else { return booking.calendarEventId }
        guard await requestAccess(promptIfNeeded: promptIfNeeded) else { return nil }
        guard let calendar = store.defaultCalendarForNewEvents
            ?? store.calendars(for: .event).first(where: \.allowsContentModifications) else {
            return nil
        }

        let existingId = booking.calendarEventId ?? mappedEventId(for: booking.id)
        let event: EKEvent
        if let existingId, let existing = store.event(withIdentifier: existingId) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
            event.calendar = calendar
        }

        event.title = "HealthFit · \(booking.titleLabel)"
        event.startDate = booking.startAt
        event.endDate = max(booking.endAt, booking.startAt.addingTimeInterval(15 * 60))
        event.notes = [
            "Consulta HealthFit Coach (\(booking.profession.title)).",
            "Profissional: \(booking.coachName)",
            "Aluno: \(booking.studentName)",
            booking.note.isEmpty ? nil : "Nota: \(booking.note)",
            "Status: \(booking.status.title)",
            booking.confirmedScheduleLabel
        ].compactMap { $0 }.joined(separator: "\n")
        event.url = URL(string: "healthfit://consultation/\(booking.id)")
        event.alarms = [
            EKAlarm(relativeOffset: -24 * 3600),
            EKAlarm(relativeOffset: -60 * 60),
            EKAlarm(relativeOffset: -15 * 60)
        ]

        do {
            try store.save(event, span: .thisEvent, commit: true)
            if let id = event.eventIdentifier {
                remember(id, for: booking.id)
                return id
            }
        } catch {
            print("[HealthFit] Falha ao salvar consulta no Calendário: \(error.localizedDescription)")
        }
        return nil
    }

    static func removeBookingEvent(bookingId: String, eventId: String?) async {
        let identifier = eventId ?? mappedEventId(for: bookingId)
        guard let identifier else { return }
        guard await requestAccess(promptIfNeeded: false) else { return }
        if let event = store.event(withIdentifier: identifier) {
            do {
                try store.remove(event, span: .thisEvent, commit: true)
            } catch {
                print("[HealthFit] Falha ao remover consulta do Calendário: \(error.localizedDescription)")
            }
        }
        forget(bookingId)
    }

    /// Intervalos ocupados no calendário do aparelho (para modo inteligente).
    static func busyIntervals(from: Date, to: Date) async -> [(start: Date, end: Date)] {
        if !canReadBusyTimes {
            let granted = await requestAccess(promptIfNeeded: true)
            guard granted, canReadBusyTimes else { return [] }
        }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        let events = store.events(matching: predicate)
        return events.map { event in
            (start: event.startDate, end: event.endDate)
        }
    }

    // MARK: - Mapping

    private static func mappedEventId(for bookingId: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: mappedKey) as? [String: String])?[bookingId]
    }

    private static func remember(_ eventId: String, for bookingId: String) {
        var map = (UserDefaults.standard.dictionary(forKey: mappedKey) as? [String: String]) ?? [:]
        map[bookingId] = eventId
        UserDefaults.standard.set(map, forKey: mappedKey)
    }

    private static func forget(_ bookingId: String) {
        var map = (UserDefaults.standard.dictionary(forKey: mappedKey) as? [String: String]) ?? [:]
        map.removeValue(forKey: bookingId)
        UserDefaults.standard.set(map, forKey: mappedKey)
    }
}
