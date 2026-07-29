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

/// Experiência de academia coletada no fluxo do IAssistente.
enum AssistantTrainingExperience: String, CaseIterable, Identifiable {
    case firstTime = "Primeira vez na academia"
    case returning = "Retomando após pausa"
    case beginner = "Iniciante"
    case intermediate = "Intermediário"
    case advanced = "Avançado"

    var id: String { rawValue }

    var summaryLabel: String {
        switch self {
        case .firstTime: return "Primeira vez na academia"
        case .returning: return "Já treinou antes, retomando agora"
        case .beginner: return "Já treina · iniciante"
        case .intermediate: return "Já treina · intermediário"
        case .advanced: return "Já treina · avançado"
        }
    }

    static let quickLevelReplies = ["Iniciante", "Intermediário", "Avançado"]
    static let quickAlreadyTrainsReplies = ["Sim, já treino", "Não, ainda não"]
    static let quickFirstTimeReplies = ["Sim, primeira vez", "Não, já treinei antes"]

    static func parseLevel(from text: String) -> AssistantTrainingExperience? {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        if normalized.contains("avanc") {
            return .advanced
        }
        if normalized.contains("intermed") {
            return .intermediate
        }
        if normalized.contains("inici") {
            return .beginner
        }
        return nil
    }

    static func fromFirstTimeAnswer(_ isFirstTime: Bool) -> AssistantTrainingExperience {
        isFirstTime ? .firstTime : .returning
    }

    func summaryLabel(for location: AssistantTrainingLocation) -> String {
        switch (self, location) {
        case (.firstTime, .homeOnly):
            return "Primeira vez treinando em casa"
        case (.returning, .homeOnly):
            return "Retomando treinos em casa"
        case (.beginner, .homeOnly):
            return "Já treina em casa · iniciante"
        case (.intermediate, .homeOnly):
            return "Já treina em casa · intermediário"
        case (.advanced, .homeOnly):
            return "Já treina em casa · avançado"
        default:
            return summaryLabel
        }
    }
}

enum AssistantTrainingLocation: String, CaseIterable, Identifiable {
    case gym = "Academia"
    case homeOnly = "Só em casa"

    var id: String { rawValue }

    var summaryLabel: String {
        switch self {
        case .gym: return "Academia / equipamentos"
        case .homeOnly: return "Apenas em casa (peso corporal)"
        }
    }

    static let quickReplies = ["Sim, só em casa", "Não, na academia"]
}

enum AssistantWorkoutBuilder {
    static let professionalDisclaimer =
        "Vou montar uma sugestão com base nos seus dados, mas é essencial consultar um profissional de Educação Física " +
        "antes de iniciar ou alterar treinos — este assistente não substitui avaliação presencial nem prescrição profissional."

    static let quickGenderReplies = ["Masculino", "Feminino"]
    static let quickHomeOnlyReplies = AssistantTrainingLocation.quickReplies
    static let quickAlreadyTrainsReplies = AssistantTrainingExperience.quickAlreadyTrainsReplies
    static let quickFirstTimeReplies = AssistantTrainingExperience.quickFirstTimeReplies
    static let quickLevelReplies = AssistantTrainingExperience.quickLevelReplies
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

    /// “Deseja treinar apenas em casa?”
    static func parseHomeOnly(from text: String) -> Bool? {
        let normalized = normalize(text)
        if normalized.contains("so em casa") || normalized.contains("apenas em casa")
            || normalized.contains("somente em casa") || normalized.contains("treino em casa")
            || normalized.contains("treinar em casa") || normalized == "casa"
            || normalized.contains("peso corporal") || normalized.contains("sem academia") {
            return true
        }
        if normalized.contains("academia") || normalized.contains("musculacao")
            || normalized.contains("equipamento") || normalized.contains("na academia") {
            return false
        }
        return parsePlainYesNo(normalized)
    }

    /// “Você já treina atualmente?”
    static func parseAlreadyTrains(from text: String) -> Bool? {
        let normalized = normalize(text)
        if normalized.contains("ainda nao") || normalized.contains("nunca") || normalized.contains("nao treino") {
            return false
        }
        if normalized.contains("ja treino") || normalized.contains("ja treina") || normalized.contains("treino sim") {
            return true
        }
        return parsePlainYesNo(normalized)
    }

