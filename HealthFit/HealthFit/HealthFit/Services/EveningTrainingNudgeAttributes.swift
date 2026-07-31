import Foundation
import ActivityKit

/// Live Activity do lembrete das 18:00 — separado do treino ativo para não conflitar.
struct EveningTrainingNudgeAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Texto fixo: usuário ainda não treinou.
        var statusMessage: String
        /// Motivação do dia da semana (PT-BR).
        var motivationalMessage: String
        /// Fim da janela de 3h (geralmente 21:00 local).
        var countdownEndDate: Date
    }

    /// Chave do dia local, ex. `2026-07-31`.
    var dayKey: String
}
