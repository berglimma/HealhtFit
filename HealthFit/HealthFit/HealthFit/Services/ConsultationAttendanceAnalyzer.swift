import Foundation

enum ConsultationAttendanceAnalyzer {
    static func buildReport(
        bookings: [ConsultationBooking],
        days: Int = 30,
        referenceDate: Date = .now
    ) -> ConsultationAttendanceReport {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) ?? end
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: end) ?? end

        let inRange = bookings.filter {
            $0.startAt >= start && $0.startAt < rangeEnd
        }

        var weekdayMap: [Int: Int] = [:]
        var dayMap: [String: (Date, Int)] = [:]
        for item in inRange {
            let wd = calendar.component(.weekday, from: item.startAt)
            weekdayMap[wd, default: 0] += 1
            let key = DailyWellnessEntry.dayKey(for: item.startAt)
            let day = calendar.startOfDay(for: item.startAt)
            let prev = dayMap[key]?.1 ?? 0
            dayMap[key] = (day, prev + 1)
        }

        let symbols = calendar.shortWeekdaySymbols
        let byWeekday = (1...7).map { wd in
            ConsultationAttendanceReport.WeekdayCount(
                weekday: wd,
                label: symbols[wd - 1],
                count: weekdayMap[wd] ?? 0
            )
        }

        let byDay = dayMap.keys.sorted().compactMap { key -> ConsultationAttendanceReport.DayCount? in
            guard let pair = dayMap[key] else { return nil }
            return .init(dayKey: key, date: pair.0, count: pair.1)
        }

        return ConsultationAttendanceReport(
            periodStart: start,
            periodEnd: referenceDate,
            totalBookings: inRange.count,
            confirmed: inRange.filter { $0.status == .confirmed }.count,
            completed: inRange.filter { $0.status == .completed }.count,
            cancelled: inRange.filter { $0.status == .cancelled || $0.status == .declined }.count,
            proposed: inRange.filter { $0.status == .proposed }.count,
            byWeekday: byWeekday,
            byDay: byDay,
            recent: inRange.sorted { $0.startAt > $1.startAt }
        )
    }
}
