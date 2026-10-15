import SwiftUI
import UIKit

/// Calendário mensal com foto nos dias em que treinou (estilo GymRats) + dias de descanso.
struct WorkoutPhotoCalendarView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var wellnessService: DailyWellnessService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var visibleMonth: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay: Date?
    @State private var sessionForPhotoPick: WorkoutSession?
    @State private var showPhotoSourceDialog = false
    @State private var showGalleryPicker = false
    @State private var showCameraPicker = false

    private var calendar: Calendar { Calendar.current }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    private var trainedDaysThisMonth: Int {
        Set(completedSessionsInVisibleMonth.map { calendar.startOfDay(for: $0.displayDate) }).count
    }

    private var restDaysThisMonth: Int {
        restDayDatesInVisibleMonth.count
    }

    private var restDayDatesInVisibleMonth: Set<Date> {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth) else { return [] }
        var days = Set<Date>()
        var cursor = interval.start
        while cursor < interval.end {
            if isRestDay(on: cursor) {
                days.insert(calendar.startOfDay(for: cursor))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    private var completedSessionsInVisibleMonth: [WorkoutSession] {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth) else { return [] }
        return workoutStore.sessionHistory.filter { session in
            guard session.endedAt != nil else { return false }
            let day = session.displayDate
            return day >= interval.start && day < interval.end
        }
    }

    private var monthSummaryLine: String {
        var parts: [String] = []
        parts.append("\(trainedDaysThisMonth) dia\(trainedDaysThisMonth == 1 ? "" : "s") treinado\(trainedDaysThisMonth == 1 ? "" : "s")")
        if restDaysThisMonth > 0 {
            parts.append("\(restDaysThisMonth) descanso")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                monthHeader
                weekdayHeader
                monthGrid
                legend
                if let selectedDay {
                    dayDetail(for: selectedDay)
                } else {
                    Text("Toque em um dia com treino ou descanso para ver detalhes.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle("Calendário de treinos")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await wellnessService.ensureRecentHistoryLoaded(limit: 62)
        }
        .confirmationDialog("Foto do treino", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
            if PhotoCaptureAvailability.isCameraAvailable {
                Button("Câmera") {
                    DispatchQueue.main.async { showCameraPicker = true }
                }
            }
            Button("Galeria") {
                DispatchQueue.main.async { showGalleryPicker = true }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("A foto aparece no dia do treino no calendário.")
        }
        .sheet(isPresented: $showGalleryPicker) {
            LibraryImagePicker { image in
                showGalleryPicker = false
                guard let image, let session = sessionForPhotoPick else { return }
                _ = workoutStore.attachCheckInPhoto(sessionId: session.id, image: image)
                sessionForPhotoPick = nil
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showCameraPicker) {
            CameraImagePicker { image in
                showCameraPicker = false
                guard let image, let session = sessionForPhotoPick else { return }
                _ = workoutStore.attachCheckInPhoto(sessionId: session.id, image: image)
                sessionForPhotoPick = nil
            }
            .ignoresSafeArea()
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 4) {
                Text(monthTitle.capitalized)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(monthSummaryLine)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(isCurrentOrFutureMonth)
            .opacity(isCurrentOrFutureMonth ? 0.35 : 1)
        }
    }

    private var isCurrentOrFutureMonth: Bool {
        let now = calendar.startOfDay(for: .now)
        guard let next = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return true }
        return next > now
    }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) ?? visibleMonth
    }

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstWeekday = calendar.firstWeekday
        let ordered = (0..<7).map { symbols[($0 + firstWeekday - 1) % 7] }
        return HStack(spacing: 4) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let cells = monthCells
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(cells) { cell in
                dayCell(cell)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            Label("Com foto", systemImage: "photo.fill")
            Label("Treino", systemImage: "circle.fill")
            Label("Descanso", systemImage: "bed.double.fill")
        }
        .font(.caption2)
        .foregroundStyle(AppTheme.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    @ViewBuilder
    private func dayCell(_ cell: CalendarDayCell) -> some View {
        Group {
            if let date = cell.date {
                let sessions = sessions(on: date)
                let hasWorkout = !sessions.isEmpty
                let isRest = isRestDay(on: date)
                let thumb = thumbnail(for: sessions)
                let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: date) } == true
                let isToday = calendar.isDateInToday(date)
                let isMarked = hasWorkout || isRest

                Button {
                    selectedDay = date
                } label: {
                    let corner = RoundedRectangle(cornerRadius: 10, style: .continuous)
                    ZStack {
                        corner.fill(
                            cellBackground(
                                hasWorkout: hasWorkout,
                                hasPhoto: thumb != nil,
                                isRest: isRest,
                                isSelected: isSelected
                            )
                        )

                        if let thumb {
                            // Overlay evita que scaledToFill expanda o layout e invada o dia vizinho.
                            Color.clear
                                .overlay {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .scaledToFill()
                                }
                                .overlay {
                                    LinearGradient(
                                        colors: [.black.opacity(0.05), .black.opacity(0.55)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                }
                        } else if isRest && !hasWorkout {
                            Image(systemName: "bed.double.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.accentSecondary.opacity(0.95))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .padding(.bottom, 6)
                        } else if hasWorkout {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.85))
                                .frame(width: 7, height: 7)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .padding(.bottom, 6)
                        }

                        if isRest, thumb != nil || hasWorkout {
                            Image(systemName: "bed.double.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(AppTheme.accentSecondary.opacity(0.92), in: Circle())
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .padding(3)
                        }

                        Text("\(calendar.component(.day, from: date))")
                            .font(.caption.weight(isToday || isMarked ? .bold : .medium))
                            .foregroundStyle(
                                dayNumberColor(
                                    hasPhoto: thumb != nil,
                                    hasWorkout: hasWorkout,
                                    isRest: isRest,
                                    isToday: isToday
                                )
                            )
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: thumb != nil ? .bottomLeading : .center
                            )
                            .padding(6)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(corner)
                    .clipped()
                    .contentShape(corner)
                    .overlay {
                        if isSelected {
                            corner.strokeBorder(AppTheme.accent, lineWidth: 2)
                        } else if isToday {
                            corner.strokeBorder(AppTheme.accent.opacity(0.55), lineWidth: 1.5)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    accessibilityLabel(
                        for: date,
                        sessionCount: sessions.count,
                        hasPhoto: thumb != nil,
                        isRest: isRest
                    )
                )
            } else {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    @ViewBuilder
    private func dayDetail(for day: Date) -> some View {
        let sessions = sessions(on: day)
        let isRest = isRestDay(on: day)
        VStack(alignment: .leading, spacing: 12) {
            Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if isRest {
                Label("Dia de descanso", systemImage: "bed.double.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accentSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.accentSecondary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if sessions.isEmpty {
                Text(isRest ? "Nenhum treino — recuperação conta na constância." : "Nenhum treino neste dia.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(sessions) { session in
                    sessionRow(session)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        let photo = WorkoutCheckInPhotoStore.loadThumbnail(fileName: session.checkInPhotoFileName, maxSide: 120)
        return HStack(spacing: 12) {
            Group {
                if let photo {
                    Color.clear
                        .overlay {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                        }
                } else {
                    ZStack {
                        AppTheme.accent.opacity(0.18)
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .frame(width: 56, height: 56)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(session.workoutTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                Text(sessionMeta(session))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Button {
                sessionForPhotoPick = session
                showPhotoSourceDialog = true
            } label: {
                Image(systemName: photo == nil ? "camera.fill" : "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.accent.opacity(0.14))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(photo == nil ? "Adicionar foto" : "Trocar foto")
        }
    }

    // MARK: - Helpers

    private func shiftMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: monthStart) else { return }
        if value > 0 {
            let nowMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
            guard next <= nowMonth else { return }
        }
        visibleMonth = next
        selectedDay = nil
    }

    private var monthCells: [CalendarDayCell] {
        let start = monthStart
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [CalendarDayCell] = (0..<leading).map { CalendarDayCell(id: "pad-\($0)", date: nil) }
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: start) else { continue }
            cells.append(CalendarDayCell(id: "day-\(day)", date: date))
        }
        while cells.count % 7 != 0 {
            cells.append(CalendarDayCell(id: "trail-\(cells.count)", date: nil))
        }
        return cells
    }

    private func sessions(on day: Date) -> [WorkoutSession] {
        workoutStore.sessionHistory
            .filter { $0.endedAt != nil && calendar.isDate($0.displayDate, inSameDayAs: day) }
            .sorted { $0.displayDate > $1.displayDate }
    }

    private func thumbnail(for sessions: [WorkoutSession]) -> UIImage? {
        for session in sessions {
            if let image = WorkoutCheckInPhotoStore.loadThumbnail(fileName: session.checkInPhotoFileName) {
                return image
            }
        }
        return nil
    }

    private func isRestDay(on date: Date) -> Bool {
        wellnessService.isRestDay(on: date)
    }

    private func cellBackground(hasWorkout: Bool, hasPhoto: Bool, isRest: Bool, isSelected: Bool) -> Color {
        if hasPhoto { return .clear }
        if hasWorkout { return AppTheme.accent.opacity(isSelected ? 0.22 : 0.12) }
        if isRest { return AppTheme.accentSecondary.opacity(isSelected ? 0.28 : 0.16) }
        return AppTheme.cardBackground.opacity(0.65)
    }

    private func dayNumberColor(hasPhoto: Bool, hasWorkout: Bool, isRest: Bool, isToday: Bool) -> Color {
        if hasPhoto { return .white }
        if isToday || hasWorkout || isRest { return AppTheme.textPrimary }
        return AppTheme.textSecondary
    }

    private func sessionMeta(_ session: WorkoutSession) -> String {
        let time = session.displayDate.formatted(date: .omitted, time: .shortened)
        let minutes = max(1, Int(session.duration / 60))
        var parts = [time, "\(minutes) min"]
        if session.caloriesBurned > 0 {
            parts.append("\(Int(session.caloriesBurned.rounded())) kcal")
        }
        return parts.joined(separator: " · ")
    }

    private func accessibilityLabel(for date: Date, sessionCount: Int, hasPhoto: Bool, isRest: Bool) -> String {
        let day = date.formatted(.dateTime.day().month(.wide))
        var parts = [day]
        if isRest { parts.append("dia de descanso") }
        if sessionCount > 0 {
            parts.append("\(sessionCount) treino\(sessionCount == 1 ? "" : "s")")
            if hasPhoto { parts.append("com foto") }
        }
        return parts.joined(separator: ", ")
    }
}

private struct CalendarDayCell: Identifiable {
    let id: String
    let date: Date?
}

private extension WorkoutSession {
    var displayDate: Date { endedAt ?? startedAt }
}

/// Atalho compacto para o Dashboard / Perfil.
struct WorkoutPhotoCalendarCard: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var wellnessService: DailyWellnessService

    private var calendar: Calendar { .current }

    private var recentPhotoDays: [(date: Date, image: UIImage)] {
        var seen = Set<Date>()
        var result: [(Date, UIImage)] = []
        for session in workoutStore.sessionHistory where session.endedAt != nil {
            let day = calendar.startOfDay(for: session.endedAt ?? session.startedAt)
            guard seen.insert(day).inserted else { continue }
            guard let image = WorkoutCheckInPhotoStore.loadThumbnail(fileName: session.checkInPhotoFileName) else {
                continue
            }
            result.append((day, image))
            if result.count >= 5 { break }
        }
        return result
    }

    private var trainedDaysThisMonth: Int {
        guard let interval = calendar.dateInterval(of: .month, for: .now) else { return 0 }
        let days = Set(
            workoutStore.sessionHistory.compactMap { session -> Date? in
                guard let end = session.endedAt, end >= interval.start, end < interval.end else { return nil }
                return calendar.startOfDay(for: end)
            }
        )
        return days.count
    }

    private var restDaysThisMonth: Int {
        guard let interval = calendar.dateInterval(of: .month, for: .now) else { return 0 }
        var count = 0
        var cursor = interval.start
        while cursor < interval.end {
            if wellnessService.isRestDay(on: cursor) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return count
    }

    private var summaryLine: String {
        var parts = ["\(trainedDaysThisMonth) dia\(trainedDaysThisMonth == 1 ? "" : "s") este mês"]
        if restDaysThisMonth > 0 {
            parts.append("\(restDaysThisMonth) descanso")
        } else {
            parts.append("fotos e descanso")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationLink {
            WorkoutPhotoCalendarView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Constância", systemImage: "calendar")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Text("Calendário de treinos · \(summaryLine)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                if recentPhotoDays.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: wellnessService.isTodayRestDay ? "bed.double.fill" : "camera.viewfinder")
                            .foregroundStyle(wellnessService.isTodayRestDay ? AppTheme.accentSecondary : AppTheme.accent)
                        Text(
                            wellnessService.isTodayRestDay
                                ? "Hoje é dia de descanso — aparece no calendário de constância."
                                : "Anexe uma foto no resumo do treino ou marque descanso no perfil."
                        )
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                } else {
                    HStack(spacing: 8) {
                        ForEach(Array(recentPhotoDays.enumerated()), id: \.offset) { _, item in
                            Color.clear
                                .frame(width: 52, height: 52)
                                .overlay {
                                    Image(uiImage: item.image)
                                        .resizable()
                                        .scaledToFill()
                                }
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .buttonStyle(.plain)
    }
}
