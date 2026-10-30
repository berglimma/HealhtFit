import AVFoundation
import AVKit
import CoreImage
import SwiftUI
import UIKit

/// Calendário mensal com foto nos dias em que treinou (estilo GymRats) + dias de descanso.
struct WorkoutPhotoCalendarView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var wellnessService: DailyWellnessService
    @EnvironmentObject private var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var visibleMonth: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay: Date?
    @State private var sessionForPhotoPick: WorkoutSession?
    @State private var showPhotoSourceDialog = false
    @State private var showGalleryPicker = false
    @State private var showCameraPicker = false
    @State private var isMakingRetrospective = false
    @State private var retrospectiveURL: URL?
    @State private var retrospectiveTitle = ""
    @State private var showRetrospectiveActions = false
    @State private var showRetrospectiveShare = false
    @State private var retrospectiveNote: String?

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
                    Text("Toque em um dia passado para ver o treino ou marcar descanso.")
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
        .sheet(isPresented: $showRetrospectiveActions) {
            if let retrospectiveURL {
                RetrospectivePlayerSheet(
                    url: retrospectiveURL,
                    monthTitle: retrospectiveTitle,
                    onGallery: { await saveRetrospectiveToGallery() },
                    onInstagram: { await shareRetrospectiveToInstagram() },
                    onPulse: { await publishRetrospectiveToPulse() },
                    onClose: { showRetrospectiveActions = false }
                )
            }
        }
        .sheet(isPresented: $showRetrospectiveShare) {
            if let retrospectiveURL {
                ActivityShareSheet(items: [retrospectiveURL]) {
                    showRetrospectiveShare = false
                }
            }
        }
        .alert("Retrospectiva", isPresented: Binding(
            get: { retrospectiveNote != nil },
            set: { if !$0 { retrospectiveNote = nil } }
        )) {
            Button("OK", role: .cancel) { retrospectiveNote = nil }
        } message: {
            Text(retrospectiveNote ?? "")
        }
    }

    private var monthHeader: some View {
        VStack(spacing: 0) {
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
        Button {
            Task { await makeRetrospective() }
        } label: {
            HStack(spacing: 4) {
                if isMakingRetrospective {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "film")
                }
                Text(verbatim: "Gerar Retrospectiva Mensal")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppTheme.accent.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isMakingRetrospective)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .accessibilityLabel("Gerar Retrospectiva Mensal")
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

            if canMarkRest(on: day) {
                Button {
                    wellnessService.setRestDay(on: day, rest: !isRest)
                } label: {
                    Label(
                        isRest ? "Remover descanso" : "Marcar como descanso",
                        systemImage: "bed.double.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
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

    private var retrospectiveMonthStart: Date {
        let current = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        if monthStart <= current { return monthStart }
        return MonthlyRetrospectiveVideo.finishedMonthStart()
    }

    private var athleteName: String {
        authService.currentUser?.greetingName
            ?? authService.currentUser?.name
            ?? "Atleta"
    }

    private func makeRetrospective() async {
        guard !isMakingRetrospective else { return }
        isMakingRetrospective = true
        defer { isMakingRetrospective = false }
        let start = retrospectiveMonthStart
        guard let end = calendar.date(byAdding: .month, value: 1, to: start) else { return }
        var restKeys: [String] = []
        var cursor = start
        while cursor < end {
            if wellnessService.isRestDay(on: cursor) {
                restKeys.append(DailyWellnessEntry.dayKey(for: cursor))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        guard let result = await MonthlyRetrospectiveVideo.make(
            sessions: workoutStore.sessionHistory,
            restDayKeys: restKeys,
            monthStart: start
        ) else {
            retrospectiveNote = "Não foi possível montar o vídeo."
            return
        }
        retrospectiveURL = result.url
        retrospectiveTitle = result.monthTitle
        showRetrospectiveActions = true
    }

    private func saveRetrospectiveToGallery() async -> String {
        guard let retrospectiveURL else { return "Não foi salvo na galeria." }
        do {
            try await PhotoLibrarySaver.saveVideo(at: retrospectiveURL)
            return "Salvo na galeria."
        } catch {
            return "Não foi salvo na galeria."
        }
    }

    private func shareRetrospectiveToInstagram() async -> String {
        guard let retrospectiveURL else { return "Não foi publicado no Instagram Stories." }
        guard let scheme = URL(string: "instagram-stories://share"),
              UIApplication.shared.canOpenURL(scheme) else {
            return "Não foi publicado no Instagram Stories."
        }
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: retrospectiveURL.path)[.size] as? NSNumber)?.intValue ?? 0
        guard fileSize > 0 else {
            return "Não foi publicado no Instagram Stories."
        }
        do {
            let data = try Data(contentsOf: retrospectiveURL, options: [.mappedIfSafe])
            let appID = Bundle.main.bundleIdentifier ?? "luan.com.healthfit.app"
            UIPasteboard.general.setItems(
                [[
                    "com.instagram.sharedSticker.backgroundVideo": data,
                    "com.instagram.sharedSticker.appID": appID,
                ]],
                options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
            )
            var components = URLComponents(string: "instagram-stories://share")
            components?.queryItems = [URLQueryItem(name: "source_application", value: appID)]
            guard let openURL = components?.url else {
                return "Não foi publicado no Instagram Stories."
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
            let opened = await UIApplication.shared.open(openURL)
            return opened ? "Publicado no Instagram Stories." : "Não foi publicado no Instagram Stories."
        } catch {
            return "Não foi publicado no Instagram Stories."
        }
    }

    private func publishRetrospectiveToPulse() async -> String {
        guard let retrospectiveURL else { return "O vídeo não está disponível." }
        let month = MonthlyRetrospectiveVideo.monthTitle(retrospectiveMonthStart)
        do {
            _ = try await PulseLocalStore.shared.addVideoPost(
                authorId: authService.currentUser?.id ?? "local",
                authorName: athleteName,
                authorCountryCode: authService.currentUser?.countryCode ?? "BR",
                caption: "Retrospectiva HealthFit de \(month). Superação para o próximo mês.",
                sourceURL: retrospectiveURL,
                community: .musculacao,
                workoutMeta: PulseWorkoutMeta(
                    modality: "Retrospectiva",
                    durationSeconds: nil,
                    intensity: nil,
                    duoTeamName: nil
                ),
                authorAvatar: authService.profileImage,
                maxDuration: 75.5
            )
            return "Publicado no Pulse."
        } catch {
            return "Não foi publicado no Pulse."
        }
    }

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

    private func canMarkRest(on date: Date) -> Bool {
        calendar.startOfDay(for: date) <= calendar.startOfDay(for: .now)
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

    private var recentPhotos: [UIImage] {
        var seen = Set<String>()
        var result: [UIImage] = []
        for session in workoutStore.sessionHistory {
            guard let name = session.checkInPhotoFileName, seen.insert(name).inserted else { continue }
            guard let image = WorkoutCheckInPhotoStore.loadThumbnail(fileName: name, maxSide: 320) else { continue }
            result.append(image)
            if result.count >= 5 { break }
        }
        return result
    }

    private var footerLine: String {
        if wellnessService.isTodayRestDay { return "Descanso hoje" }
        if recentPhotos.isEmpty { return "Anexe fotos" }
        return "\(recentPhotos.count) com foto"
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
        }         label: {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    CoverAssetImage(name: "ConstancyCover")
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                    LinearGradient(
                        colors: [Color.black.opacity(0.08), Color.black.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .semibold))
                            Text(verbatim: "CALENDÁRIO")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(AppTheme.accent)
                        Text(verbatim: "Constância")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, 6)
                        Text(verbatim: "Calendário de treinos · \(summaryLine)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                        Text(verbatim: footerLine)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 8)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()

                if !recentPhotos.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(recentPhotos.enumerated()), id: \.offset) { _, photo in
                            Color.clear
                                .frame(width: 52, height: 52)
                                .overlay {
                                    Image(uiImage: photo)
                                        .resizable()
                                        .scaledToFill()
                                }
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct RetrospectivePlayerSheet: View {
    let url: URL
    let monthTitle: String
    var onGallery: () async -> String
    var onInstagram: () async -> String
    var onPulse: () async -> String
    var onClose: () -> Void

    @State private var player: AVPlayer?
    @State private var showShare = false
    @State private var status = "Toque em uma ação para confirmar."
    @State private var busy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                VStack(spacing: 12) {
                    Text(monthTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                    Text(status)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    actionButton("Salvar na galeria") { await onGallery() }
                    actionButton("Publicar no Pulse") { await onPulse() }
                    actionButton("WhatsApp") {
                        guard let scheme = URL(string: "whatsapp://"),
                              UIApplication.shared.canOpenURL(scheme) else {
                            return "Não foi publicado no WhatsApp."
                        }
                        showShare = true
                        return "Escolha o WhatsApp para publicar."
                    }
                    actionButton("Instagram Stories") { await onInstagram() }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.027, green: 0.063, blue: 0.094))
            }
            .background(Color.black)
            .navigationTitle("Retrospectiva")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", action: onClose)
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            let av = AVPlayer(url: url)
            player = av
            av.play()
        }
        .onDisappear { player?.pause() }
        .sheet(isPresented: $showShare) {
            ActivityShareSheet(items: [url], onFinish: { completed in
                showShare = false
                status = completed ? "Publicado no WhatsApp." : "Não foi publicado no WhatsApp."
            })
        }
    }

    private func actionButton(_ title: String, action: @escaping () async -> String) -> some View {
        Button(title) {
            guard !busy else { return }
            busy = true
            status = "Aguarde…"
            Task {
                status = await action()
                busy = false
            }
        }
        .buttonStyle(PrimaryButtonStyle(isEnabled: !busy))
        .disabled(busy)
    }
}

/// Vídeo da retrospectiva do mês já encerrado.
/// Usa só as fotos locais do calendário Constância. Não grava nada no Firebase.
/// Duração máxima: 75 segundos.
enum MonthlyRetrospectiveVideo {
    static let maxSeconds = 75
    private static let fps: Int32 = 10
    private static let width = 720
    private static let height = 1280

    struct Result {
        let url: URL
        let monthTitle: String
        let nextMonthTitle: String
        let workoutCount: Int
        let photoCount: Int
    }

    private struct Slide: Sendable {
        enum Kind: String, Sendable {
            case intro
            case photo
            case rest
            case phrase
            case outro
        }

        var kind: Kind
        var phrase: String
        var caption: String
        var detail: String
        var photoPath: String?
        var frames: Int
    }

    private static let phrases = [
        "Cada treino contou.",
        "Você apareceu. Isso muda tudo.",
        "Constância é o seu diferencial.",
        "O corpo lembra o que você repetiu.",
        "Um dia de cada vez, o mês inteiro.",
        "Disciplina virou resultado.",
        "Você não pulou o dia difícil.",
        "A evolução está nessas fotos.",
        "Orgulho do caminho, não só da chegada.",
        "Força se constrói quando ninguém vê.",
        "Sua presença foi o treino mais importante.",
        "O mês ficou marcado na Constância.",
    ]

    private static let restCovers = [
        "MeditacaoCoverRecuperacao",
        "MeditacaoCoverRelaxamento",
        "MeditacaoCoverSono",
        "MeditacaoCoverRespiracao",
    ]

    private static let restPhrases = [
        "Descansar também é treinar.",
        "O corpo cresce no descanso.",
        "Recuperação faz parte da constância.",
        "Você respeitou o limite.",
        "Superação inclui saber parar.",
        "O próximo treino agradece essa pausa.",
    ]

    static func finishedMonthStart(now: Date = .now, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: now)
        let startOfThisMonth = calendar.date(from: parts) ?? now
        return calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? startOfThisMonth
    }

    static func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "MMMM 'de' yyyy"
        let raw = formatter.string(from: date)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    static func make(
        sessions: [WorkoutSession],
        restDayKeys: [String] = [],
        monthStart requestedMonth: Date? = nil,
        now: Date = .now
    ) async -> Result? {
        let calendar = Calendar.current
        let monthStart: Date
        if let requestedMonth {
            let parts = calendar.dateComponents([.year, .month], from: requestedMonth)
            monthStart = calendar.date(from: parts) ?? requestedMonth
        } else {
            monthStart = finishedMonthStart(now: now, calendar: calendar)
        }
        let nextStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
        let monthSessions = sessions
            .filter { session in
                guard session.endedAt != nil else { return false }
                let date = session.displayDate
                return date >= monthStart && date < monthEnd
            }
            .sorted { $0.displayDate < $1.displayDate }
        let photos = photosFromCalendarDays(
            sessions: sessions,
            monthStart: monthStart,
            monthEnd: monthEnd,
            calendar: calendar
        )
        let monthLabel = monthTitle(monthStart)
        let nextLabel = monthTitle(nextStart)
        let monthPrefix = monthTitleStamp(monthStart)
        let photoDays = Set(photos.map(\.dayKey))
        let rests = restDayKeys
            .filter { $0.hasPrefix(monthPrefix) && !photoDays.contains($0) }
            .sorted()
        let slides = storyboard(
            monthTitle: monthLabel,
            nextTitle: nextLabel,
            workoutCount: monthSessions.count,
            photos: photos,
            restDayKeys: rests
        )
        let totalFrames = slides.reduce(0) { $0 + $1.frames }
        guard totalFrames <= maxSeconds * Int(fps) else { return nil }
        let workoutCount = monthSessions.count
        let photoCount = photos.count
        return await Task.detached(priority: .userInitiated) {
            guard let url = write(slides: slides, monthStart: monthStart) else { return nil }
            return Result(
                url: url,
                monthTitle: monthLabel,
                nextMonthTitle: nextLabel,
                workoutCount: workoutCount,
                photoCount: photoCount
            )
        }.value
    }

    private static func storyboard(
        monthTitle: String,
        nextTitle: String,
        workoutCount: Int,
        photos: [(path: String, title: String, day: String, dayKey: String)],
        restDayKeys: [String]
    ) -> [Slide] {
        let introFrames = 4 * Int(fps)
        let outroFrames = 6 * Int(fps)
        let budget = maxSeconds * Int(fps) - introFrames - outroFrames
        let restLine = restDayKeys.isEmpty
            ? "Nenhum dia de descanso"
            : count(restDayKeys.count, one: "dia de descanso", many: "dias de descanso")
        let photoLine = photos.isEmpty
            ? "Sem fotos neste mês"
            : count(photos.count, one: "foto na Constância", many: "fotos na Constância")
        var slides: [Slide] = [
            Slide(
                kind: .intro,
                phrase: monthTitle,
                caption: count(workoutCount, one: "treino", many: "treinos"),
                detail: "\(photoLine)\n\(restLine)",
                photoPath: nil,
                frames: introFrames
            ),
        ]
        let moments: [(sort: String, slide: Slide)] = photos.map { photo in
            (photo.dayKey, Slide(kind: .photo, phrase: "", caption: photo.title, detail: photo.day, photoPath: photo.path, frames: 0))
        } + restDayKeys.map { key in
            (key, Slide(kind: .rest, phrase: "", caption: dayTitle(fromDayKey: key), detail: "", photoPath: nil, frames: 0))
        }
        let ordered = moments.sorted { $0.sort < $1.sort }.map(\.slide)
        if ordered.isEmpty {
            let phraseFrames = min(4 * Int(fps), budget / 4)
            for (index, phrase) in phrases.prefix(4).enumerated() {
                slides.append(
                    Slide(
                        kind: .phrase,
                        phrase: phrase,
                        caption: "Constância  ·  \(index + 1)",
                        detail: "",
                        photoPath: nil,
                        frames: phraseFrames
                    )
                )
            }
        } else {
            let minFrames = Int(fps)
            let room = max(budget / minFrames, 1)
            let photosOnly = ordered.filter { $0.kind == .photo }
            let restsOnly = ordered.filter { $0.kind == .rest }
            let chosen: [Slide]
            if ordered.count <= room {
                chosen = ordered
            } else if photosOnly.count >= room {
                chosen = sample(photosOnly, limit: room)
            } else {
                chosen = photosOnly + sample(restsOnly, limit: room - photosOnly.count)
            }
            let per = max(budget / max(chosen.count, 1), 1)
            for (index, moment) in chosen.enumerated() {
                var slide = moment
                slide.frames = per
                if slide.kind == .rest {
                    slide.phrase = restPhrases[index % restPhrases.count]
                    slide.photoPath = restCovers[index % restCovers.count]
                } else {
                    slide.phrase = phrases[index % phrases.count]
                }
                slides.append(slide)
            }
        }
        slides.append(
            Slide(
                kind: .outro,
                phrase: "SUPERAÇÃO",
                caption: "para \(nextTitle)",
                detail: "Vá além do que você fez em \(monthTitle).",
                photoPath: nil,
                frames: outroFrames
            )
        )
        return slides
    }

    private static func write(slides: [Slide], monthStart: Date) -> URL? {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = folder.appendingPathComponent("retrospective", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyy-MM"
        let url = dir.appendingPathComponent("HealthFit-Retrospectiva-\(stamp.string(from: monthStart)).mp4")
        try? FileManager.default.removeItem(at: url)

        let heart = UIImage(named: "BrandHeart")
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_500_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)

        var kept: [CVPixelBuffer] = []
        var frameIndex: Int64 = 0
        for slide in slides {
            let image = render(slide, heart: heart)
            guard let buffer = pixelBuffer(from: image) else { return nil }
            kept.append(buffer)
            for _ in 0..<slide.frames {
                var spins = 0
                while !input.isReadyForMoreMediaData {
                    if spins > 500 { return nil }
                    Thread.sleep(forTimeInterval: 0.01)
                    spins += 1
                }
                let time = CMTime(value: frameIndex, timescale: fps)
                if !adaptor.append(buffer, withPresentationTime: time) {
                    return nil
                }
                frameIndex += 1
            }
        }
        input.markAsFinished()
        writer.finishWriting { }
        var waits = 0
        while writer.status == .writing && waits < 400 {
            Thread.sleep(forTimeInterval: 0.05)
            waits += 1
        }
        _ = kept.count
        guard writer.status == .completed, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private static func render(_ slide: Slide, heart: UIImage?) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { context in
            let canvas = context.cgContext
            switch slide.kind {
            case .photo:
                if let photo = loadCalendarPhoto(path: slide.photoPath) {
                    drawCover(photo, in: CGRect(x: 0, y: 0, width: width, height: height))
                } else {
                    UIColor(red: 0.027, green: 0.063, blue: 0.094, alpha: 1).setFill()
                    canvas.fill(CGRect(x: 0, y: 0, width: width, height: height))
                }
                drawVerticalFade(canvas, from: 0.42)
                drawTopFade(canvas)
                drawMark(heart, x: 48, y: 56, size: 72)
                _ = drawText(slide.detail, y: 980, font: .systemFont(ofSize: 22, weight: .medium), color: muted)
                _ = drawText(slide.caption, y: 1020, font: .systemFont(ofSize: 36, weight: .bold), color: .white)
                _ = drawText(slide.phrase, y: 1110, font: .systemFont(ofSize: 40, weight: .bold), color: .white)
            case .intro:
                fillBackground(canvas)
                drawHeart(heart, top: 390, size: 220)
                var y: CGFloat = 640
                y = drawText("HEALTHFIT", y: y, font: .systemFont(ofSize: 34, weight: .bold), color: accent) + 28
                y = drawText("RETROSPECTIVA", y: y, font: .systemFont(ofSize: 54, weight: .bold), color: .white) + 18
                y = drawText(slide.phrase, y: y, font: .systemFont(ofSize: 32, weight: .semibold), color: .white) + 36
                y = drawText(slide.caption, y: y, font: .systemFont(ofSize: 28, weight: .medium), color: muted) + 12
                _ = drawText(slide.detail, y: y, font: .systemFont(ofSize: 26, weight: .semibold), color: accent)
            case .rest:
                if let name = slide.photoPath, let photo = UIImage(named: name) {
                    drawCover(photo, in: CGRect(x: 0, y: 0, width: width, height: height))
                } else {
                    fillBackground(canvas)
                }
                drawVerticalFade(canvas, from: 0.28)
                drawTopFade(canvas)
                drawHeart(heart, top: 280, size: 180)
                var y: CGFloat = 500
                y = drawText("HEALTHFIT", y: y, font: .systemFont(ofSize: 28, weight: .bold), color: accent) + 20
                y = drawText("DIA DE DESCANSO", y: y, font: .systemFont(ofSize: 44, weight: .bold), color: .white) + 12
                y = drawText(slide.caption, y: y, font: .systemFont(ofSize: 28, weight: .semibold), color: .white) + 28
                _ = drawText(slide.phrase, y: y, font: .systemFont(ofSize: 34, weight: .bold), color: .white)
            case .phrase:
                fillBackground(canvas)
                drawHeart(heart, top: 430, size: 180)
                _ = drawText("HEALTHFIT", y: 660, font: .systemFont(ofSize: 28, weight: .bold), color: accent)
                _ = drawText(slide.phrase, y: 760, font: .systemFont(ofSize: 48, weight: .bold), color: .white)
                _ = drawText(slide.caption, y: 1040, font: .systemFont(ofSize: 24, weight: .medium), color: muted)
            case .outro:
                fillBackground(canvas)
                drawHeart(heart, top: 340, size: 240)
                var y: CGFloat = 620
                y = drawText("HEALTHFIT", y: y, font: .systemFont(ofSize: 36, weight: .bold), color: accent) + 36
                y = drawText(slide.phrase, y: y, font: .systemFont(ofSize: 58, weight: .bold), color: .white) + 16
                y = drawText(slide.caption, y: y, font: .systemFont(ofSize: 32, weight: .semibold), color: .white) + 48
                _ = drawText(slide.detail, y: y, font: .systemFont(ofSize: 28, weight: .medium), color: muted)
            }
        }
    }

    private static func fillBackground(_ canvas: CGContext) {
        UIColor(red: 0.027, green: 0.063, blue: 0.094, alpha: 1).setFill()
        canvas.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }

    private static func drawHeart(_ heart: UIImage?, top: CGFloat, size: CGFloat) {
        let rect = CGRect(x: (CGFloat(width) - size) / 2, y: top, width: size, height: size)
        if let heart {
            heart.draw(in: rect)
        } else {
            accent.setFill()
            UIBezierPath(ovalIn: rect).fill()
        }
    }

    private static func drawMark(_ heart: UIImage?, x: CGFloat, y: CGFloat, size: CGFloat) {
        heart?.draw(in: CGRect(x: x, y: y, width: size, height: size))
        let text = NSAttributedString(
            string: "HEALTHFIT",
            attributes: [
                .font: UIFont.systemFont(ofSize: 26, weight: .bold),
                .foregroundColor: UIColor.white,
            ]
        )
        text.draw(at: CGPoint(x: x + size + 16, y: y + size * 0.28))
    }

    private static func drawCover(_ image: UIImage, in rect: CGRect) {
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let dest = CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        image.draw(in: dest)
    }

    private static func drawVerticalFade(_ canvas: CGContext, from start: CGFloat) {
        let colors = [
            UIColor.clear.cgColor,
            UIColor(red: 0.027, green: 0.063, blue: 0.094, alpha: 0.94).cgColor,
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        canvas.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: CGFloat(height) * start),
            end: CGPoint(x: 0, y: CGFloat(height)),
            options: []
        )
    }

    private static func drawTopFade(_ canvas: CGContext) {
        let colors = [
            UIColor(red: 0.027, green: 0.063, blue: 0.094, alpha: 0.8).cgColor,
            UIColor.clear.cgColor,
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        canvas.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: 280),
            options: []
        )
    }

    @discardableResult
    private static func drawText(_ text: String, y: CGFloat, font: UIFont, color: UIColor) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: style,
            ]
        )
        let bounds = attributed.boundingRect(
            with: CGSize(width: CGFloat(width) - 96, height: 800),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let rect = CGRect(x: 48, y: y, width: CGFloat(width) - 96, height: ceil(bounds.height) + 4)
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return y + rect.height
    }

    private static func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        ]
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else { return nil }
        guard var ciImage = CIImage(image: image) else { return nil }
        let extent = ciImage.extent.integral
        if extent.width > 0, extent.height > 0,
           abs(extent.width - CGFloat(width)) > 0.5 || abs(extent.height - CGFloat(height)) > 0.5 {
            ciImage = ciImage.transformed(by: CGAffineTransform(
                scaleX: CGFloat(width) / extent.width,
                y: CGFloat(height) / extent.height
            ))
        }
        let ciContext = CIContext(options: [
            .workingColorSpace: NSNull(),
            .cacheIntermediates: false,
        ])
        ciContext.render(
            ciImage,
            to: buffer,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return buffer
    }

    private static var accent: UIColor { UIColor(red: 0.239, green: 0.863, blue: 0.227, alpha: 1) }
    private static var muted: UIColor { UIColor(red: 0.718, green: 0.753, blue: 0.784, alpha: 1) }

    /// Uma foto por arquivo, na ordem dos dias do calendário — a mesma imagem da célula.
    private static func photosFromCalendarDays(
        sessions: [WorkoutSession],
        monthStart: Date,
        monthEnd: Date,
        calendar: Calendar
    ) -> [(path: String, title: String, day: String, dayKey: String)] {
        var photos: [(path: String, title: String, day: String, dayKey: String)] = []
        var seen = Set<String>()
        var cursor = monthStart
        while cursor < monthEnd {
            let daySessions = sessions
                .filter { $0.endedAt != nil && calendar.isDate($0.displayDate, inSameDayAs: cursor) }
                .sorted { $0.displayDate < $1.displayDate }
            for session in daySessions {
                guard let name = session.checkInPhotoFileName, !name.isEmpty, seen.insert(name).inserted else { continue }
                let url = WorkoutCheckInPhotoStore.fileURL(for: name)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                photos.append((
                    url.path,
                    session.workoutTitle,
                    dayTitle(cursor),
                    DailyWellnessEntry.dayKey(for: cursor)
                ))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return photos
    }

    private static func loadCalendarPhoto(path: String?) -> UIImage? {
        guard let path, !path.isEmpty else { return nil }
        if let image = UIImage(contentsOfFile: path) { return image }
        return WorkoutCheckInPhotoStore.load(fileName: URL(fileURLWithPath: path).lastPathComponent)
    }

    private static func monthTitleStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private static func dayTitle(fromDayKey key: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: key) else { return key }
        return dayTitle(date)
    }

    private static func dayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d 'de' MMMM"
        return formatter.string(from: date)
    }

    private static func count(_ value: Int, one: String, many: String) -> String {
        value == 1 ? "1 \(one)" : "\(value) \(many)"
    }

    private static func sample<T>(_ items: [T], limit: Int) -> [T] {
        guard items.count > limit, limit > 0 else { return items }
        if limit == 1 { return [items[items.count / 2]] }
        return (0..<limit).map { index in
            let position = Double(index) * Double(items.count - 1) / Double(limit - 1)
            return items[Int(position.rounded())]
        }
    }
}
