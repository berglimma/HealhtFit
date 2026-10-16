import Foundation
import Combine

enum StudyPriorityLevel: String, Codable, CaseIterable, Identifiable {
    case high
    case medium
    case low

    var id: String { rawValue }

    var label: String {
        switch self {
        case .high: return "Alta"
        case .medium: return "Média"
        case .low: return "Baixa"
        }
    }

    var icon: String {
        switch self {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "flag.fill"
        case .low: return "bookmark.fill"
        }
    }
}

struct StudyPriorityItem: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var level: StudyPriorityLevel

    init(id: UUID = UUID(), title: String, level: StudyPriorityLevel = .medium) {
        self.id = id
        self.title = title
        self.level = level
    }
}

struct StudyFocusCard: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var note: String
    var priorities: [StudyPriorityItem]
    var notifyPriorities: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        note: String = "",
        priorities: [StudyPriorityItem] = [],
        notifyPriorities: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.priorities = priorities
        self.notifyPriorities = notifyPriorities
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Prompts usados na sessão guiada (prioridades + guias padrão).
    func sessionPrompts(base: [String]) -> [String] {
        let priorityLines = priorities
            .sorted { lhs, rhs in
                let order: [StudyPriorityLevel: Int] = [.high: 0, .medium: 1, .low: 2]
                return (order[lhs.level] ?? 9) < (order[rhs.level] ?? 9)
            }
            .map { "Prioridade \($0.level.label): \($0.title)" }
        if priorityLines.isEmpty { return base }
        return priorityLines + base
    }

    func asMeditationTopic(base: MeditationTopic) -> MeditationTopic {
        MeditationTopic(
            id: id,
            name: name,
            description: note.isEmpty ? base.description : note,
            icon: "book.fill",
            colorName: "indigo",
            prompts: sessionPrompts(base: base.prompts)
        )
    }
}

struct StudyFocusSessionRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var cardName: String
    var durationSeconds: Int
    var endedAt: Date
    var prioritiesCompletedHint: Int

    init(
        id: UUID = UUID(),
        cardName: String,
        durationSeconds: Int,
        endedAt: Date = .now,
        prioritiesCompletedHint: Int = 0
    ) {
        self.id = id
        self.cardName = cardName
        self.durationSeconds = durationSeconds
        self.endedAt = endedAt
        self.prioritiesCompletedHint = prioritiesCompletedHint
    }
}

@MainActor
final class StudyFocusStore: ObservableObject {
    static let shared = StudyFocusStore()

    @Published private(set) var cards: [StudyFocusCard] = []
    @Published private(set) var sessionLog: [StudyFocusSessionRecord] = []

    private let storageKey = "healthfit.study_focus.cards.v1"
    private let sessionsKey = "healthfit.study_focus.sessions.v1"
    private let lastInsightDayKey = "healthfit.study_focus.last_insight_day"
    private let lastProgressDayKey = "healthfit.study_focus.last_progress_day"
    private let defaults: UserDefaults

    static var studyTopic: MeditationTopic {
        MeditationTopic.catalog.first(where: { $0.name == "Foco em Estudo" })
            ?? MeditationTopic(
                name: "Foco em Estudo",
                description: "Sessão de concentração com prioridades e lembretes",
                icon: "book.fill",
                colorName: "indigo",
                prompts: ["Foque na prioridade atual.", "Continue estudando com atenção."]
            )
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        loadSessions()
        if cards.isEmpty {
            seedDefaultCard()
        }
    }

    var lastInsightDay: String? {
        get { defaults.string(forKey: lastInsightDayKey) }
        set { defaults.set(newValue, forKey: lastInsightDayKey) }
    }

    var lastProgressDay: String? {
        get { defaults.string(forKey: lastProgressDayKey) }
        set { defaults.set(newValue, forKey: lastProgressDayKey) }
    }

    func recordCompletedSession(cardName: String, durationSeconds: Int, prioritiesCount: Int = 0, at date: Date = .now) {
        let record = StudyFocusSessionRecord(
            cardName: cardName,
            durationSeconds: max(0, durationSeconds),
            endedAt: date,
            prioritiesCompletedHint: prioritiesCount
        )
        sessionLog.insert(record, at: 0)
        if sessionLog.count > 120 {
            sessionLog = Array(sessionLog.prefix(120))
        }
        persistSessions()
        NotificationService.shared.recordStudyFocusCompleted(at: date)
        NotificationService.shared.refreshStudyFocusRoutineReminders(using: sessionLog)
    }

    func card(id: UUID) -> StudyFocusCard? {
        cards.first { $0.id == id }
    }

    @discardableResult
    func create(name: String, note: String = "", priorities: [StudyPriorityItem] = [], notifyPriorities: Bool = true) -> StudyFocusCard {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let card = StudyFocusCard(
            name: trimmed.isEmpty ? "Meu estudo" : trimmed,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            priorities: priorities,
            notifyPriorities: notifyPriorities
        )
        cards.insert(card, at: 0)
        persist()
        return card
    }

    func update(_ card: StudyFocusCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        var next = card
        next.updatedAt = .now
        let trimmed = next.name.trimmingCharacters(in: .whitespacesAndNewlines)
        next.name = trimmed.isEmpty ? "Meu estudo" : trimmed
        cards[index] = next
        persist()
    }

    func delete(id: UUID) {
        cards.removeAll { $0.id == id }
        persist()
    }

    private func seedDefaultCard() {
        cards = [
            StudyFocusCard(
                name: "Sessão de estudo",
                note: "Card padrão — edite, exclua ou crie outros com o nome que quiser.",
                priorities: [
                    StudyPriorityItem(title: "Revisar o conteúdo principal", level: .high),
                    StudyPriorityItem(title: "Resolver exercícios", level: .medium),
                    StudyPriorityItem(title: "Resumo final", level: .low)
                ],
                notifyPriorities: true
            )
        ]
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([StudyFocusCard].self, from: data) else {
            cards = []
            return
        }
        cards = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cards) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func loadSessions() {
        guard let data = defaults.data(forKey: sessionsKey),
              let decoded = try? JSONDecoder().decode([StudyFocusSessionRecord].self, from: data) else {
            sessionLog = []
            return
        }
        sessionLog = decoded.sorted { $0.endedAt > $1.endedAt }
    }

    private func persistSessions() {
        guard let data = try? JSONEncoder().encode(sessionLog) else { return }
        defaults.set(data, forKey: sessionsKey)
    }
}
