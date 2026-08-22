import Foundation

enum AssistantMealPlanBuilder {
    static let professionalDisclaimer =
        "Vou montar uma sugestão com base nos seus dados, mas é essencial consultar um nutricionista " +
        "ou médico antes de mudar a alimentação — este assistente não substitui avaliação profissional."

    static let quickLactoseReplies = LactoseTolerance.allCases.map(\.rawValue)
    static let quickSweetReplies = SweetConsumptionLevel.allCases.map(\.rawValue)
    static let quickGoalReplies = FitnessGoal.allCases.map(\.rawValue)
    static let quickConfirmReplies = ["Sim, autorizo", "Não, cancelar"]

    static func detectsMealPlanBuildIntent(_ text: String) -> Bool {
        let normalized = normalize(text)
        let phrases = [
            "montar cardapio",
            "criar cardapio",
            "gerar cardapio",
            "montar cardápio",
            "criar cardápio",
            "gerar cardápio",
            "cardapio personalizado",
            "cardápio personalizado",
            "plano alimentar",
            "montar dieta",
            "criar dieta",
            "gerar dieta",
            "cardapio sem nutricionista",
            "sem nutricionista",
            "montar cardapio mesmo assim",
            "montar cardápio mesmo assim",
            "iassistente cardapio",
            "iassistente cardápio",
            "sugestao de cardapio",
            "sugestão de cardápio"
        ]
        return phrases.contains { normalized.contains($0) }
    }

    static func detectsForceBuildDespiteNutritionist(_ text: String) -> Bool {
        let normalized = normalize(text)
        return normalized.contains("mesmo assim") && (normalized.contains("cardap") || normalized.contains("dieta"))
    }

    static func hasRequiredProfileData(_ user: UserProfile?) -> Bool {
        guard let user else { return false }
        return !looksLikeUnsetBodyMetrics(user)
    }

    static func profileGaps(for user: UserProfile?) -> [String] {
        guard let user else {
            return ["Faça login e complete Perfil (peso, altura, idade) e Nutrição (biotipo)."]
        }
        var gaps: [String] = []
        if looksLikeUnsetBodyMetrics(user) {
            gaps.append("Atualize peso, altura e idade em Perfil (ainda parecem valores padrão).")
        }
        return gaps
    }

    static func parseLactoseTolerance(from text: String) -> LactoseTolerance? {
        let normalized = normalize(text)
        if normalized.contains("intoler") || normalized.contains("sem lactose") || normalized.contains("nao toler") {
            return .intolerant
        }
        if normalized.contains("toler") || normalized.contains("sim") || normalized.contains("pode") {
            return .tolerant
        }
        return LactoseTolerance.allCases.first { normalized.contains(normalize($0.rawValue)) }
    }

    static func parseSweetLevel(from text: String) -> SweetConsumptionLevel? {
        let normalized = normalize(text)
        if normalized.contains("pouco") || normalized.contains("baixo") || normalized.contains("raro") {
            return .low
        }
        if normalized.contains("muito") || normalized.contains("alto") || normalized.contains("doces todo") {
            return .high
        }
        if normalized.contains("moder") || normalized.contains("medio") || normalized.contains("médio") {
            return .moderate
        }
        return SweetConsumptionLevel.allCases.first { normalized.contains(normalize($0.rawValue)) }
    }

    static func parseGoal(from text: String) -> FitnessGoal? {
        let normalized = normalize(text)
        if normalized.contains("massa") || normalized.contains("hipertrof") || normalized.contains("ganho") {
            return .muscleGain
        }
        if normalized.contains("gordura") || normalized.contains("emagrec") || normalized.contains("deficit")
            || normalized.contains("perda") || normalized.contains("secar") {
            return .fatLoss
        }
        if normalized.contains("resist") || normalized.contains("condicionamento") || normalized.contains("endurance") {
            return .endurance
        }
        if normalized.contains("manut") || normalized.contains("manter") {
            return .maintenance
        }
        return FitnessGoal.allCases.first { normalized.contains(normalize($0.rawValue)) }
    }

    static func isAffirmative(_ text: String) -> Bool {
        let normalized = normalize(text)
        let positives = ["sim", "autorizo", "pode", "ok", "quero", "confirmo", "gerar", "montar", "cria", "pode montar"]
        return positives.contains { normalized.contains($0) }
            && !normalized.contains("nao")
            && !normalized.contains("cancel")
    }

    static func isNegative(_ text: String) -> Bool {
        let normalized = normalize(text)
        return normalized.contains("nao") || normalized.contains("cancel") || normalized.contains("depois")
    }

    static func confirmationSummary(
        profile: UserProfile,
        lactose: LactoseTolerance,
        sweet: SweetConsumptionLevel,
        goal: FitnessGoal
    ) -> String {
        let planProfile = profileWith(goal: goal, base: profile)
        return """
        Resumo do cardápio sugerido:
        • Objetivo: \(goal.rawValue)
        • Biotipo: \(profile.biotype.rawValue)
        • Peso: \(Int(profile.weight)) kg · Altura: \(Int(profile.height)) cm · Idade: \(profile.age)
        • TMB: \(planProfile.basalMetabolicRate) kcal · TDEE: \(planProfile.estimatedTDEE) kcal
        • Meta diária: \(planProfile.dailyCalorieTarget) kcal
        • Lactose: \(lactose.rawValue)
        • Doces: \(sweet.rawValue)
        • 6 refeições/dia + lista de compras na aba Nutrição

        \(professionalDisclaimer)

        Autoriza gerar o cardápio e deixar disponível em Nutrição?
        Responda “Sim, autorizo” ou “Não, cancelar”.
        """
    }

    static func createdPlanLocationHint() -> String {
        """
        Cardápio pronto! Abra **Nutrição → Plano** (ou **Cardápio**) — você verá o selo **Sugerido pelo IAssistente**.

        Marque as refeições conforme for seguindo e use a lista de compras quando quiser.
        """
    }

    static func profileWith(goal: FitnessGoal, base: UserProfile) -> UserProfile {
        var copy = base
        copy.goal = goal
        return copy
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func looksLikeUnsetBodyMetrics(_ user: UserProfile) -> Bool {
        user.weight == 75 && user.height == 175 && user.age == 28
    }
}
