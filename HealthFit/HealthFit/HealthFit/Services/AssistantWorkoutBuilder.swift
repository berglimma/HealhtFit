import Foundation

/// Foco solicitado no fluxo do IAssistente para montar ficha.
enum AssistantWorkoutGoalFocus: String, CaseIterable, Identifiable {
    case muscleGain = "Ganho de massa"
    case endurance = "Resistência"
    case fatLoss = "Perda de gordura"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .muscleGain: return "Hipertrofia"
        case .endurance: return "Resistência"
        case .fatLoss: return "Emagrecimento"
        }
    }

    static func parse(from text: String) -> AssistantWorkoutGoalFocus? {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        if normalized.contains("massa") || normalized.contains("hipertrof") || normalized.contains("musculo") {
            return .muscleGain
        }
        if normalized.contains("resist") || normalized.contains("condicionamento") || normalized.contains("endurance") {
            return .endurance
        }
        if normalized.contains("gordura") || normalized.contains("emagrec") || normalized.contains("definir")
            || normalized.contains("perda") || normalized.contains("secar") {
            return .fatLoss
        }
        return nil
    }
}

enum AssistantWorkoutBuilder {
    static let professionalDisclaimer =
        "Vou montar uma sugestão com base nos seus dados, mas é essencial consultar um profissional de Educação Física " +
        "antes de iniciar ou alterar treinos — este assistente não substitui avaliação presencial nem prescrição profissional."

    static let quickGenderReplies = ["Masculino", "Feminino"]
    static let quickFocusReplies = [
        AssistantWorkoutGoalFocus.muscleGain.rawValue,
        AssistantWorkoutGoalFocus.endurance.rawValue,
        AssistantWorkoutGoalFocus.fatLoss.rawValue
    ]
    static let quickConfirmReplies = ["Sim, autorizo", "Não, cancelar"]

    /// Lacunas que impedem ou enfraquecem a personalização.
    static func profileGaps(for user: UserProfile?) -> [String] {
        guard let user else {
            return ["Faça login e complete Perfil (peso, altura, idade) e Nutrição (biotipo)."]
        }

        var gaps: [String] = []
        if looksLikeUnsetBodyMetrics(user) {
            gaps.append("Atualize peso, altura e idade em Perfil (ainda parecem valores padrão).")
        }
        if !user.bodyMeasurements.hasAnyValue {
            gaps.append("Inclua medidas corporais em Perfil (opcional, mas melhora a sugestão).")
        }
        return gaps
    }

    /// Dados mínimos obrigatórios para gerar a ficha.
    static func hasRequiredProfileData(_ user: UserProfile?) -> Bool {
        guard let user else { return false }
        return !looksLikeUnsetBodyMetrics(user)
    }

    static func parseGender(from text: String) -> Gender? {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
        if normalized.contains("femin") {
            return .female
        }
        if normalized.contains("mascul") || normalized == "homem" || normalized.contains("homem") {
            return .male
        }
        return nil
    }

    static func isAffirmative(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
        let positives = ["sim", "autorizo", "pode", "ok", "quero", "confirmo", "gerar", "montar", "cria", "pode montar"]
        return positives.contains { normalized.contains($0) }
            && !normalized.contains("nao")
            && !normalized.contains("cancel")
    }

    static func isNegative(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
        return normalized.contains("nao") || normalized.contains("cancel") || normalized.contains("depois")
    }

    static func detectsWorkoutBuildIntent(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        let phrases = [
            "montar treino",
            "criar treino",
            "gerar treino",
            "montar ficha",
            "criar ficha",
            "gerar ficha",
            "ficha personalizada",
            "treino sem personal",
            "nao tenho personal",
            "sem personal",
            "montar treino mesmo assim",
            "treino pelo assistente",
            "iassistente montar",
            "sugestao de treino",
            "montar um treino"
        ]
        return phrases.contains { normalized.contains($0) }
    }

    static func detectsForceBuildDespitePersonal(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
        return normalized.contains("mesmo assim") || normalized.contains("mesmo assim montar")
    }

