import Foundation
import Combine
import SwiftUI

enum WellnessHealthIconStatus: Equatable {
    case green
    case yellow
    case red

    var title: String {
        switch self {
        case .green: return "Ícone saudável"
        case .yellow: return "Ícone amarelo — atualize hoje"
        case .red: return "Ícone vermelho — 24h sem atualizar"
        }
    }

    var message: String {
        switch self {
        case .green:
            return "Parabéns, mantenha o foco em sua saúde"
        case .yellow:
            return "Atualize água e sono durante o dia para manter o ícone verde."
        case .red:
            return "Passou mais de 24 horas sem atualizar água e sono. Registre agora em Sono e Hidratação."
        }
    }

    var glowColor: Color {
        switch self {
        case .green: return AppTheme.accent
        case .yellow: return .yellow
        case .red: return .red
        }
    }
}

@MainActor
final class DailyWellnessService: ObservableObject {
    static let shared = DailyWellnessService()
    static let staleUpdateThreshold: TimeInterval = 24 * 60 * 60

    @Published private(set) var todayEntry: DailyWellnessEntry = .empty()
    @Published var pendingSleepHours: Double = 7
    @Published var showSleepCheckIn = false

    private var userEmail: String?
    private var cloudUserId: String?
    /// Meta diária de água (ml), derivada do perfil; enviada ao Firebase junto com o dia.
    private var waterGoalMl: Int?
    private let storagePrefix = "healthfit_wellness"
    private let lastUpdatePrefix = "healthfit_wellness_last_update"
    private let trackingStartPrefix = "healthfit_wellness_tracking_start"
    /// Dia em que o sheet matinal de sono/água já foi concluído ou dispensado (não reaparece no mesmo dia).
    private let morningCheckInHandledPrefix = "healthfit_wellness_morning_checkin_handled"

    private init() {}

    func configure(for user: UserProfile?) {
        userEmail = user?.email
        cloudUserId = user?.id
        waterGoalMl = user?.recommendedDailyWaterML
        if user != nil {
            ensureTrackingStarted()
        }
        loadTodayEntry()
        evaluateMorningCheckInPresentation()
        if user != nil {
            refreshHealthIconNotifications()
        }
    }

    func configureCloudSync(userId: String?) {
        cloudUserId = userId
    }

    /// Carrega o dia atual (e metadados) do Firebase e mescla com o cache local.
    func syncFromCloudIfNeeded() async {
        guard let userId = cloudUserId, DailyWellnessFirestoreService.isAvailable else { return }

        do {
            let todayKey = DailyWellnessEntry.dayKey(for: .now)
            if let remote = try await DailyWellnessFirestoreService.fetchEntry(userId: userId, dayKey: todayKey) {
                let merged = mergeEntries(local: todayEntry.dayKey == todayKey ? todayEntry : .empty(), remote: remote)
                todayEntry = merged
                persistLocally(merged)
            }

            let meta = try await DailyWellnessFirestoreService.fetchMeta(userId: userId)
            if let remoteLast = meta.lastWaterOrSleepUpdateAt {
                let localLast = lastWaterOrSleepUpdateAt
                if localLast == nil || remoteLast > localLast! {
                    setLastWaterOrSleepUpdateAt(remoteLast)
                }
            }
            if let remoteTracking = meta.trackingStartedAt, trackingStartedAt == nil {
                setTrackingStartedAt(remoteTracking)
            }

            // Garante que o estado local atual também exista na nuvem.
            if todayEntry.dayKey == todayKey {
                try await pushEntryToCloud(todayEntry)
                try await pushMetaToCloud()
            }

            evaluateMorningCheckInPresentation()
            refreshHealthIconNotifications()
        } catch {
            print("[HealthFit] Falha ao sincronizar wellness do Firebase: \(error.localizedDescription)")
        }
    }

