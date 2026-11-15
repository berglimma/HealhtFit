import Foundation

/// Mensagens de incentivo do IAssistente para o HealthFit Pulse (máx. 2×/dia).
@MainActor
enum AssistantPulseNudgeEngine {
    private static let dayKeyPrefix = "healthfit.assistant.pulseNudge.day."
    private static let slotKeyPrefix = "healthfit.assistant.pulseNudge.slot."

    enum Slot: String {
        case morning
        case evening

        static func current(now: Date = .now) -> Slot {
            let hour = Calendar.current.component(.hour, from: now)
            return hour < 15 ? .morning : .evening
        }
    }

    static func shouldDeliver(now: Date = .now) -> Bool {
        guard PulseEntitlement.isPulseVisible else { return false }
        let day = dayStamp(now)
        let slot = Slot.current(now: now)
        let key = slotKeyPrefix + day + "." + slot.rawValue
        return !UserDefaults.standard.bool(forKey: key)
    }

    static func markDelivered(now: Date = .now) {
        let day = dayStamp(now)
        let slot = Slot.current(now: now)
        UserDefaults.standard.set(true, forKey: slotKeyPrefix + day + "." + slot.rawValue)
        UserDefaults.standard.set(day, forKey: dayKeyPrefix + "last")
    }

    static func message(athleteName: String, slot: Slot = .current()) -> String {
        let name = athleteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let greetingName = name.isEmpty ? "Atleta" : name

        switch slot {
        case .morning:
            return """
            Bom dia, \(greetingName)! 💚

            Que tal começar o dia no **HealthFit Pulse**? Veja o que a comunidade treinou, compartilhe sua evolução e inspire (e se inspire).

            Abra o card **Pulse** no Dashboard — 1 minuto já muda o ritmo do dia. 🔥
            """
        case .evening:
            return """
            Ei, \(greetingName)! 🌙

            Antes de encerrar o dia, passe no **HealthFit Pulse**: curta treinos, poste o seu e mantenha a constância com a galera.

            Toque em **Pulse** no Dashboard e deixe o feed trabalhar a favor da sua rotina. 💪
            """
        }
    }

    private static func dayStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