    static func buildSheet(
        gender: Gender,
        focus: AssistantWorkoutGoalFocus,
        profile: UserProfile
    ) -> WorkoutSheet {
        let templates = templateExercises(gender: gender, focus: focus)
        let exercises = templates.map { adjust($0, profile: profile, focus: focus) }
        let genderLabel = gender == .female ? "Feminino" : "Masculino"
        let biotypeNote = profile.biotype.rawValue
        let measuresNote = profile.bodyMeasurements.hasAnyValue
            ? "Medidas corporais consideradas."
            : "Medidas corporais ainda incompletas — ajuste cargas com cautela."

        let description = """
        Gerado pelo IAssistente · \(focus.rawValue) · biotipo \(biotypeNote) · \(Int(profile.weight)) kg. \
        \(measuresNote) Sugestão educativa — essencial validar com profissional de Educação Física.
        """

        return WorkoutSheet(
            title: "IAssistente — \(focus.shortLabel) (\(genderLabel))",
            description: description,
            exercises: exercises,
            isUserCreated: true,
            targetGender: gender,
            createdByAssistant: true
        )
    }

    static func confirmationSummary(
        gender: Gender,
        focus: AssistantWorkoutGoalFocus,
        profile: UserProfile
    ) -> String {
        let genderLabel = gender == .female ? "feminino" : "masculino"
        let optionalMeasures = profile.bodyMeasurements.hasAnyValue
            ? "Medidas corporais encontradas no Perfil."
            : "Ainda sem medidas corporais detalhadas (pode gerar mesmo assim)."

        return """
        Resumo da sugestão:
        • Perfil de treino: \(genderLabel)
        • Foco: \(focus.rawValue)
        • Peso: \(Int(profile.weight)) kg · Altura: \(Int(profile.height)) cm · Idade: \(profile.age)
        • Biotipo: \(profile.biotype.rawValue)
        • \(optionalMeasures)

        \(professionalDisclaimer)

        Autoriza criar a ficha e deixar disponível em Treinos → Personalizados?
        Responda “Sim, autorizo” ou “Não, cancelar”.
        """
    }

    // MARK: - Private

    private static func looksLikeUnsetBodyMetrics(_ user: UserProfile) -> Bool {
        user.weight == 75 && user.height == 175 && user.age == 28
    }