    func clearAllLocalData() {
        if let userEmail {
            UserDefaults.standard.removeObject(forKey: storageKey(email: userEmail))
            UserDefaults.standard.removeObject(forKey: lastUpdateKey(email: userEmail))
            UserDefaults.standard.removeObject(forKey: trackingStartKey(email: userEmail))
            UserDefaults.standard.removeObject(forKey: morningCheckInHandledKey(email: userEmail))
        }
        userEmail = nil
        cloudUserId = nil
        waterGoalMl = nil
        todayEntry = .empty()
        pendingSleepHours = 7
        showSleepCheckIn = false
    }

    /// Chamado no foreground após login: apresenta o check-in matinal no máximo 1× por dia.
    func checkInOnAppOpen() {
        loadTodayEntry()
        evaluateMorningCheckInPresentation()
    }

    /// Sono ainda não registrado hoje (independente do sheet já ter sido dispensado).
    var needsSleepCheckIn: Bool {
        todayEntry.sleepHours == nil
    }

    /// Sheet matinal deve aparecer: usuário logado, sono pendente e ainda não tratado hoje.
    var shouldPresentMorningCheckIn: Bool {
        guard userEmail != nil else { return false }
        if hasLoggedSleepToday { return false }
        if isMorningCheckInHandledToday { return false }
        return true
    }

    /// Dispensa o sheet sem registrar sono; não reaparece até o próximo dia.
    func dismissMorningCheckIn() {
        markMorningCheckInHandled()
        showSleepCheckIn = false
    }

    var todaySleepHours: Double? {
        todayEntry.sleepHours
    }

    var todaySleepAssessment: SleepAssessment? {
        guard let hours = todayEntry.sleepHours else { return nil }
        return SleepAssessment.evaluate(hours: hours)
    }

    /// Última atualização de água ou sono (persiste entre dias).
    var lastWaterOrSleepUpdateAt: Date? {
        guard let userEmail else { return nil }
        return UserDefaults.standard.object(forKey: lastUpdateKey(email: userEmail)) as? Date
    }

    /// Exposto para agendar atualização do ícone da tela inicial.
    var lastWaterOrSleepUpdateAtForIconScheduling: Date? { lastWaterOrSleepUpdateAt }

    private var trackingStartedAt: Date? {
        guard let userEmail else { return nil }
        return UserDefaults.standard.object(forKey: trackingStartKey(email: userEmail)) as? Date
    }

    var trackingStartedAtForIconScheduling: Date? { trackingStartedAt }

    var hasLoggedSleepToday: Bool {
        todayEntry.sleepHours != nil
    }

    var hasLoggedWaterToday: Bool {
        todayEntry.waterIntakeMl > 0
    }

    func healthIconStatus(referenceDate: Date = .now) -> WellnessHealthIconStatus {
        let anchor = lastWaterOrSleepUpdateAt ?? trackingStartedAt
        if let anchor, referenceDate.timeIntervalSince(anchor) >= Self.staleUpdateThreshold {
            return .red
        }

        if hasLoggedSleepToday && hasLoggedWaterToday {
            return .green
        }

        return .yellow
    }

    func healthIconDetailMessage(referenceDate: Date = .now) -> String {
        let status = healthIconStatus(referenceDate: referenceDate)
        switch status {
        case .green:
            return status.message
        case .red:
            var parts: [String] = [status.message]
            if !hasLoggedSleepToday { parts.append("Sono de hoje ainda não registrado.") }
            if !hasLoggedWaterToday { parts.append("Água de hoje ainda não registrada.") }
            return parts.joined(separator: " ")
        case .yellow:
            var reasons: [String] = []
            if !hasLoggedSleepToday { reasons.append("sono") }
            if !hasLoggedWaterToday { reasons.append("água") }
            if reasons.isEmpty {
                return status.message
            }
            let missing = reasons.joined(separator: " e ")
            return "Ícone amarelo porque você ainda não atualizou \(missing) hoje. Registre em Sono e Hidratação."
        }
    }

