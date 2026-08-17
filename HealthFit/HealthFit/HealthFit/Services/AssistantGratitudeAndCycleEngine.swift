import Foundation

/// Respostas curtas quando o usuário agradece no IAssistente.
enum AssistantGratitudeEngine {
    private static let tokens = [
        "obrigado", "obrigada", "obrigadao", "muito obrigado", "muito obrigada",
        "obrigadissimo", "obrigadissima", "super obrigado", "super obrigada",
        "grato", "grata", "gratidao", "agradecido", "agradecida",
        "agradeço", "agradecco", "te agradeço", "te agradeco",
        "fico grato", "fico grata", "ficamos gratos",
        "valeu", "vlw", "obg", "obgd",
        "thanks", "thank you", "thx", "ty "
    ]

    private static let questionHints = [
        "como ", "qual ", "quais ", "quando ", "onde ", "por que", "porque",
        "o que ", "posso ", "devo ", "sera que", "será que", "?"
    ]

    static func matches(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let normalized = normalize(trimmed)
        guard tokens.contains(where: { normalized.contains($0) }) else { return false }

        if trimmed.count <= 80, !normalized.contains("?") {
            return true
        }

        if questionHints.contains(where: { normalized.contains($0) }) {
            return false
        }
        return trimmed.count <= 140
    }

    static func answer(context: HealthAssistantContext) -> String {
        let name = context.user?.greetingName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let greeting = name.isEmpty ? "De nada!" : "De nada, \(name)!"
        return """
        \(greeting) Eu que agradeço a confiança. 🙏

        Estou aqui no IAssistente para treino, nutrição, rotina e o que mais você precisar. Qualquer dúvida, é só escrever.
        """
    }

    private static func normalize(_ text: String) -> String {
        " \(text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))) "
    }
}

/// Ciclo menstrual no IAssistente: só perfil feminino. Masculino não recebe este conteúdo.
enum MenstrualCycleAssistantEngine {
    static let gynecologistAdvice =
        "Se ocorrer qualquer alteração no ciclo menstrual — atraso, fluxo muito diferente do habitual, dor intensa, sangramento entre os períodos ou ausência de menstruação — procure um ginecologista. O IAssistente não faz diagnóstico e não substitui consulta médica."

    private static let keywords = [
        "ciclo menstrual", "menstruacao", "menstruo", "menstruou", "menstruando",
        "periodo menstrual", "atraso menstrual", "menstruacao atrasada", "ciclo atrasou",
        "ciclo irregular", "fluxo menstrual", "tpm", "ovulacao", "colica menstrual",
        "alteracao no ciclo", "alteracoes no ciclo", "ciclo mudou", "mudou o ciclo",
        "sangramento irregular", "falta de menstruacao", "amenorreia", "ginecologista",
        "dismenorreia", "endometriose", "sindrome pre-menstrual"
    ]

    static func isEnabled(in context: HealthAssistantContext) -> Bool {
        context.user?.gender == .female
    }

    static func matches(_ question: String) -> Bool {
        let normalized = question
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
        return keywords.contains { normalized.contains($0) }
    }

    static func answer(for question: String, context: HealthAssistantContext) -> String? {
        guard isEnabled(in: context), matches(question) else { return nil }

        let name = context.user?.greetingName ?? "Atleta"
        var lines = [
            "\(name), alterações no ciclo merecem atenção profissional.",
            "",
            gynecologistAdvice
        ]

        if let snapshot = context.user?.currentMenstrualSnapshot {
            lines.append("")
            lines.append(
                "Pelo que está registrado na sua conta (privado, só você vê): agora é \(snapshot.phase.displayName.lowercased()), dia \(snapshot.cycleDay) de \(snapshot.cycleLengthDays)."
            )
            lines.append("Como você está se sentindo hoje? Energia, cólica, humor — pode me contar, e eu te apoio no treino com leveza.")
        } else {
            lines.append("")
            lines.append(
                "Se quiser acompanhamento privado no app, ative o ciclo em Perfil → Seus Dados (só a sua conta acessa)."
            )
        }

        lines.append("")
        lines.append("Enquanto isso: treine conforme o corpo pedir, hidrate, priorize sono e evite comparar medidas nesta fase se houver inchaço.")
        lines.append("")
        lines.append(HealthAssistantEngine.healthSafetyDisclaimer)
        return lines.joined(separator: "\n")
    }

    static func welcomeAlert(context: HealthAssistantContext) -> String? {
        guard isEnabled(in: context) else { return nil }
        if context.user?.menstrualCycle.tracksCycle == true {
            return gynecologistAdvice
        }
        return "Ciclo menstrual: se houver alteração fora do seu padrão, procure um ginecologista."
    }

    static func suggestedQuestions(context: HealthAssistantContext) -> [String] {
        guard isEnabled(in: context) else { return [] }
        return ["O que fazer se o ciclo menstrual mudar?"]
    }
}
