import SwiftUI
import Combine

// MARK: - Professional availability editor

struct CoachAvailabilityEditorView: View {
    @ObservedObject private var coach = CoachService.shared
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var draft = CoachAvailability.empty(coachUid: "")
    @State private var isSaving = false
    @State private var statusMessage: String?
    @State private var allowSmart = true
    @State private var allowManual = true

    private let weekdays: [(Int, String)] = [
        (2, "Segunda"), (3, "Terça"), (4, "Quarta"),
        (5, "Quinta"), (6, "Sexta"), (7, "Sábado"), (1, "Domingo")
    ]

    var body: some View {
        Form {
            Section {
                Text("Defina quando você atende. Alunos e o IAssistente usam isso para sugerir horários livres.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Duração da consulta") {
                Stepper("\(draft.slotDurationMinutes) min", value: $draft.slotDurationMinutes, in: 20...120, step: 5)
            }

            Section("Modo de agendamento") {
                Toggle("Inteligente (horários livres)", isOn: $allowSmart)
                Toggle("Escolher horário manualmente", isOn: $allowManual)
                Toggle("Sincronizar com Calendário do iPhone", isOn: $draft.syncToDeviceCalendar)
            }

            Section("Horários por dia") {
                ForEach(weekdays, id: \.0) { weekday, title in
                    weekdayRow(weekday: weekday, title: title)
                }
            }

            if let statusMessage {
                Section { Text(statusMessage).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Minha agenda")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "…" : "Salvar") {
                    Task { await save() }
                }
                .disabled(isSaving || (!allowSmart && !allowManual))
            }
        }
        .onAppear {
            guard let uid = authService.currentUser?.id else { return }
            draft = coach.availability(for: uid)
            draft.coachUid = uid
            allowSmart = draft.allowsSmart
            allowManual = draft.allowsManual
        }
    }

    private func weekdayRow(weekday: Int, title: String) -> some View {
        let ranges = draft.ranges(forWeekday: weekday)
        let isOn = !ranges.isEmpty
        return Toggle(isOn: Binding(
            get: { isOn },
            set: { enabled in
                if enabled {
                    draft.setRanges([
                        ConsultationTimeRange(startMinutes: 9 * 60, endMinutes: 12 * 60),
                        ConsultationTimeRange(startMinutes: 14 * 60, endMinutes: 18 * 60)
                    ], forWeekday: weekday)
                } else {
                    draft.setRanges([], forWeekday: weekday)
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if isOn {
                    Text(ranges.map(\.label).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Folga").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func save() async {
        guard let uid = authService.currentUser?.id else { return }
        isSaving = true
        defer { isSaving = false }
        draft.coachUid = uid
        var modes: [ConsultationBookingMode] = []
        if allowSmart { modes.append(.smart) }
        if allowManual { modes.append(.manual) }
        draft.allowedModes = modes.isEmpty ? [.manual] : modes
        draft.timezoneIdentifier = TimeZone.current.identifier
        let ok = await coach.saveAvailability(draft)
        if ok {
            _ = await ConsultationCalendarService.requestAccess(promptIfNeeded: draft.syncToDeviceCalendar)
            statusMessage = "Agenda salva."
            dismiss()
        } else {
            statusMessage = coach.lastError ?? "Não foi possível salvar."
        }
    }
}

// MARK: - HealthFit Calendar chrome

private enum HFCalTheme {
    static let accent = AppTheme.accent
    static let accentSecondary = AppTheme.accentSecondary
    static let eventGreen = AppTheme.accent
    static let eventGreenDark = AppTheme.accent.opacity(0.55)
    static let selection = AppTheme.accentSecondary
    static let gridLine = Color.white.opacity(0.12)
    static let muted = AppTheme.textSecondary
    static let hourHeight: CGFloat = 56
    static let dayStartHour = 7
    static let dayEndHour = 20
    static var totalHours: CGFloat { CGFloat(dayEndHour - dayStartHour) }
    static var dayGridHeight: CGFloat { hourHeight * totalHours }
}

// MARK: - Schedule consultation (estilo Calendário do iPhone)

struct CoachScheduleConsultationView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case year = "Ano"
        case month = "Mês"
        case week = "Semana"
        case day = "Dia"
        var id: String { rawValue }
    }

    let link: CoachLink
    /// Quando true (painel profissional), usa a barra de navegação do container.
    var isEmbedded: Bool = false

    @ObservedObject private var coach = CoachService.shared
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var scope: Scope = .month
    @State private var focusedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var visibleYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedStart: Date?
    @State private var note = ""
    @State private var busyIntervals: [(start: Date, end: Date)] = []
    @State private var isSaving = false
    @State private var statusMessage: String?
    @State private var confirmationBanner: String?
    @State private var bookingToReschedule: ConsultationBooking?
    @State private var bookingPendingCancel: ConsultationBooking?
    @State private var nowTicker = Date()

    private var calendar: Calendar { Calendar.current }

    private var availability: CoachAvailability {
        coach.availability(for: link.coachUid)
    }

    private var durationMinutes: Int {
        max(availability.slotDurationMinutes, 15)
    }

    private var bookings: [ConsultationBooking] {
        (coach.consultationsByLink[link.id] ?? []).filter {
            $0.status == .proposed || $0.status == .confirmed
        }
    }

    private var upcoming: [ConsultationBooking] {
        bookings.filter(\.isUpcoming).sorted { $0.startAt < $1.startAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            calendarChrome

            Group {
                switch scope {
                case .year:
                    yearView
                case .month:
                    monthView
                case .week:
                    weekView
                case .day:
                    dayView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let confirmationBanner {
                Text(confirmationBanner)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(HFCalTheme.eventGreen.opacity(0.35))
                    .overlay(alignment: .leading) {
                        Rectangle().fill(HFCalTheme.eventGreen).frame(width: 4)
                    }
            }

            if bookingToReschedule != nil {
                Text("Toque num horário livre para remarcar · \(bookingToReschedule!.shortScheduleLabel)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HFCalTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }

            upcomingManageSection
            bottomBar
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(isEmbedded ? "" : "Agendar consulta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isEmbedded {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "…" : (bookingToReschedule == nil ? "Agendar" : "Remarcar")) {
                    Task { await schedule() }
                }
                .disabled(isSaving || selectedStart == nil)
                .fontWeight(.semibold)
                .tint(AppTheme.accent)
            }
        }
        .alert("Excluir agendamento?", isPresented: Binding(
            get: { bookingPendingCancel != nil },
            set: { if !$0 { bookingPendingCancel = nil } }
        )) {
            Button("Excluir", role: .destructive) {
                guard let booking = bookingPendingCancel else { return }
                Task {
                    let ok = await coach.cancelConsultation(booking)
                    if ok {
                        confirmationBanner = nil
                        statusMessage = "Consulta de \(booking.shortScheduleLabel) cancelada. O outro lado foi notificado."
                        if bookingToReschedule?.id == booking.id {
                            bookingToReschedule = nil
                        }
                    } else {
                        statusMessage = coach.lastError ?? "Não foi possível cancelar."
                    }
                    bookingPendingCancel = nil
                }
            }
            Button("Manter", role: .cancel) {
                bookingPendingCancel = nil
            }
        } message: {
            if let booking = bookingPendingCancel {
                Text("A consulta de \(booking.shortScheduleLabel) será cancelada e \(authService.currentUser?.id == booking.studentUid ? "o profissional" : "o aluno") será notificado.")
            }
        }
        .task {
            await refreshBusy()
        }
        .onChange(of: focusedDay) { _, _ in
            Task { await refreshBusy() }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            nowTicker = date
        }
    }

    // MARK: - Chrome

    private var calendarChrome: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle)
                        .font(scope == .day ? .title2.bold() : .title.bold())
                        .foregroundStyle(.white)
                    if scope == .day {
                        Text(weekdayLong(focusedDay))
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer(minLength: 8)
                HStack(spacing: 10) {
                    Button { step(-1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(HFCalTheme.accent)
                    }
                    Button("Hoje") { goToday() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(HFCalTheme.accent)
                    Button { step(1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(HFCalTheme.accent)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Picker("Escopo", selection: $scope) {
                ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            Text("Duração: \(durationMinutes) min · toque num horário livre (07:00–20:00)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
        }
        .background(AppTheme.background)
    }

    private var headerTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        switch scope {
        case .year:
            return "\(visibleYear)"
        case .month:
            f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
            return f.string(from: focusedDay).lowercased()
        case .week:
            f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
            return f.string(from: focusedDay).lowercased()
        case .day:
            f.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
            return f.string(from: focusedDay).lowercased()
        }
    }

    private var upcomingManageSection: some View {
        Group {
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Agendamentos")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HFCalTheme.muted)
                    ForEach(upcoming.prefix(5)) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.confirmedScheduleLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Lembretes automáticos: 24h, 1h e 15 min antes")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Button("Remarcar") {
                                    bookingToReschedule = item
                                    selectedStart = nil
                                    focusedDay = calendar.startOfDay(for: item.startAt)
                                    scope = .day
                                    statusMessage = "Escolha o novo horário no calendário."
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(HFCalTheme.eventGreen)

                                Button("Excluir", role: .destructive) {
                                    bookingPendingCancel = item
                                }
                                .font(.caption.weight(.semibold))
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selectedStart {
                HStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(HFCalTheme.eventGreen)
                        .frame(width: 4, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nova consulta")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(selectedStart.formatted(date: .abbreviated, time: .shortened)
                             + " · \(durationMinutes) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Limpar") { self.selectedStart = nil }
                        .font(.caption)
                        .foregroundStyle(HFCalTheme.accent)
                }
            }

            TextField("Observação (opcional)", text: $note, axis: .vertical)
                .lineLimit(1...3)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !upcoming.isEmpty, scope == .year || scope == .month {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(upcoming.prefix(6)) { item in
                            Text(item.startAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(HFCalTheme.eventGreenDark)
                                .clipShape(Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
    }

    // MARK: - Year (foto 1)

    private var yearView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 18) {
                ForEach(1...12, id: \.self) { month in
                    yearMonthCell(month: month)
                }
            }
            .padding(12)
        }
    }

    private func yearMonthCell(month: Int) -> some View {
        let monthDate = date(year: visibleYear, month: month, day: 1)
        return VStack(alignment: .leading, spacing: 4) {
            Text(monthName(month).lowercased())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HFCalTheme.accent)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 1) {
                ForEach(shortWeekdayLetters, id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(HFCalTheme.muted)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(daysInMonthGrid(for: monthDate).enumerated()), id: \.offset) { _, day in
                    if let day {
                        let inMonth = calendar.isDate(day, equalTo: monthDate, toGranularity: .month)
                        let isToday = calendar.isDateInToday(day)
                        Button {
                            focusedDay = calendar.startOfDay(for: day)
                            scope = .day
                        } label: {
                            Text("\(calendar.component(.day, from: day))")
                                .font(.system(size: 9, weight: isToday ? .bold : .regular))
                                .foregroundStyle(inMonth ? (isToday ? .white : .white.opacity(0.9)) : HFCalTheme.muted.opacity(0.5))
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(isToday ? HFCalTheme.accent : Color.clear))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(width: 16, height: 16)
                    }
                }
            }
        }
    }

    // MARK: - Month (foto 2)

    private var monthView: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(weekdayHeadersShort, id: \.self) { title in
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(HFCalTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 4)

            GeometryReader { geo in
                let rows = max(monthGridDays.filter { $0 != nil || true }.count / 7, 5)
                let cellH = max((geo.size.height - 8) / CGFloat(max(rows, 5)), 72)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(Array(monthGridDays.enumerated()), id: \.offset) { _, day in
                        if let day {
                            monthDayCell(day, height: cellH)
                        } else {
                            Color.clear.frame(height: cellH)
                                .overlay(Rectangle().stroke(HFCalTheme.gridLine, lineWidth: 0.5))
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
    }

    private func monthDayCell(_ day: Date, height: CGFloat) -> some View {
        let inMonth = calendar.isDate(day, equalTo: focusedDay, toGranularity: .month)
        let isToday = calendar.isDateInToday(day)
        let isSelected = calendar.isDate(day, inSameDayAs: focusedDay)
        let dayBookings = bookings.filter { calendar.isDate($0.startAt, inSameDayAs: day) }
        let hasDraft = selectedStart.map { calendar.isDate($0, inSameDayAs: day) } ?? false

        return Button {
            focusedDay = calendar.startOfDay(for: day)
            scope = .day
        } label: {
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(isToday || isSelected ? .bold : .regular))
                    .foregroundStyle(inMonth ? .white : HFCalTheme.muted)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(isToday ? HFCalTheme.accent : Color.clear))
                    .frame(maxWidth: .infinity, alignment: .trailing)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(dayBookings.prefix(2)) { item in
                        HStack(spacing: 3) {
                            Capsule().fill(HFCalTheme.eventGreenDark).frame(width: 2, height: 10)
                            Text(shortEventTitle(item))
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                    if hasDraft {
                        Text("Nova consulta")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(HFCalTheme.eventGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    if dayBookings.count > 2 {
                        Text("e mais \(dayBookings.count - 2)")
                            .font(.system(size: 8))
                            .foregroundStyle(HFCalTheme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(4)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .top)
            .overlay(Rectangle().stroke(HFCalTheme.gridLine, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Week (foto 3)

    private var weekView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 44)
                ForEach(weekDays, id: \.self) { day in
                    let isToday = calendar.isDateInToday(day)
                    VStack(spacing: 4) {
                        Text(weekdayTiny(day))
                            .font(.caption2)
                            .foregroundStyle(isToday ? HFCalTheme.accent : HFCalTheme.muted)
                        Text("\(calendar.component(.day, from: day))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isToday ? .white : .white.opacity(0.9))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(isToday ? HFCalTheme.accent : Color.clear))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedDay = day
                        scope = .day
                    }
                }
            }
            .padding(.vertical, 6)

            Text("dia inteiro")
                .font(.caption2)
                .foregroundStyle(HFCalTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 44)
                .padding(.bottom, 4)

            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    timeGutter
                    ForEach(weekDays, id: \.self) { day in
                        dayColumn(day: day, showNowLine: calendar.isDateInToday(day))
                            .overlay(Rectangle().stroke(HFCalTheme.gridLine, lineWidth: 0.5))
                    }
                }
                .frame(height: HFCalTheme.dayGridHeight)
            }
        }
    }

    // MARK: - Day (foto 4)

    private var dayView: some View {
        VStack(spacing: 0) {
            Text("dia inteiro")
                .font(.caption2)
                .foregroundStyle(HFCalTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 52)
                .padding(.vertical, 6)
            Divider().overlay(HFCalTheme.gridLine)

            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    timeGutter
                    dayColumn(day: focusedDay, showNowLine: calendar.isDateInToday(focusedDay), wide: true)
                }
                .frame(height: HFCalTheme.dayGridHeight)
            }
        }
    }

    private var timeGutter: some View {
        VStack(spacing: 0) {
            ForEach(HFCalTheme.dayStartHour..<HFCalTheme.dayEndHour, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundStyle(HFCalTheme.muted)
                    .frame(width: 44, height: HFCalTheme.hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 4)
                    .offset(y: -6)
            }
        }
    }

    private func dayColumn(day: Date, showNowLine: Bool, wide: Bool = false) -> some View {
        let dayBookings = bookings.filter { calendar.isDate($0.startAt, inSameDayAs: day) }
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(HFCalTheme.dayStartHour..<HFCalTheme.dayEndHour, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: HFCalTheme.hourHeight)
                        .overlay(alignment: .top) {
                            Rectangle().fill(HFCalTheme.gridLine).frame(height: 0.5)
                        }
                        .contentShape(Rectangle())
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        selectSlot(atY: value.location.y, on: day)
                    }
            )

            ForEach(dayBookings) { item in
                eventBlock(
                    start: item.startAt,
                    end: item.endAt,
                    title: shortEventTitle(item),
                    color: HFCalTheme.eventGreenDark,
                    wide: wide
                )
            }

            if let selectedStart,
               calendar.isDate(selectedStart, inSameDayAs: day) {
                let end = selectedStart.addingTimeInterval(TimeInterval(durationMinutes * 60))
                eventBlock(
                    start: selectedStart,
                    end: end,
                    title: "Nova consulta",
                    color: HFCalTheme.eventGreen,
                    wide: wide
                )
            }

            if showNowLine {
                nowLineOverlay
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: HFCalTheme.dayGridHeight)
    }

    private func eventBlock(start: Date, end: Date, title: String, color: Color, wide: Bool) -> some View {
        let top = yOffset(for: start)
        let bottom = yOffset(for: end)
        let height = max(bottom - top, 22)
        return HStack(spacing: 0) {
            Rectangle().fill(color.opacity(0.95)).frame(width: 3)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 5).fill(color.opacity(0.85)))
        .padding(.horizontal, wide ? 6 : 2)
        .offset(y: top)
    }

    @ViewBuilder
    private var nowLineOverlay: some View {
        let y = yOffset(for: nowTicker)
        if y >= 0, y <= HFCalTheme.dayGridHeight {
            HStack(spacing: 0) {
                Text(timeLabel(nowTicker))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(HFCalTheme.accent))
                    .offset(x: -40)
                Circle().fill(HFCalTheme.accent).frame(width: 8, height: 8)
                Rectangle().fill(HFCalTheme.accent).frame(height: 2)
            }
            .offset(y: y - 4)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Actions / helpers

    private func selectSlot(atY y: CGFloat, on day: Date) {
        let minutesFromStart = Int((y / HFCalTheme.hourHeight) * 60)
        let absolute = HFCalTheme.dayStartHour * 60 + minutesFromStart
        let stepped = (absolute / durationMinutes) * durationMinutes
        let clamped = min(max(stepped, HFCalTheme.dayStartHour * 60), HFCalTheme.dayEndHour * 60 - durationMinutes)
        let hour = clamped / 60
        let minute = clamped % 60
        guard let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: calendar.startOfDay(for: day)) else { return }
        let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        if end <= Date() { return }
        let overlapsBooking = bookings.contains { start < $0.endAt && end > $0.startAt }
        let overlapsBusy = busyIntervals.contains { start < $0.end && end > $0.start }
        guard !overlapsBooking, !overlapsBusy else { return }
        selectedStart = start
        focusedDay = calendar.startOfDay(for: day)
        if bookingToReschedule != nil {
            Task { await schedule() }
        }
    }

    private func yOffset(for date: Date) -> CGFloat {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let fromStart = CGFloat(minutes - HFCalTheme.dayStartHour * 60)
        return (fromStart / 60) * HFCalTheme.hourHeight
    }

    private func goToday() {
        focusedDay = calendar.startOfDay(for: Date())
        visibleYear = calendar.component(.year, from: focusedDay)
        if scope == .year { scope = .month }
    }

    private func step(_ delta: Int) {
        switch scope {
        case .year:
            visibleYear += delta
        case .month:
            if let d = calendar.date(byAdding: .month, value: delta, to: focusedDay) {
                focusedDay = calendar.startOfDay(for: d)
                visibleYear = calendar.component(.year, from: focusedDay)
            }
        case .week:
            if let d = calendar.date(byAdding: .weekOfYear, value: delta, to: focusedDay) {
                focusedDay = calendar.startOfDay(for: d)
            }
        case .day:
            if let d = calendar.date(byAdding: .day, value: delta, to: focusedDay) {
                focusedDay = calendar.startOfDay(for: d)
            }
        }
    }

    private func refreshBusy() async {
        let start = calendar.date(byAdding: .day, value: -1, to: focusedDay) ?? focusedDay
        let end = calendar.date(byAdding: .day, value: 8, to: focusedDay) ?? focusedDay
        busyIntervals = await ConsultationCalendarService.busyIntervals(from: start, to: end)
    }

    private func schedule() async {
        guard let selectedStart else { return }
        isSaving = true
        defer { isSaving = false }
        if let bookingToReschedule {
            if let updated = await coach.rescheduleConsultation(bookingToReschedule, newStartAt: selectedStart) {
                confirmationBanner = updated.confirmedScheduleLabel
                statusMessage = "Remarcada com lembretes automáticos. O outro lado foi notificado."
                self.bookingToReschedule = nil
                self.selectedStart = nil
            } else {
                statusMessage = coach.lastError ?? "Não foi possível remarcar."
            }
            return
        }
        if let booking = await coach.scheduleConsultation(
            link: link,
            startAt: selectedStart,
            mode: .manual,
            note: note
        ) {
            confirmationBanner = booking.confirmedScheduleLabel
            statusMessage = "Lembretes automáticos ativos (24h, 1h e 15 min antes)."
            self.selectedStart = nil
            note = ""
        } else {
            statusMessage = coach.lastError ?? "Não foi possível agendar."
        }
    }

    private var weekDays: [Date] {
        let start = startOfWeek(focusedDay)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var monthGridDays: [Date?] {
        daysInMonthGrid(for: focusedDay)
    }

    private func daysInMonthGrid(for reference: Date) -> [Date?] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: reference)) ?? reference
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        var cells: [Date?] = []
        if leading > 0, let prev = calendar.date(byAdding: .day, value: -leading, to: monthStart) {
            for i in 0..<leading {
                cells.append(calendar.date(byAdding: .day, value: i, to: prev))
            }
        } else {
            cells.append(contentsOf: Array(repeating: nil, count: leading))
        }
        for day in 1...daysInMonth {
            var comps = calendar.dateComponents([.year, .month], from: monthStart)
            comps.day = day
            cells.append(calendar.date(from: comps))
        }
        while cells.count % 7 != 0 {
            guard let last = cells.compactMap({ $0 }).last,
                  let next = calendar.date(byAdding: .day, value: 1, to: last) else {
                cells.append(nil)
                continue
            }
            cells.append(next)
        }
        return cells
    }

    private func startOfWeek(_ date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let delta = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -delta, to: day) ?? day
    }

    private var shortWeekdayLetters: [String] {
        // D S T Q Q S S — alinhado ao firstWeekday do calendário
        let base = ["D", "S", "T", "Q", "Q", "S", "S"]
        // Calendar: 1=Dom …; Portuguese Sunday-first matches Apple BR often
        let first = calendar.firstWeekday // 1 Sunday typically in pt_BR/US
        if first == 1 { return base }
        // Rotate if Monday-first
        return Array(base[(first - 1)...]) + Array(base[..<(first - 1)])
    }

    private var weekdayHeadersShort: [String] {
        let symbols = calendar.shortWeekdaySymbols.map { String($0.prefix(3)).lowercased() + "." }
        let first = calendar.firstWeekday - 1
        return (0..<7).map { symbols[($0 + first) % 7] }
    }

    private func monthName(_ month: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        return f.monthSymbols[month - 1]
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        return calendar.date(from: c) ?? Date()
    }

    private func weekdayLong(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.setLocalizedDateFormatFromTemplate("EEEE")
        return f.string(from: day).lowercased()
    }

    private func weekdayTiny(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f.string(from: day).lowercased() + "."
    }

    private func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func shortEventTitle(_ item: ConsultationBooking) -> String {
        let name = item.studentName.isEmpty ? "Consulta" : item.studentName
        return "HealthFit · \(name)"
    }
}

// MARK: - Agenda profissional (= mesma UI do aluno + horários)

struct CoachProfessionalAgendaView: View {
    @ObservedObject private var coach = CoachService.shared
    @EnvironmentObject private var authService: AuthService

    @State private var selectedLinkId: String?
    @State private var showAvailability = false

    private var myStudentLinks: [CoachLink] {
        let uid = authService.currentUser?.id ?? ""
        return coach.myLinks
            .filter { $0.coachUid == uid && $0.isActiveLike }
            .sorted { $0.studentName.localizedCaseInsensitiveCompare($1.studentName) == .orderedAscending }
    }

    private var selectedLink: CoachLink? {
        if let selectedLinkId,
           let match = myStudentLinks.first(where: { $0.id == selectedLinkId }) {
            return match
        }
        return myStudentLinks.first
    }

    private var allUpcoming: [ConsultationBooking] {
        myStudentLinks
            .flatMap { coach.consultationsByLink[$0.id] ?? [] }
            .filter(\.isUpcoming)
            .sorted { $0.startAt < $1.startAt }
    }

    var body: some View {
        Group {
            if myStudentLinks.isEmpty {
                ContentUnavailableView(
                    "Nenhum aluno vinculado",
                    systemImage: "calendar.badge.plus",
                    description: Text("Vincule um aluno para agendar consultas. Os horários ficam sincronizados com o calendário do aluno.")
                )
            } else if let link = selectedLink {
                VStack(spacing: 0) {
                    studentPicker
                    syncedBanner
                    CoachScheduleConsultationView(link: link, isEmbedded: true)
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Agenda de consultas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAvailability = true
                } label: {
                    Label("Horários", systemImage: "clock")
                }
                .tint(AppTheme.accent)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CoachConsultationAttendanceReportView()
                } label: {
                    Image(systemName: "chart.bar.doc.horizontal")
                }
                .tint(AppTheme.accent)
            }
        }
        .sheet(isPresented: $showAvailability) {
            NavigationStack {
                CoachAvailabilityEditorView()
            }
        }
        .onAppear {
            if selectedLinkId == nil {
                selectedLinkId = myStudentLinks.first?.id
            }
        }
        .onChange(of: myStudentLinks.map(\.id)) { _, ids in
            if let selectedLinkId, ids.contains(selectedLinkId) { return }
            selectedLinkId = ids.first
        }
    }

    private var studentPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aluno / paciente")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Picker("Aluno", selection: Binding(
                get: { selectedLinkId ?? myStudentLinks.first?.id ?? "" },
                set: { selectedLinkId = $0 }
            )) {
                ForEach(myStudentLinks) { link in
                    Text("\(link.studentName) · \(link.profession.title)")
                        .tag(link.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.accent)

            if !allUpcoming.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allUpcoming.prefix(8)) { item in
                            Button {
                                selectedLinkId = item.linkId
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.studentName)
                                        .font(.caption2.weight(.semibold))
                                    Text(item.shortScheduleLabel)
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.accent.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(AppTheme.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
    }

    private var syncedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(AppTheme.accent)
            Text("Mesmo calendário do aluno · sincronizado em tempo real")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(AppTheme.accent.opacity(0.08))
    }
}