    /// Avalia o ícone de saúde e dispara notificação ao mudar para amarelo/vermelho.
    func refreshHealthIconNotifications(referenceDate: Date = .now) {
        guard userEmail != nil else { return }

        let status = healthIconStatus(referenceDate: referenceDate)
        let staleAnchor = lastWaterOrSleepUpdateAt ?? trackingStartedAt
        let redFireDate = staleAnchor.map { $0.addingTimeInterval(Self.staleUpdateThreshold) }

        NotificationService.shared.refreshHealthIconNotifications(
            status: status,
            detailMessage: healthIconDetailMessage(referenceDate: referenceDate),
            redFireDate: redFireDate,
            dayKey: DailyWellnessEntry.dayKey(for: referenceDate),
            staleAnchor: staleAnchor
        )
        AppIconInactivityService.shared.syncWithWellnessHealthIcon(status: status)
    }

    func logSleep(hours: Double) {
        var entry = currentTodayEntry()
        entry.sleepHours = max(0, min(hours, 14))
        entry.sleepUpdatedAt = .now
        todayEntry = entry
        save(entry)
        markWaterOrSleepUpdated()
        markMorningCheckInHandled()
        // Mantém o sheet aberto para feedback/água; a UI fecha com Continuar ou dismissMorningCheckIn.
    }

    /// Atualiza a meta de água enviada ao Firebase a partir do peso do perfil.
    func refreshWaterGoal(from user: UserProfile?) {
        waterGoalMl = user?.recommendedDailyWaterML
    }

    func updateWaterIntake(_ milliliters: Int) {
        var entry = currentTodayEntry()
        let clamped = min(max(0, milliliters), WaterServing.maxDailyIntakeML)
        entry.waterIntakeMl = clamped
        if clamped > 0 {
            entry.waterUpdatedAt = .now
            markWaterOrSleepUpdated()
        }
        todayEntry = entry
        save(entry)
    }

    func addWater(_ milliliters: Int) {
        updateWaterIntake(min(todayEntry.waterIntakeMl + milliliters, WaterServing.maxDailyIntakeML))
    }

    func updateEnergyDrinksCount(_ count: Int) {
        var entry = currentTodayEntry()
        entry.energyDrinksCount = max(0, count)
        todayEntry = entry
        save(entry)
    }

    func updatePreWorkoutCount(_ count: Int) {
        var entry = currentTodayEntry()
        entry.preWorkoutCount = max(0, count)
        todayEntry = entry
        save(entry)
    }

    var todaySupplementIntakes: [SupplementIntakeEntry] {
        currentTodayEntry().supplementIntakes.sorted { $0.loggedAt > $1.loggedAt }
    }

    func logSupplementIntake(_ intake: SupplementIntakeEntry, athleteName: String = "Atleta") {
        guard !intake.name.isEmpty, intake.quantity > 0 else { return }
        var entry = currentTodayEntry()
        entry.supplementIntakes.append(intake)
        entry.supplementsUpdatedAt = .now
        todayEntry = entry
        save(entry)
        AssistantSupplementNudgeEngine.queueLoggedAcknowledgment(intake, athleteName: athleteName)
    }

    func removeSupplementIntake(id: UUID) {
        var entry = currentTodayEntry()
        entry.supplementIntakes.removeAll { $0.id == id }
        entry.supplementsUpdatedAt = .now
        todayEntry = entry
        save(entry)
    }

    func applyPreWorkoutFromWorkouts(_ sessions: [WorkoutSession]) {
        let usedToday = WorkoutReportBuilder.todayPreWorkoutEntries(from: sessions)
            .filter(\.tookPreWorkout)
            .count
        var entry = currentTodayEntry()
        guard usedToday > entry.preWorkoutCount else { return }
        entry.preWorkoutCount = usedToday
        todayEntry = entry
        save(entry)
    }

    var tookPreWorkoutAndEnergyDrinkToday: Bool {
        todayEntry.preWorkoutCount > 0 && todayEntry.energyDrinksCount > 0
    }

