import Foundation

/// Como o usuário escolhe o horário da consulta.
enum ConsultationBookingMode: String, CaseIterable, Codable, Identifiable, Hashable {
    case smart
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: return "Assistente de agendamento"
        case .manual: return "Calendário"
        }
    }

    var detail: String {
        switch self {
        case .smart:
            return "Verifica a agenda do personal/nutri e sugere os melhores horários livres."
        case .manual:
            return "Você escolhe data e hora no calendário."
        }
    }

    var shortBadge: String {
        switch self {
        case .smart: return "Assistente"
        case .manual: return "Manual"
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
    static let defaultAllowedModes: [ConsultationBookingMode] = [.smart, .manual]

    static func empty(coachUid: String) -> CoachAvailability {
        CoachAvailability(
            coachUid: coachUid,
            weekdayRanges: Self.defaultWeekdayRanges,
            slotDurationMinutes: defaultDuration,
            timezoneIdentifier: TimeZone.current.identifier,
            allowedModes: defaultAllowedModes,
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

    init(
        coachUid: String,
        weekdayRanges: [String: [ConsultationTimeRange]],
        slotDurationMinutes: Int,
        timezoneIdentifier: String,
        allowedModes: [ConsultationBookingMode],
        syncToDeviceCalendar: Bool,
        updatedAt: Date
    ) {
        self.coachUid = coachUid
        self.weekdayRanges = weekdayRanges
        self.slotDurationMinutes = slotDurationMinutes
        self.timezoneIdentifier = timezoneIdentifier
        self.allowedModes = allowedModes.isEmpty ? Self.defaultAllowedModes : allowedModes
        self.syncToDeviceCalendar = syncToDeviceCalendar
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coachUid = try container.decode(String.self, forKey: .coachUid)
        weekdayRanges = try container.decodeIfPresent([String: [ConsultationTimeRange]].self, forKey: .weekdayRanges) ?? [:]
        slotDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .slotDurationMinutes) ?? Self.defaultDuration
        timezoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timezoneIdentifier) ?? TimeZone.current.identifier
        let modes = try container.decodeIfPresent([ConsultationBookingMode].self, forKey: .allowedModes) ?? []
        allowedModes = modes.isEmpty ? Self.defaultAllowedModes : modes
        syncToDeviceCalendar = try container.decodeIfPresent(Bool.self, forKey: .syncToDeviceCalendar) ?? true
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
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

/// Horário ranqueado pelo Assistente de agendamento (aluno).
struct ConsultationSuggestedSlot: Identifiable, Hashable {
    var id: Date { startAt }
    var startAt: Date
    var endAt: Date
    var score: Double
    var reasons: [String]

    var label: String {
        let day = Self.dayFormatter.string(from: startAt)
        let time = Self.timeFormatter.string(from: startAt)
        return "\(day) · \(time)"
    }

    var openSlot: ConsultationOpenSlot {
        ConsultationOpenSlot(startAt: startAt, endAt: endAt, source: "assistente")
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

/// Ranqueia horários livres da agenda do profissional (e conflitos do calendário).
enum ConsultationSchedulingAssistant {
    /// Sugere os melhores horários a partir dos slots abertos e da carga da agenda.
    static func suggest(
        openSlots: [ConsultationOpenSlot],
        existing: [ConsultationBooking],
        from: Date = .now,
        limit: Int = 8
    ) -> [ConsultationSuggestedSlot] {
        guard !openSlots.isEmpty else { return [] }
        let calendar = Calendar.current
        let active = existing.filter { $0.status == .proposed || $0.status == .confirmed }
        let scored = openSlots.map { slot -> ConsultationSuggestedSlot in
            score(slot: slot, existing: active, from: from, calendar: calendar)
        }
        // Diversifica: no máximo 2 sugestões por dia, priorizando score.
        var perDay: [Date: Int] = [:]
        var picked: [ConsultationSuggestedSlot] = []
        for item in scored.sorted(by: { $0.score > $1.score }) {
            let day = calendar.startOfDay(for: item.startAt)
            let count = perDay[day, default: 0]
            if count >= 2 { continue }
            perDay[day] = count + 1
            picked.append(item)
            if picked.count >= limit { break }
        }
        return picked
    }

    private static func score(
        slot: ConsultationOpenSlot,
        existing: [ConsultationBooking],
        from: Date,
        calendar: Calendar
    ) -> ConsultationSuggestedSlot {
        var score: Double = 50
        var reasons: [String] = []

        let hoursAhead = slot.startAt.timeIntervalSince(from) / 3600
        switch hoursAhead {
        case ..<4:
            score -= 15
            reasons.append("Muito em cima da hora")
        case 4..<24:
            score += 12
            reasons.append("Ainda hoje / amanhã cedo")
        case 24..<72:
            score += 28
            reasons.append("Bom prazo (1–3 dias)")
        case 72..<168:
            score += 18
            reasons.append("Esta semana")
        default:
            score += 6
            reasons.append("Mais à frente")
        }

        let hour = calendar.component(.hour, from: slot.startAt)
        let minute = calendar.component(.minute, from: slot.startAt)
        let minutes = hour * 60 + minute
        switch minutes {
        case (9 * 60)..<(11 * 60), (14 * 60)..<(16 * 60):
            score += 22
            reasons.append("Horário comercial ideal")
        case (11 * 60)..<(12 * 60), (16 * 60)..<(18 * 60):
            score += 10
            reasons.append("Bom horário do dia")
        case (12 * 60)..<(14 * 60):
            score -= 8
            reasons.append("Horário de almoço — menos preferível")
        default:
            break
        }

        let weekday = calendar.component(.weekday, from: slot.startAt)
        if (2...6).contains(weekday) {
            score += 12
            reasons.append("Dia útil")
        } else {
            score -= 4
            reasons.append("Fim de semana")
        }

        let dayStart = calendar.startOfDay(for: slot.startAt)
        let sameDayCount = existing.filter {
            calendar.isDate($0.startAt, inSameDayAs: dayStart)
        }.count
        if sameDayCount == 0 {
            score += 14
            reasons.append("Agenda do profissional folgada nesse dia")
        } else if sameDayCount == 1 {
            score += 4
            reasons.append("Poucas consultas nesse dia")
        } else {
            score -= Double(sameDayCount) * 3
            reasons.append("Dia já movimentado (\(sameDayCount) consultas)")
        }

        let nearestGap = existing
            .map { abs($0.startAt.timeIntervalSince(slot.startAt)) }
            .min()
        if let nearestGap {
            if nearestGap >= 90 * 60 {
                score += 10
                reasons.append("Espaço confortável entre consultas")
            } else if nearestGap < 45 * 60 {
                score -= 6
            }
        } else {
            score += 8
            reasons.append("Sem conflito com outras consultas")
        }

        // Mantém no máximo 3 motivos legíveis, priorizando os mais positivos.
        let trimmed = Array(reasons.prefix(3))
        return ConsultationSuggestedSlot(
            startAt: slot.startAt,
            endAt: slot.endAt,
            score: score,
            reasons: trimmed
        )
    }
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
