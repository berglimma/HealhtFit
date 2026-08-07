import Combine
import Foundation

/// Inventário de equipamento de escalada com controle de usos e tempo de serviço.
@MainActor
final class ClimbingGearService: ObservableObject {
    static let shared = ClimbingGearService()

    private let storageKey = "healthfit.climbing.gear.v1"
    private let lastAlertKey = "healthfit.climbing.gear.lastAlert.v1"
    private var boundUserId: String?

    @Published private(set) var items: [ClimbingGearItem] = []

    private init() {
        load()
    }

    func bind(userId: String?) {
        guard boundUserId != userId else { return }
        boundUserId = userId
        load()
    }

    // MARK: - Consulta

    var activeItems: [ClimbingGearItem] {
        items.filter { !$0.isRetired }
    }

    /// Ordenado pelo que precisa de atenção primeiro.
    var sortedItems: [ClimbingGearItem] {
        items.sorted {
            if $0.status.sortPriority != $1.status.sortPriority {
                return $0.status.sortPriority < $1.status.sortPriority
            }
            return $0.wearRatio > $1.wearRatio
        }
    }

    var overdueItems: [ClimbingGearItem] {
        items.filter { $0.status == .overdue }
    }

    var dueSoonItems: [ClimbingGearItem] {
        items.filter { $0.status == .dueSoon }
    }

    var needsAttention: Bool {
        !overdueItems.isEmpty || !dueSoonItems.isEmpty
    }

    // MARK: - Edição

    func add(type: ClimbingGearType, name: String = "", acquiredAt: Date = .now) {
        items.append(ClimbingGearItem(type: type, name: name, acquiredAt: acquiredAt))
        save()
    }

    func add(_ item: ClimbingGearItem) {
        items.append(item)
        save()
    }

    func update(_ item: ClimbingGearItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save()
    }

    func remove(_ item: ClimbingGearItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    /// Zera a contagem de usos e reinicia o relógio de serviço.
    func markInspected(_ item: ClimbingGearItem, at date: Date = .now) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].lastInspectedAt = date
        items[index].useCount = 0
        save()
    }

    func setRetired(_ item: ClimbingGearItem, retired: Bool) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isRetired = retired
        save()
    }

    /// Cria o kit sugerido para quem ainda não montou o inventário.
    func createStarterKit(for discipline: ClimbingDiscipline) {
        let existing = Set(items.map(\.type))
        let missing = discipline.suggestedStarterKit.filter { !existing.contains($0) }
        guard !missing.isEmpty else { return }
        items.append(contentsOf: missing.map { ClimbingGearItem(type: $0) })
        save()
    }

    // MARK: - Uso por sessão

    /// Soma um uso a cada item da modalidade e avisa se algo passou do limite.
    func registerSessionUse(discipline: ClimbingDiscipline) {
        let types = Set(discipline.gearTypesInUse)
        var touched = false

        for index in items.indices where !items[index].isRetired && types.contains(items[index].type) {
            items[index].useCount += 1
            touched = true
        }

        guard touched else { return }
        save()
        notifyInspectionIfNeeded()
    }

    /// Alerta no máximo uma vez por dia para não virar ruído.
    func notifyInspectionIfNeeded(force: Bool = false) {
        let overdue = overdueItems.map(\.name)
        let dueSoon = dueSoonItems.map(\.name)
        guard !overdue.isEmpty || !dueSoon.isEmpty else { return }

        if !force {
            let lastAlert = UserDefaults.standard.object(forKey: lastAlertKey) as? Date
            if let lastAlert, Calendar.current.isDateInToday(lastAlert) { return }
        }

        UserDefaults.standard.set(Date(), forKey: lastAlertKey)
        NotificationService.shared.deliverClimbingGearInspectionAlert(
            overdueNames: overdue,
            dueSoonNames: dueSoon
        )
    }

    /// Resumo textual usado pelo IAssistente.
    func assistantSummary() -> String {
        guard !items.isEmpty else {
            return "Você ainda não cadastrou equipamento. Abra o diário de escalada e monte o inventário para eu acompanhar usos e tempo de serviço de corda, costuras e cadeirinha."
        }

        let overdue = overdueItems
        let dueSoon = dueSoonItems

        if overdue.isEmpty && dueSoon.isEmpty {
            let nextUp = sortedItems.first { !$0.isRetired }
            var text = "Nenhum item vencido — seu equipamento está em dia."
            if let nextUp {
                text += " O próximo a pedir atenção é \(nextUp.alertMessage.lowercased())"
            }
            return text
        }

        var lines: [String] = []
        if !overdue.isEmpty {
            lines.append("Revise antes de subir:")
            lines.append(contentsOf: overdue.map { "• \($0.alertMessage)" })
        }
        if !dueSoon.isEmpty {
            lines.append(overdue.isEmpty ? "Chegando no limite:" : "\nChegando no limite:")
            lines.append(contentsOf: dueSoon.map { "• \($0.alertMessage)" })
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Persistência

    private func load() {
        items = []
        guard let data = UserScopedDefaults.data(
            forLogicalKey: "climbing.gear.v1",
            uid: boundUserId,
            legacyKey: storageKey
        ),
              let decoded = try? JSONDecoder().decode([ClimbingGearItem].self, from: data) else {
            return
        }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserScopedDefaults.setData(
            data,
            forLogicalKey: "climbing.gear.v1",
            uid: boundUserId,
            legacyKey: storageKey
        )
    }
}