    func waterProgress(for user: UserProfile) -> Double {
        guard user.recommendedDailyWaterML > 0 else { return 0 }
        return min(Double(todayEntry.waterIntakeMl) / Double(user.recommendedDailyWaterML), 1.0)
    }

    func hasMetWaterGoal(for user: UserProfile) -> Bool {
        todayEntry.waterIntakeMl >= user.recommendedDailyWaterML
    }

    func waterStatusMessage(for user: UserProfile) -> String {
        if hasMetWaterGoal(for: user) {
            return "Excelente hidratação!"
        }
        return "Você precisa hidratar-se melhor."
    }

    private func evaluateMorningCheckInPresentation() {
        guard userEmail != nil else {
            showSleepCheckIn = false
            return
        }

        if hasLoggedSleepToday {
            markMorningCheckInHandled()
            // Se o sheet já está aberto (feedback pós-registro), a UI fecha com Continuar.
            return
        }

        guard shouldPresentMorningCheckIn else {
            showSleepCheckIn = false
            return
        }

        if !showSleepCheckIn {
            pendingSleepHours = 7
        }
        showSleepCheckIn = true
    }

    private var isMorningCheckInHandledToday: Bool {
        guard let userEmail else { return false }
        let stored = UserDefaults.standard.string(forKey: morningCheckInHandledKey(email: userEmail))
        return stored == DailyWellnessEntry.dayKey(for: .now)
    }

    private func markMorningCheckInHandled() {
        guard let userEmail else { return }
        UserDefaults.standard.set(
            DailyWellnessEntry.dayKey(for: .now),
            forKey: morningCheckInHandledKey(email: userEmail)
        )
    }

    private func markWaterOrSleepUpdated(at date: Date = .now) {
        setLastWaterOrSleepUpdateAt(date)
        objectWillChange.send()
        refreshHealthIconNotifications()
        Task {
            await pushMetaToCloudSafely()
        }
    }

    private func ensureTrackingStarted(at date: Date = .now) {
        guard trackingStartedAt == nil else { return }
        setTrackingStartedAt(date)
        Task {
            await pushMetaToCloudSafely()
        }
    }

    private func setLastWaterOrSleepUpdateAt(_ date: Date) {
        guard let userEmail else { return }
        UserDefaults.standard.set(date, forKey: lastUpdateKey(email: userEmail))
    }

    private func setTrackingStartedAt(_ date: Date) {
        guard let userEmail else { return }
        UserDefaults.standard.set(date, forKey: trackingStartKey(email: userEmail))
    }

    private func currentTodayEntry() -> DailyWellnessEntry {
        let today = DailyWellnessEntry.dayKey(for: .now)
        if todayEntry.dayKey == today {
            return todayEntry
        }
        return .empty()
    }

    private func loadTodayEntry() {
        guard let userEmail else {
            todayEntry = .empty()
            return
        }

        let key = storageKey(email: userEmail)
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode(DailyWellnessEntry.self, from: data),
              stored.dayKey == DailyWellnessEntry.dayKey(for: .now) else {
            todayEntry = .empty()
            return
        }
        todayEntry = stored
    }

    private func save(_ entry: DailyWellnessEntry) {
        persistLocally(entry)
        Task {
            await pushEntryToCloudSafely(entry)
            await pushMetaToCloudSafely()
        }
    }

    private func persistLocally(_ entry: DailyWellnessEntry) {
        guard let userEmail else { return }
        todayEntry = entry
        if let data = try? JSONEncoder().encode(entry) {
            UserDefaults.standard.set(data, forKey: storageKey(email: userEmail))
        }
    }

    private func pushEntryToCloudSafely(_ entry: DailyWellnessEntry) async {
        do {
            try await pushEntryToCloud(entry)
        } catch {
            print("[HealthFit] Falha ao salvar wellness no Firebase: \(error.localizedDescription)")
        }
    }

    private func pushEntryToCloud(_ entry: DailyWellnessEntry) async throws {
        guard let userId = cloudUserId else { return }
        try await DailyWellnessFirestoreService.saveEntry(
            entry,
            userId: userId,
            waterGoalMl: waterGoalMl
        )
    }

