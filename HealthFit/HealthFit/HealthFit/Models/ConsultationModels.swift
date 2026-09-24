import Foundation

/// Como o usuário escolhe o horário da consulta.
enum ConsultationBookingMode: String, CaseIterable, Codable, Identifiable, Hashable {
    case smart
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: return "Inteligente"
        case .manual: return "Escolher horário"
        }
    }

    var detail: String {
        switch self {
        case .smart:
            return "Sugere horários livres da agenda do profissional e do calendário do celular."
        case .manual:
            return "Você escolhe data e hora livremente."
        }
    }
}

enum ConsultationStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case proposed
    case confirmed
    case declined
    case cancelled
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .proposed: return "Proposta"
        case .confirmed: return "Confirmada"
        case .declined: return "Recusada"
        case .cancelled: return "Cancelada"
        case .completed: return "Concluída"
        }
    }
}

/// Janela horária em minutos desde meia-noite (ex.: 9h = 540).
struct ConsultationTimeRange: Codable, Equatable, Hashable, Identifiable {
    var id: String { "\(startMinutes)-\(endMinutes)" }
    var startMinutes: Int
    var endMinutes: Int

    var label: String {
        "\(Self.format(startMinutes)) – \(Self.format(endMinutes))"
    }

    static func format(_ minutes: Int) -> String {
        let h = max(0, minutes) / 60
        let m = max(0, minutes) % 60
        return String(format: "%02d:%02d", h, m)
    }
}

/// Agenda semanal do profissional (personal ou nutricionista).
struct CoachAvailability: Codable, Equatable, Hashable {
    var coachUid: String
    /// 1 = domingo … 7 = sábado (Calendar.component .weekday).
    var weekdayRanges: [String: [ConsultationTimeRange]]
    var slotDurationMinutes: Int
    var timezoneIdentifier: String
    /// Modos permitidos para o aluno agendar.
    var allowedModes: [ConsultationBookingMode]
    var syncToDeviceCalendar: Bool
    var updatedAt: Date

    static let defaultDuration = 45

    static func empty(coachUid: String) -> CoachAvailability {
        CoachAvailability(
            coachUid: coachUid,
            weekdayRanges: Self.defaultWeekdayRanges,
            slotDurationMinutes: defaultDuration,
            timezoneIdentifier: TimeZone.current.identifier,
            allowedModes: [.smart, .manual],
            syncToDeviceCalendar: true,
            updatedAt: .now
        )
    }

    /// Seg–sex 9h–12h e 14h–18h.
    static var defaultWeekdayRanges: [String: [ConsultationTimeRange]] {
        let morning = ConsultationTimeRange(startMinutes: 9 * 60, endMinutes: 12 * 60)
        let afternoon = ConsultationTimeRange(startMinutes: 14 * 60, endMinutes: 18 * 60)
        var map: [String: [ConsultationTimeRange]] = [:]
        for weekday in 2...6 {
            map[String(weekday)] = [morning, afternoon]
        }
        return map
    }

    func ranges(forWeekday weekday: Int) -> [ConsultationTimeRange] {
        weekdayRanges[String(weekday)] ?? []
    }

    mutating func setRanges(_ ranges: [ConsultationTimeRange], forWeekday weekday: Int) {
        weekdayRanges[String(weekday)] = ranges
        updatedAt = .now
    }

    var allowsSmart: Bool { allowedModes.contains(.smart) }
    var allowsManual: Bool { allowedModes.contains(.manual) }
}