    private static func templateExercises(gender: Gender, focus: AssistantWorkoutGoalFocus) -> [Exercise] {
        switch (gender, focus) {
        case (.male, .muscleGain):
            return named([
                ("Supino Reto", 4, 8, 70, 90, .chest),
                ("Supino Inclinado", 4, 10, 55, 90, .chest),
                ("Remada Curvada", 4, 8, 60, 90, .back),
                ("Puxada Frontal", 3, 10, 50, 75, .back),
                ("Agachamento Livre", 4, 8, 90, 120, .legs),
                ("Leg Press 45°", 3, 10, 180, 90, .legs),
                ("Desenvolvimento com Halteres", 3, 10, 20, 75, .shoulders),
                ("Rosca Direta", 3, 10, 16, 60, .arms),
                ("Tríceps Pulley", 3, 10, 30, 60, .arms),
                ("Prancha", 3, 40, 0, 45, .core)
            ])
        case (.male, .endurance):
            return named([
                ("Agachamento Livre", 3, 15, 50, 45, .legs),
                ("Leg Press 45°", 3, 15, 100, 45, .legs),
                ("Flexão de Braços", 3, 15, 0, 45, .chest),
                ("Puxada Frontal", 3, 15, 35, 45, .back),
                ("Elevação Lateral", 3, 15, 8, 40, .shoulders),
                ("Mountain Climber", 3, 30, 0, 40, .core),
                ("Burpee", 3, 12, 0, 60, .fullBody),
                ("Kettlebell Swing", 3, 15, 12, 45, .fullBody),
                ("Prancha", 3, 45, 0, 40, .core)
            ])
        case (.male, .fatLoss):
            return named([
                ("Agachamento Livre", 3, 12, 60, 60, .legs),
                ("Remada Curvada", 3, 12, 45, 60, .back),
                ("Supino Reto", 3, 12, 50, 60, .chest),
                ("Afundo", 3, 12, 16, 45, .legs),
                ("Elevação Lateral", 3, 15, 8, 40, .shoulders),
                ("Burpee", 3, 12, 0, 45, .fullBody),
                ("Mountain Climber", 3, 30, 0, 40, .core),
                ("Abdominal Crunch", 3, 20, 0, 40, .core),
                ("Kettlebell Swing", 3, 15, 12, 45, .fullBody)
            ])
        case (.female, .muscleGain):
            return named([
                ("Elevação Pélvica (Hip Thrust)", 4, 12, 40, 75, .legs),
                ("Agachamento Sumô", 4, 12, 40, 90, .legs),
                ("Stiff", 4, 12, 30, 75, .legs),
                ("Afundo Búlgaro", 3, 12, 12, 75, .legs),
                ("Cadeira Abdutora", 3, 15, 40, 45, .legs),
                ("Puxada Frontal", 3, 12, 30, 60, .back),
                ("Remada Unilateral", 3, 12, 12, 60, .back),
                ("Elevação Lateral", 3, 15, 6, 45, .shoulders),
                ("Prancha", 3, 40, 0, 45, .core)
            ])
        case (.female, .endurance):
            return named([
                ("Agachamento Livre", 3, 15, 30, 45, .legs),
                ("Afundo", 3, 15, 8, 45, .legs),
                ("Elevação Pélvica (Hip Thrust)", 3, 15, 25, 45, .legs),
                ("Puxada Frontal", 3, 15, 25, 45, .back),
                ("Elevação Lateral", 3, 15, 5, 40, .shoulders),
                ("Mountain Climber", 3, 30, 0, 40, .core),
                ("Bicicleta no Ar", 3, 20, 0, 40, .core),
                ("Kettlebell Swing", 3, 15, 10, 45, .fullBody),
                ("Prancha", 3, 40, 0, 40, .core)
            ])
        case (.female, .fatLoss):
            return named([
                ("Agachamento Livre", 3, 12, 30, 50, .legs),
                ("Elevação Pélvica (Hip Thrust)", 3, 12, 30, 50, .legs),
                ("Afundo", 3, 12, 8, 45, .legs),
                ("Cadeira Adutora", 3, 15, 35, 40, .legs),
                ("Puxada Frontal", 3, 12, 25, 50, .back),
                ("Flexão de Braços", 3, 10, 0, 45, .chest),
                ("Mountain Climber", 3, 30, 0, 40, .core),
                ("Abdominal Oblíquo", 3, 20, 0, 40, .core),
                ("Kettlebell Swing", 3, 15, 10, 45, .fullBody)
            ])
        }
    }

    private static func named(
        _ items: [(String, Int, Int, Double, Int, MuscleGroup)]
    ) -> [Exercise] {
        items.map { name, sets, reps, weight, rest, group in
            Exercise(
                name: name,
                sets: sets,
                reps: reps,
                weight: weight > 0 ? weight : nil,
                restSeconds: rest,
                muscleGroup: group
            )
        }
    }

    private static func adjust(
        _ template: Exercise,
        profile: UserProfile,
        focus: AssistantWorkoutGoalFocus
    ) -> Exercise {
        var exercise = Exercise(
            name: template.name,
            sets: template.sets,
            reps: template.reps,
            weight: template.weight,
            restSeconds: template.restSeconds,
            notes: template.notes,
            muscleGroup: template.muscleGroup
        )
        let weightFactor = min(1.35, max(0.65, profile.weight / 75.0))

        if let base = exercise.recommendedWeight, base > 0 {
            var scaled = (base * weightFactor).rounded()
            switch profile.biotype {
            case .ectomorph:
                scaled *= focus == .muscleGain ? 0.9 : 0.95
            case .endomorph:
                scaled *= focus == .fatLoss ? 0.95 : 1.05
            case .mesomorph:
                break
            }
            exercise.recommendedWeight = max(2, scaled.rounded())
        }

        switch (profile.biotype, focus) {
        case (.ectomorph, .muscleGain):
            exercise.restSeconds = min(150, exercise.restSeconds + 15)
        case (.endomorph, .fatLoss), (.endomorph, .endurance):
            exercise.restSeconds = max(30, exercise.restSeconds - 10)
            exercise.reps = min(20, exercise.reps + 2)
        default:
            break
        }

        return exercise
    }
}