    private func pushMetaToCloudSafely() async {
        do {
            try await pushMetaToCloud()
        } catch {
            print("[HealthFit] Falha ao salvar meta de wellness no Firebase: \(error.localizedDescription)")
        }
    }

    private func pushMetaToCloud() async throws {
        guard let userId = cloudUserId else { return }
        try await DailyWellnessFirestoreService.saveMeta(
            userId: userId,
            lastWaterOrSleepUpdateAt: lastWaterOrSleepUpdateAt,
            trackingStartedAt: trackingStartedAt
        )
    }

    private func mergeEntries(local: DailyWellnessEntry, remote: DailyWellnessEntry) -> DailyWellnessEntry {
        var merged = local
        merged.dayKey = remote.dayKey

        // Prefere o sono mais recente; se só um lado tem, usa esse.
        switch (local.sleepUpdatedAt, remote.sleepUpdatedAt) {
        case let (l?, r?) where r >= l:
            merged.sleepHours = remote.sleepHours
            merged.sleepUpdatedAt = remote.sleepUpdatedAt
        case (nil, .some):
            merged.sleepHours = remote.sleepHours
            merged.sleepUpdatedAt = remote.sleepUpdatedAt
        default:
            break
        }

        if remote.waterIntakeMl > merged.waterIntakeMl {
            merged.waterIntakeMl = remote.waterIntakeMl
            merged.waterUpdatedAt = remote.waterUpdatedAt ?? merged.waterUpdatedAt
        } else if merged.waterUpdatedAt == nil {
            merged.waterUpdatedAt = remote.waterUpdatedAt
        }

        merged.energyDrinksCount = max(local.energyDrinksCount, remote.energyDrinksCount)
        merged.preWorkoutCount = max(local.preWorkoutCount, remote.preWorkoutCount)

        // Lista de suplementos: usa o lado com atualização mais recente (respeita remoções).
        switch (local.supplementsUpdatedAt, remote.supplementsUpdatedAt) {
        case let (l?, r?) where r > l:
            merged.supplementIntakes = remote.supplementIntakes
            merged.supplementsUpdatedAt = remote.supplementsUpdatedAt
        case (nil, .some):
            merged.supplementIntakes = remote.supplementIntakes
            merged.supplementsUpdatedAt = remote.supplementsUpdatedAt
        case (.some, nil):
            merged.supplementIntakes = local.supplementIntakes
            merged.supplementsUpdatedAt = local.supplementsUpdatedAt
        default:
            if remote.supplementIntakes.count > local.supplementIntakes.count {
                merged.supplementIntakes = remote.supplementIntakes
                merged.supplementsUpdatedAt = remote.supplementsUpdatedAt ?? local.supplementsUpdatedAt
            } else {
                merged.supplementIntakes = local.supplementIntakes
                merged.supplementsUpdatedAt = local.supplementsUpdatedAt ?? remote.supplementsUpdatedAt
            }
        }
        return merged
    }

    private func storageKey(email: String) -> String {
        let safeEmail = email.lowercased().replacingOccurrences(of: "@", with: "_at_")
        return "\(storagePrefix)_\(safeEmail)_today"
    }

    private func lastUpdateKey(email: String) -> String {
        let safeEmail = email.lowercased().replacingOccurrences(of: "@", with: "_at_")
        return "\(lastUpdatePrefix)_\(safeEmail)"
    }

    private func trackingStartKey(email: String) -> String {
        let safeEmail = email.lowercased().replacingOccurrences(of: "@", with: "_at_")
        return "\(trackingStartPrefix)_\(safeEmail)"
    }

    private func morningCheckInHandledKey(email: String) -> String {
        let safeEmail = email.lowercased().replacingOccurrences(of: "@", with: "_at_")
        return "\(morningCheckInHandledPrefix)_\(safeEmail)"
    }
}