struct ConsultationBooking: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var linkId: String
    var coachUid: String
    var studentUid: String
    var coachName: String
    var studentName: String
    var professionRaw: String
    var startAt: Date
    var endAt: Date
    var statusRaw: String
    var modeRaw: String
    var note: String
    var createdByUid: String
    var calendarEventId: String?
    var createdAt: Date
    var updatedAt: Date

    var profession: CoachProfession {
        get { CoachProfession(rawValue: professionRaw) ?? .personal }
        set { professionRaw = newValue.rawValue }
    }

    var status: ConsultationStatus {
        get { ConsultationStatus(rawValue: statusRaw) ?? .proposed }
        set { statusRaw = newValue.rawValue }
    }

    var mode: ConsultationBookingMode {
        get { ConsultationBookingMode(rawValue: modeRaw) ?? .manual }
        set { modeRaw = newValue.rawValue }
    }

    var isUpcoming: Bool {
        (status == .proposed || status == .confirmed) && endAt > .now
    }

    /// Ex.: "Consulta confirmada — 25/09 às 14:30"
    var confirmedScheduleLabel: String {
        "Consulta confirmada — \(Self.dayMonthFormatter.string(from: startAt)) às \(Self.timeFormatter.string(from: startAt))"
    }

    var shortScheduleLabel: String {
        "\(Self.dayMonthFormatter.string(from: startAt)) às \(Self.timeFormatter.string(from: startAt))"
    }

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "HH:mm"
        return f
    }()

    var titleLabel: String {
        switch profession {
        case .personal: return "Consulta com personal"
        case .nutritionist: return "Consulta com nutricionista"
        }
    }

    static func make(
        link: CoachLink,
        startAt: Date,
        durationMinutes: Int,
        mode: ConsultationBookingMode,
        note: String,
        createdByUid: String,
        status: ConsultationStatus = .proposed
    ) -> ConsultationBooking {
        let end = startAt.addingTimeInterval(TimeInterval(max(durationMinutes, 15) * 60))
        let now = Date()
        return ConsultationBooking(
            id: UUID().uuidString,
            linkId: link.id,
            coachUid: link.coachUid,
            studentUid: link.studentUid,
            coachName: link.coachName,
            studentName: link.studentName,
            professionRaw: link.profession.rawValue,
            startAt: startAt,
            endAt: end,
            statusRaw: status.rawValue,
            modeRaw: mode.rawValue,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            createdByUid: createdByUid,
            calendarEventId: nil,
            createdAt: now,
            updatedAt: now
        )
    }
}

struct ConsultationOpenSlot: Identifiable, Hashable {
    var id: Date { startAt }
    var startAt: Date
    var endAt: Date
    var source: String

    var label: String {
        let day = Self.dayFormatter.string(from: startAt)
        let time = Self.timeFormatter.string(from: startAt)
        return "\(day) · \(time)"
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "HH:mm"
        return f
    }()
}

enum ConsultationSlotEngine {
    /// Gera horários abertos a partir da disponibilidade, excluindo já agendados e (opcional) ocupados no calendário.
    static func openSlots(
        availability: CoachAvailability,
        existing: [ConsultationBooking],
        busyIntervals: [(start: Date, end: Date)],
        from: Date = .now,
        daysAhead: Int = 14,
        limit: Int = 24
    ) -> [ConsultationOpenSlot] {
        var calendar = Calendar.current
        if let tz = TimeZone(identifier: availability.timezoneIdentifier) {
            calendar.timeZone = tz
        }
        let duration = max(availability.slotDurationMinutes, 15)
        let durationSec = TimeInterval(duration * 60)
        let startDay = calendar.startOfDay(for: from)
        var results: [ConsultationOpenSlot] = []

        let activeBookings = existing.filter {
            $0.status == .proposed || $0.status == .confirmed
        }

        for dayOffset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startDay) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let ranges = availability.ranges(forWeekday: weekday)
            for range in ranges {
                var cursor = range.startMinutes
                while cursor + duration <= range.endMinutes {
                    guard let slotStart = calendar.date(bySettingHour: cursor / 60, minute: cursor % 60, second: 0, of: day) else {
                        cursor += duration
                        continue
                    }
                    let slotEnd = slotStart.addingTimeInterval(durationSec)
                    cursor += duration
                    if slotStart < from.addingTimeInterval(30 * 60) { continue }

                    let overlapsBooking = activeBookings.contains {
                        slotStart < $0.endAt && slotEnd > $0.startAt
                    }
                    if overlapsBooking { continue }

                    let overlapsBusy = busyIntervals.contains {
                        slotStart < $0.end && slotEnd > $0.start
                    }
                    if overlapsBusy { continue }

                    results.append(
                        ConsultationOpenSlot(
                            startAt: slotStart,
                            endAt: slotEnd,
                            source: "agenda"
                        )
                    )
                    if results.count >= limit { return results }
                }
            }
        }
        return results
    }
}