    /// “É a sua primeira vez na academia?”
    static func parseFirstTimeAtGym(from text: String) -> Bool? {
        let normalized = normalize(text)
        if normalized.contains("ja treinei") || normalized.contains("ja pratiquei")
            || normalized.contains("ja fui") || normalized.contains("voltei")
            || normalized.contains("retom") {
            return false
        }
        if normalized.contains("primeira vez") || normalized.contains("nunca treinei")
            || normalized.contains("nunca fui") {
            return true
        }
        return parsePlainYesNo(normalized)
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
            "montar um treino",
            "treino em casa",
            "montar treino em casa",
            "criar treino em casa",
            "ficha em casa",
            "treinar em casa"
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
        profile: UserProfile,
        experience: AssistantTrainingExperience = .intermediate,
        location: AssistantTrainingLocation = .gym
    ) -> WorkoutSheet {
        let templates = templateExercises(
            gender: gender,
            focus: focus,
            experience: experience,
            location: location
        )
        let exercises = templates.map {
            adjust($0, profile: profile, focus: focus, experience: experience, location: location)
        }
        let genderLabel = gender == .female ? "Feminino" : "Masculino"
        let biotypeNote = profile.biotype.rawValue
        let measuresNote = profile.bodyMeasurements.hasAnyValue
            ? "Medidas corporais consideradas."
            : "Medidas corporais ainda incompletas — ajuste o volume com cautela."
        let locationNote = location == .homeOnly
            ? "Treino em casa · peso corporal (sem academia)."
            : "Treino para academia / equipamentos."

        let titlePrefix = location == .homeOnly ? "IAssistente — Casa ·" : "IAssistente —"
        let description = """
        Gerado pelo IAssistente · \(focus.rawValue) · \(experience.summaryLabel(for: location)) · \(locationNote) \
        Biotipo \(biotypeNote) · \(Int(profile.weight)) kg. \(measuresNote) \
        Sugestão educativa — essencial validar com profissional de Educação Física.
        """

        return WorkoutSheet(
            title: "\(titlePrefix) \(focus.shortLabel) (\(genderLabel))",
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
        profile: UserProfile,
        experience: AssistantTrainingExperience,
        location: AssistantTrainingLocation
    ) -> String {
        let genderLabel = gender == .female ? "feminino" : "masculino"
        let optionalMeasures = profile.bodyMeasurements.hasAnyValue
            ? "Medidas corporais encontradas no Perfil."
            : "Ainda sem medidas corporais detalhadas (pode gerar mesmo assim)."
        let locationExtra = location == .homeOnly
            ? "Ficha de peso corporal para fazer em casa (com demos em GIF)."
            : "Ficha pensada para academia / equipamentos."

        return """
        Resumo da sugestão:
        • Perfil de treino: \(genderLabel)
        • Local: \(location.summaryLabel)
        • Experiência: \(experience.summaryLabel(for: location))
        • Foco: \(focus.rawValue)
        • Peso: \(Int(profile.weight)) kg · Altura: \(Int(profile.height)) cm · Idade: \(profile.age)
        • Biotipo: \(profile.biotype.rawValue)
        • \(optionalMeasures)
        • \(locationExtra)

        \(professionalDisclaimer)

        Autoriza criar a ficha e deixar disponível em Treinos → Personalizados?
        Responda “Sim, autorizo” ou “Não, cancelar”.
        """
    }

    static func createdSheetLocationHint(gender: Gender, location: AssistantTrainingLocation) -> String {
        let program = gender == .female ? "Feminino" : "Masculino"
        var lines = [
            "Onde encontrar: **Treinos → Musculação → \(program) → Personalizados** (badge IAssistente)."
        ]
        if location == .homeOnly {
            lines.append(
                "Dica: em **Treinos → Treine em Casa** há fichas prontas de peso corporal com demos para complementar."
            )
        }
        return lines.joined(separator: "\n\n")
    }

    // MARK: - Private

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parsePlainYesNo(_ normalized: String) -> Bool? {
        if normalized.hasPrefix("nao") || normalized == "n" || normalized.hasPrefix("n,")
            || normalized.hasPrefix("n ") {
            return false
        }
        if normalized.hasPrefix("sim") || normalized == "s" || normalized.hasPrefix("s,")
            || normalized.hasPrefix("s ") {
            return true
        }
        return nil
    }

    private static func looksLikeUnsetBodyMetrics(_ user: UserProfile) -> Bool {
        user.weight == 75 && user.height == 175 && user.age == 28
    }

    private static func templateExercises(
        gender: Gender,
        focus: AssistantWorkoutGoalFocus,
        experience: AssistantTrainingExperience,
        location: AssistantTrainingLocation
    ) -> [Exercise] {
        if location == .homeOnly {
            return homeTemplateExercises(gender: gender, focus: focus, experience: experience)
        }
        return gymTemplateExercises(gender: gender, focus: focus, experience: experience)
    }

    private static func homeTemplateExercises(
        gender: Gender,
        focus: AssistantWorkoutGoalFocus,
        experience: AssistantTrainingExperience
    ) -> [Exercise] {
        let base: [Exercise]
        switch (gender, focus) {
        case (.male, .muscleGain):
            base = named([
                ("Agachamento Livre", 4, 15, 0, 45, .legs),
                ("Flexão de Braços", 4, 12, 0, 45, .chest),
                ("Afundo", 3, 12, 0, 45, .legs),
                ("Mergulho no Banco", 3, 12, 0, 45, .arms),
                ("Superman", 3, 15, 0, 40, .back),
                ("Flexão Diamante", 3, 10, 0, 45, .arms),
                ("Prancha", 3, 40, 0, 40, .core),
                ("Mountain Climber", 3, 20, 0, 40, .fullBody)
            ])
        case (.male, .endurance):
            base = named([
                ("Polichinelo", 3, 40, 0, 30, .fullBody),
                ("Agachamento Livre", 3, 20, 0, 35, .legs),
                ("Flexão de Braços", 3, 15, 0, 35, .chest),
                ("Burpee", 3, 12, 0, 45, .fullBody),
                ("Mountain Climber", 3, 30, 0, 30, .fullBody),
                ("Afundo", 3, 16, 0, 35, .legs),
                ("Prancha", 3, 45, 0, 30, .core),
                ("Polichinelo", 2, 35, 0, 40, .fullBody)
            ])
        case (.male, .fatLoss):
            base = named([
                ("Polichinelo", 3, 35, 0, 30, .fullBody),
                ("Agachamento Livre", 3, 18, 0, 35, .legs),
                ("Burpee", 3, 12, 0, 40, .fullBody),
                ("Flexão de Braços", 3, 12, 0, 35, .chest),
                ("Afundo", 3, 14, 0, 35, .legs),
                ("Mountain Climber", 3, 30, 0, 30, .fullBody),
                ("Abdominal Crunch", 3, 20, 0, 30, .core),
                ("Prancha", 3, 40, 0, 30, .core)
            ])
        case (.female, .muscleGain):
            base = named([
                ("Agachamento Livre", 4, 15, 0, 45, .legs),
                ("Ponte de Glúteos", 4, 15, 0, 40, .legs),
                ("Afundo", 3, 12, 0, 45, .legs),
                ("Elevação Pélvica (Hip Thrust)", 3, 15, 0, 45, .legs),
                ("Flexão de Braços", 3, 10, 0, 45, .chest),
                ("Superman", 3, 12, 0, 40, .back),
                ("Prancha", 3, 40, 0, 40, .core),
                ("Russian Twist", 3, 20, 0, 35, .core)
            ])
        case (.female, .endurance):
            base = named([
                ("Polichinelo", 3, 35, 0, 30, .fullBody),
                ("Agachamento Livre", 3, 18, 0, 35, .legs),
                ("Afundo", 3, 15, 0, 35, .legs),
                ("Ponte de Glúteos", 3, 15, 0, 35, .legs),
                ("Mountain Climber", 3, 30, 0, 30, .fullBody),
                ("Bicicleta no Ar", 3, 24, 0, 30, .core),
                ("Flexão de Braços", 3, 10, 0, 35, .chest),
                ("Prancha", 3, 40, 0, 30, .core)
            ])
        case (.female, .fatLoss):
            base = named([
                ("Polichinelo", 3, 35, 0, 30, .fullBody),
                ("Agachamento Livre", 3, 18, 0, 35, .legs),
                ("Burpee", 3, 10, 0, 40, .fullBody),
                ("Ponte de Glúteos", 3, 15, 0, 35, .legs),
                ("Afundo", 3, 14, 0, 35, .legs),
                ("Mountain Climber", 3, 30, 0, 30, .fullBody),
                ("Abdominal Oblíquo", 3, 20, 0, 30, .core),
                ("Prancha", 3, 40, 0, 30, .core)
            ])
        }

        switch experience {
        case .firstTime:
            return Array(base.prefix(6)).map { exercise in
                var copy = exercise
                copy.sets = min(3, copy.sets)
                copy.notes = copy.notes.isEmpty
                    ? "Foque na técnica e use o demo em GIF no app."
                    : copy.notes
                return copy
            }
        case .returning:
            return Array(base.prefix(7)).map { exercise in
                var copy = exercise
                copy.sets = min(3, copy.sets)
                return copy
            }
        case .beginner, .intermediate, .advanced:
            return base
        }
    }

    private static func gymTemplateExercises(
        gender: Gender,
        focus: AssistantWorkoutGoalFocus,
        experience: AssistantTrainingExperience
    ) -> [Exercise] {
        let base: [Exercise]
        switch (gender, focus) {
        case (.male, .muscleGain):
            base = named([
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
            base = named([
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
            base = named([
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
            base = named([
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
            base = named([
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
            base = named([
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

        switch experience {
        case .firstTime:
            return Array(base.prefix(7)).map { exercise in
                var copy = exercise
                copy.sets = min(3, copy.sets)
                if copy.notes.isEmpty {
                    copy.notes = "Priorize técnica; peça orientação na academia se tiver dúvida."
                }
                return copy
            }
        case .returning:
            return Array(base.prefix(8)).map { exercise in
                var copy = exercise
                copy.sets = min(3, copy.sets)
                return copy
            }
        case .beginner, .intermediate, .advanced:
            return base
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
        focus: AssistantWorkoutGoalFocus,
        experience: AssistantTrainingExperience,
        location: AssistantTrainingLocation
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

        if location == .homeOnly {
            exercise.weight = nil
            switch experience {
            case .firstTime:
                exercise.restSeconds = min(90, exercise.restSeconds + 15)
                exercise.reps = max(8, exercise.reps - 2)
            case .returning, .beginner:
                exercise.restSeconds = min(75, exercise.restSeconds + 10)
            case .advanced:
                exercise.reps = min(30, exercise.reps + 4)
                if exercise.sets < 4 { exercise.sets += 1 }
            case .intermediate:
                break
            }

            switch (profile.biotype, focus) {
            case (.endomorph, .fatLoss), (.endomorph, .endurance):
                exercise.reps = min(35, exercise.reps + 3)
                exercise.restSeconds = max(25, exercise.restSeconds - 5)
            case (.ectomorph, .muscleGain):
                exercise.restSeconds = min(90, exercise.restSeconds + 10)
            default:
                break
            }
            return exercise
        }

        let weightFactor = min(1.35, max(0.65, profile.weight / 75.0))
        let experienceFactor: Double
        switch experience {
        case .firstTime: experienceFactor = 0.45
        case .returning: experienceFactor = 0.60
        case .beginner: experienceFactor = 0.75
        case .intermediate: experienceFactor = 1.0
        case .advanced: experienceFactor = 1.15
        }

        if let base = exercise.recommendedWeight, base > 0 {
            var scaled = (base * weightFactor * experienceFactor).rounded()
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

        switch experience {
        case .firstTime:
            exercise.restSeconds = min(150, exercise.restSeconds + 25)
            if exercise.notes.isEmpty {
                exercise.notes = "Comece leve e foque na execução."
            }
        case .returning:
            exercise.restSeconds = min(140, exercise.restSeconds + 15)
        case .beginner:
            exercise.restSeconds = min(130, exercise.restSeconds + 10)
        case .advanced:
            if exercise.sets < 4, [.chest, .back, .legs].contains(exercise.muscleGroup) {
                exercise.sets += 1
            }
        case .intermediate:
            break
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
