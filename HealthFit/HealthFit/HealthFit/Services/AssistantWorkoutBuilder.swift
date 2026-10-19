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

    /// Preferência persistida no perfil (hub de musculação).
    var musculacaoPreference: MusculacaoTrainingExperience {
        switch self {
        case .firstTime, .returning, .beginner:
            return .beginner
        case .intermediate, .advanced:
            return .trainsAlready
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

/// Quem já treina pode pedir fichas novas ou só as recomendações do catálogo.
enum AssistantWorkoutDeliveryMode: String, CaseIterable, Identifiable {
    case create = "Criar fichas"
    case recommend = "Recomendar do catálogo"

    var id: String { rawValue }

    static let quickReplies = [Self.create.rawValue, Self.recommend.rawValue]

    static func parse(from text: String) -> AssistantWorkoutDeliveryMode? {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        if normalized.contains("recomend") || normalized.contains("catalogo") || normalized.contains("pront") {
            return .recommend
        }
        if normalized.contains("criar") || normalized.contains("montar") || normalized.contains("gerar")
            || normalized.contains("nova") || normalized.contains("fichas novas") {
            return .create
        }
        return nil
    }
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
    static let quickDeliveryModeReplies = AssistantWorkoutDeliveryMode.quickReplies
    static let quickFocusReplies = [
        AssistantWorkoutGoalFocus.muscleGain.rawValue,
        AssistantWorkoutGoalFocus.endurance.rawValue,
        AssistantWorkoutGoalFocus.fatLoss.rawValue
    ]
    static let quickConfirmReplies = ["Sim, autorizo", "Não, cancelar"]

    /// Grupos cobertos quando o IAssistente cria o programa.
    static let programMuscleGroups: [MuscleGroup] = [
        .chest, .back, .legs, .shoulders, .arms, .core
    ]

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

    /// Uma ficha mista (compatível com testes / atalhos). Preferir `buildProgramSheets` no fluxo completo.
    static func buildSheet(
        gender: Gender,
        focus: AssistantWorkoutGoalFocus,
        profile: UserProfile,
        experience: AssistantTrainingExperience = .intermediate,
        location: AssistantTrainingLocation = .gym
    ) -> WorkoutSheet {
        let sheets = buildProgramSheets(
            gender: gender,
            focus: focus,
            profile: profile,
            experience: experience,
            location: location
        )
        if sheets.count == 1, let only = sheets.first {
            return only
        }
        let exercises = sheets.flatMap(\.exercises)
        let genderLabel = gender == .female ? "Feminino" : "Masculino"
        let titlePrefix = location == .homeOnly ? "IAssistente — Casa ·" : "IAssistente —"
        return WorkoutSheet(
            title: "\(titlePrefix) \(focus.shortLabel) (\(genderLabel))",
            description: sheets.first?.description ?? "",
            exercises: exercises,
            isUserCreated: true,
            targetGender: gender,
            createdByAssistant: true
        )
    }

    /// Cria uma ficha por grupo muscular (peito, costas, pernas, ombros, braços, abdômen).
    static func buildProgramSheets(
        gender: Gender,
        focus: AssistantWorkoutGoalFocus,
        profile: UserProfile,
        experience: AssistantTrainingExperience = .intermediate,
        location: AssistantTrainingLocation = .gym
    ) -> [WorkoutSheet] {
        let genderLabel = gender == .female ? "Feminino" : "Masculino"
        let biotypeNote = profile.biotype.rawValue
        let measuresNote = profile.bodyMeasurements.hasAnyValue
            ? "Medidas corporais consideradas."
            : "Medidas corporais ainda incompletas — ajuste o volume com cautela."
        let locationNote = location == .homeOnly
            ? "Treino em casa · peso corporal (sem academia)."
            : "Treino para academia / equipamentos."
        let titlePrefix = location == .homeOnly ? "IAssistente — Casa ·" : "IAssistente —"

        return programMuscleGroups.compactMap { group in
            let templates = templateExercises(
                gender: gender,
                focus: focus,
                experience: experience,
                location: location,
                muscleGroup: group
            )
            guard !templates.isEmpty else { return nil }
            let exercises = templates.map {
                adjust($0, profile: profile, focus: focus, experience: experience, location: location, gender: gender)
            }
            let description = """
            Gerado pelo IAssistente · \(group.rawValue) · \(focus.rawValue) · \
            \(experience.summaryLabel(for: location)) · \(locationNote) \
            Biotipo \(biotypeNote) · \(Int(profile.weight)) kg. \(measuresNote) \
            Sugestão educativa — essencial validar com profissional de Educação Física.
            """
            return WorkoutSheet(
                title: "\(titlePrefix) \(group.rawValue) · \(focus.shortLabel) (\(genderLabel))",
                description: description,
                exercises: exercises,
                isUserCreated: true,
                targetGender: gender,
                createdByAssistant: true
            )
        }
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
            ? "Fichas de peso corporal para fazer em casa (com demos em GIF)."
            : "Fichas pensadas para academia / equipamentos."
        let groupsLabel = programMuscleGroups.map(\.rawValue).joined(separator: ", ")

        return """
        Resumo da sugestão:
        • Perfil de treino: \(genderLabel) (do seu Perfil)
        • Local: \(location.summaryLabel)
        • Experiência: \(experience.summaryLabel(for: location))
        • Foco: \(focus.rawValue)
        • Grupos: \(groupsLabel) — uma ficha para cada
        • Peso: \(Int(profile.weight)) kg · Altura: \(Int(profile.height)) cm · Idade: \(profile.age)
        • Biotipo: \(profile.biotype.rawValue)
        • \(optionalMeasures)
        • \(locationExtra)

        \(professionalDisclaimer)

        Autoriza criar as fichas e abrir **Treinos → Personalizados**?
        Responda “Sim, autorizo” ou “Não, cancelar”.
        """
    }

    static func recommendConfirmationSummary(gender: Gender, experience: AssistantTrainingExperience) -> String {
        let program = gender == .female ? "Feminino" : "Masculino"
        return """
        Beleza — vou te levar às fichas **Recomendadas** do programa \(program), \
        calibradas para o nível **\(experience.rawValue.lowercased())**.

        \(professionalDisclaimer)

        Autoriza abrir **Treinos → Musculação → \(program) → Recomendados**?
        Responda “Sim, autorizo” ou “Não, cancelar”.
        """
    }

    static func createdSheetLocationHint(gender: Gender, location: AssistantTrainingLocation, sheetCount: Int) -> String {
        let program = gender == .female ? "Feminino" : "Masculino"
        var lines = [
            "Abri **Treinos → Musculação → \(program) → Personalizados** com \(sheetCount) ficha\(sheetCount == 1 ? "" : "s") (badge IAssistente)."
        ]
        if location == .homeOnly {
            lines.append(
                "Dica: em **Treinos → Treine em Casa** há fichas prontas de peso corporal com demos para complementar."
            )
        }
        return lines.joined(separator: "\n\n")
    }

    static func recommendedCatalogHint(gender: Gender) -> String {
        let program = gender == .female ? "Feminino" : "Masculino"
        return "Abri **Treinos → Musculação → \(program) → Recomendados** para você escolher uma ficha do catálogo."
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
        location: AssistantTrainingLocation,
        muscleGroup: MuscleGroup
    ) -> [Exercise] {
        let base: [Exercise]
        if location == .homeOnly {
            base = homeTemplateExercises(gender: gender, focus: focus, muscleGroup: muscleGroup)
        } else {
            base = gymTemplateExercises(gender: gender, focus: focus, muscleGroup: muscleGroup)
        }
        return trim(base, experience: experience, location: location)
    }

    private static func exerciseLimit(
        for experience: AssistantTrainingExperience,
        location: AssistantTrainingLocation
    ) -> Int {
        switch experience {
        case .firstTime: return location == .homeOnly ? 3 : 3
        case .returning, .beginner: return 4
        case .intermediate: return 5
        case .advanced: return 6
        }
    }

    private static func trim(
        _ base: [Exercise],
        experience: AssistantTrainingExperience,
        location: AssistantTrainingLocation
    ) -> [Exercise] {
        let limit = exerciseLimit(for: experience, location: location)
        let sliced = Array(base.prefix(limit))
        switch experience {
        case .firstTime:
            return sliced.map { exercise in
                var copy = exercise
                copy.sets = min(3, copy.sets)
                if copy.notes.isEmpty {
                    copy.notes = location == .homeOnly
                        ? "Foque na técnica e use o demo em GIF no app."
                        : "Priorize técnica; peça orientação na academia se tiver dúvida."
                }
                return copy
            }
        case .returning, .beginner:
            return sliced.map { exercise in
                var copy = exercise
                copy.sets = min(3, copy.sets)
                return copy
            }
        case .intermediate, .advanced:
            return sliced
        }
    }

    private static func homeTemplateExercises(
        gender: Gender,
        focus: AssistantWorkoutGoalFocus,
        muscleGroup: MuscleGroup
    ) -> [Exercise] {
        let higherReps = focus != .muscleGain
        switch muscleGroup {
        case .chest:
            return named([
                ("Flexão de Braços", higherReps ? 3 : 4, higherReps ? 15 : 12, 0, 45, .chest),
                ("Flexão Inclinação", 3, higherReps ? 14 : 10, 0, 45, .chest),
                ("Flexão Diamante", 3, higherReps ? 12 : 8, 0, 45, .chest),
                ("Flexão de Braços", 2, higherReps ? 12 : 10, 0, 40, .chest)
            ])
        case .back:
            return named([
                ("Superman", higherReps ? 3 : 4, higherReps ? 18 : 15, 0, 40, .back),
                ("Remada Invertida", 3, higherReps ? 14 : 10, 0, 45, .back),
                ("Good Morning", 3, higherReps ? 15 : 12, 0, 40, .back),
                ("Superman", 2, 12, 0, 35, .back)
            ])
        case .legs:
            if gender == .female {
                return named([
                    ("Agachamento Livre", higherReps ? 3 : 4, higherReps ? 18 : 15, 0, 45, .legs),
                    ("Ponte de Glúteos", higherReps ? 3 : 4, higherReps ? 18 : 15, 0, 40, .legs),
                    ("Afundo", 3, higherReps ? 14 : 12, 0, 45, .legs),
                    ("Elevação Pélvica (Hip Thrust)", 3, higherReps ? 15 : 12, 0, 45, .legs),
                    ("Agachamento Sumô", 3, 15, 0, 40, .legs)
                ])
            }
            return named([
                ("Agachamento Livre", higherReps ? 3 : 4, higherReps ? 20 : 15, 0, 45, .legs),
                ("Afundo", 3, higherReps ? 16 : 12, 0, 45, .legs),
                ("Agachamento Sumô", 3, higherReps ? 16 : 12, 0, 40, .legs),
                ("Ponte de Glúteos", 3, 15, 0, 40, .legs),
                ("Afundo", 2, 12, 0, 40, .legs)
            ])
        case .shoulders:
            return named([
                ("Elevação Lateral", 3, higherReps ? 18 : 15, 0, 40, .shoulders),
                ("Desenvolvimento com Halteres", 3, higherReps ? 15 : 12, 0, 45, .shoulders),
                ("Elevação Frontal", 3, higherReps ? 15 : 12, 0, 40, .shoulders),
                ("Prancha", 3, 40, 0, 40, .shoulders)
            ])
        case .arms:
            return named([
                ("Mergulho no Banco", higherReps ? 3 : 4, higherReps ? 14 : 12, 0, 45, .arms),
                ("Flexão Diamante", 3, higherReps ? 12 : 10, 0, 45, .arms),
                ("Rosca Direta", 3, higherReps ? 15 : 12, 0, 40, .arms),
                ("Mergulho no Banco", 2, 10, 0, 40, .arms)
            ])
        case .core:
            return named([
                ("Prancha", 3, higherReps ? 45 : 40, 0, 40, .core),
                ("Abdominal Crunch", 3, higherReps ? 24 : 20, 0, 30, .core),
                ("Mountain Climber", 3, higherReps ? 30 : 20, 0, 35, .core),
                ("Abdominal Oblíquo", 3, 20, 0, 30, .core),
                ("Russian Twist", 3, 20, 0, 30, .core)
            ])
        case .fullBody:
            return named([
                ("Burpee", 3, 12, 0, 45, .fullBody),
                ("Mountain Climber", 3, 30, 0, 30, .fullBody),
                ("Polichinelo", 3, 35, 0, 30, .fullBody)
            ])
        }
    }

    private static func gymTemplateExercises(
        gender: Gender,
        focus: AssistantWorkoutGoalFocus,
        muscleGroup: MuscleGroup
    ) -> [Exercise] {
        let endurance = focus == .endurance
        let fatLoss = focus == .fatLoss
        let female = gender == .female
        let repsBase = endurance || fatLoss ? 12 : 8
        let setsBase = endurance || fatLoss ? 3 : 4

        switch muscleGroup {
        case .chest:
            return named([
                ("Supino Reto", setsBase, repsBase, 70, 90, .chest),
                ("Supino Inclinado", 3, repsBase + 2, 55, 90, .chest),
                ("Crucifixo Reto", 3, repsBase + 2, 14, 60, .chest),
                ("Crossover", 3, repsBase + 2, 20, 60, .chest),
                ("Flexão de Braços", 3, fatLoss ? 15 : 12, 0, 45, .chest)
            ])
        case .back:
            return named([
                ("Remada Curvada", setsBase, repsBase, 60, 90, .back),
                ("Puxada Frontal", 3, repsBase + 2, 50, 75, .back),
                ("Remada Unilateral", 3, repsBase + 2, 16, 60, .back),
                ("Puxada Aberta", 3, repsBase + 2, 45, 75, .back),
                ("Barra Fixa", 3, fatLoss ? 10 : 8, 0, 90, .back)
            ])
        case .legs:
            if female {
                return named([
                    ("Elevação Pélvica (Hip Thrust)", setsBase, repsBase + 4, 40, 75, .legs),
                    ("Agachamento Sumô", setsBase, repsBase + 4, 40, 90, .legs),
                    ("Stiff", 3, repsBase + 4, 30, 75, .legs),
                    ("Afundo Búlgaro", 3, repsBase + 4, 12, 75, .legs),
                    ("Cadeira Abdutora", 3, 15, 40, 45, .legs),
                    ("Leg Press 45°", 3, repsBase + 2, 140, 90, .legs)
                ])
            }
            return named([
                ("Agachamento Livre", setsBase, repsBase, 90, 120, .legs),
                ("Leg Press 45°", 3, repsBase + 2, 180, 90, .legs),
                ("Stiff", 3, repsBase + 2, 50, 90, .legs),
                ("Afundo", 3, repsBase + 2, 16, 60, .legs),
                ("Cadeira Extensora", 3, 12, 40, 60, .legs),
                ("Panturrilha em Pé", 3, 15, 40, 45, .legs)
            ])
        case .shoulders:
            return named([
                ("Desenvolvimento com Halteres", setsBase, repsBase + 2, 20, 75, .shoulders),
                ("Elevação Lateral", 3, repsBase + 4, 8, 45, .shoulders),
                ("Elevação Frontal", 3, repsBase + 4, 8, 45, .shoulders),
                ("Crucifixo Inverso", 3, repsBase + 2, 10, 45, .shoulders),
                ("Desenvolvimento Arnold", 3, repsBase + 2, 14, 60, .shoulders)
            ])
        case .arms:
            return named([
                ("Rosca Direta", setsBase, repsBase + 2, 16, 60, .arms),
                ("Tríceps Pulley", setsBase, repsBase + 2, 30, 60, .arms),
                ("Rosca Martelo", 3, repsBase + 2, 12, 45, .arms),
                ("Tríceps Testa", 3, repsBase + 2, 18, 60, .arms),
                ("Mergulho no Banco", 3, fatLoss ? 14 : 10, 0, 45, .arms)
            ])
        case .core:
            return named([
                ("Prancha", 3, endurance ? 45 : 40, 0, 45, .core),
                ("Abdominal Crunch", 3, 20, 0, 40, .core),
                ("Abdominal Oblíquo", 3, 20, 0, 40, .core),
                ("Mountain Climber", 3, fatLoss || endurance ? 30 : 20, 0, 40, .core),
                ("Bicicleta no Ar", 3, 24, 0, 35, .core)
            ])
        case .fullBody:
            return named([
                ("Burpee", 3, 12, 0, 60, .fullBody),
                ("Kettlebell Swing", 3, 15, 12, 45, .fullBody),
                ("Mountain Climber", 3, 30, 0, 40, .fullBody)
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
        focus: AssistantWorkoutGoalFocus,
        experience: AssistantTrainingExperience,
        location: AssistantTrainingLocation,
        gender: Gender
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
        let genderFactor: Double = gender == .female ? 0.85 : 1.0
        let experienceFactor: Double
        switch experience {
        case .firstTime: experienceFactor = 0.45
        case .returning: experienceFactor = 0.55
        case .beginner: experienceFactor = 0.55
        case .intermediate: experienceFactor = 1.0
        case .advanced: experienceFactor = 1.15
        }

        if let base = exercise.weight, base > 0 {
            var scaled = (base * weightFactor * experienceFactor * genderFactor).rounded()
            switch profile.biotype {
            case .ectomorph:
                scaled *= focus == .muscleGain ? 0.9 : 0.95
            case .endomorph:
                scaled *= focus == .fatLoss ? 0.95 : 1.05
            case .mesomorph:
                break
            }
            exercise.weight = max(2, scaled.rounded())
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
