import Foundation

/// Responde perguntas de escalada cruzando histórico de vias, recuperação, clima e equipamento.
enum ClimbingAssistantEngine {
    enum Intent {
        case successByRouteType
        case gradeProgress(degree: Int?)
        case readiness
        case gearInspection
        case conditions
        case overview
    }

    /// Perguntas mostradas como sugestão no chat.
    static let suggestedQuestions: [String] = [
        "Quais tipos de vias têm menor taxa de sucesso?",
        "Estou evoluindo nos graus 6º ou 7º?",
        "Minha recuperação está adequada para tentar uma via mais difícil amanhã?",
        "Qual equipamento preciso revisar antes da próxima escalada?",
        "Em quais condições de temperatura e umidade costumo ter melhor desempenho?"
    ]

    static func matches(_ question: String) -> Bool {
        intent(for: question) != nil
    }

    // MARK: - Roteamento

    static func intent(for question: String) -> Intent? {
        let text = normalize(question)

        // Equipamento é a única intenção que dispensa contexto explícito de escalada:
        // "o que preciso revisar" com nome de item já é inequívoco.
        if mentionsAny(text, gearWords), mentionsAny(text, inspectionWords) {
            return .gearInspection
        }

        let isClimbingContext = mentionsAny(text, climbingWords)

        if mentionsAny(text, ["taxa de sucesso", "menor taxa", "menos sucesso", "pior desempenho", "tipos de via", "tipo de via", "que vias"]),
           isClimbingContext || mentionsAny(text, ["via", "vias", "boulder"]) {
            return .successByRouteType
        }

        if isClimbingContext || mentionsAny(text, ["grau", "graus"]) {
            if mentionsAny(text, ["evoluindo", "evolucao", "progresso", "progredindo", "progressao", "melhorando"]) {
                return .gradeProgress(degree: parseDegree(text))
            }
        }

        if mentionsAny(text, ["recuperacao", "recuperado", "descansado", "pronto para", "prontidao", "posso tentar", "via mais dificil", "mais dificil amanha"]),
           isClimbingContext || mentionsAny(text, ["via", "grau", "amanha"]) {
            return .readiness
        }

        if mentionsAny(text, ["temperatura", "umidade", "clima", "condicoes"]),
           isClimbingContext || mentionsAny(text, ["desempenho", "melhor rendimento", "rendimento"]) {
            return .conditions
        }

        if isClimbingContext,
           mentionsAny(text, ["como estou", "resumo", "meu historico", "historico", "desempenho", "analise"]) {
            return .overview
        }

        return nil
    }

    // MARK: - Resposta

    static func answer(for question: String, context: HealthAssistantContext) -> String {
        let entries = ClimbingAnalytics.entries(from: context.recentWorkoutSessions)
        let intent = intent(for: question) ?? .overview

        // Equipamento não depende de histórico de sessão — responde mesmo sem escaladas registradas.
        if case .gearInspection = intent {
            return withDisclaimer(gearAnswer(context: context))
        }

        guard !entries.isEmpty else {
            return withDisclaimer(emptyHistoryAnswer(name: context.user?.greetingName))
        }

        let body: String
        switch intent {
        case .successByRouteType:
            body = successByRouteTypeAnswer(entries: entries)
        case .gradeProgress(let degree):
            body = gradeProgressAnswer(entries: entries, requestedDegree: degree)
        case .readiness:
            body = readinessAnswer(entries: entries, context: context)
        case .conditions:
            body = conditionsAnswer(entries: entries)
        case .overview:
            body = overviewAnswer(entries: entries)
        case .gearInspection:
            body = gearAnswer(context: context)
        }

        return withDisclaimer(body)
    }

    // MARK: - Respostas por intenção

    private static func successByRouteTypeAnswer(entries: [ClimbingSessionEntry]) -> String {
        let stats = ClimbingAnalytics.disciplineStats(from: entries)
        guard !stats.isEmpty else {
            return "Ainda não tenho tentativas registradas com o tipo de via. Anote as vias durante a sessão para eu comparar boulder, esportiva e tradicional."
        }

        var lines = ["Taxa de sucesso por tipo de via, da menor para a maior:"]
        lines.append(contentsOf: stats.map { stat in
            "• \(stat.discipline.rawValue): \(stat.successPercent)% (\(stat.successCount) de \(stat.attemptCount) tentativas)"
        })

        if let weakest = stats.first {
            lines.append("")
            if weakest.attemptCount < 5 {
                lines.append("\(weakest.discipline.rawValue) aparece na ponta baixa, mas com só \(weakest.attemptCount) tentativas — amostra pequena demais para concluir. Registre mais algumas sessões antes de mudar o treino.")
            } else {
                lines.append("\(weakest.discipline.rawValue) é onde você mais cai: \(weakest.successPercent)% de sucesso em \(weakest.attemptCount) tentativas. \(trainingHint(for: weakest.discipline))")
            }
        }

        if let strongest = stats.last, stats.count > 1, strongest.attemptCount >= 5 {
            lines.append("Seu forte é \(strongest.discipline.rawValue), com \(strongest.successPercent)%.")
        }

        return lines.joined(separator: "\n")
    }

    private static func gradeProgressAnswer(entries: [ClimbingSessionEntry], requestedDegree: Int?) -> String {
        let all = ClimbingAnalytics.degreeProgress(from: entries)
        guard !all.isEmpty else {
            return "Ainda não consigo medir progressão — as tentativas registradas não têm grau associado."
        }

        // Sem grau na pergunta, comenta os dois graus com mais tentativas.
        let selected: [ClimbingDegreeProgress] = {
            if let requestedDegree, let match = all.first(where: { $0.degree == requestedDegree }) {
                return [match]
            }
            if requestedDegree != nil {
                return []
            }
            return Array(all.sorted { $0.attemptCount > $1.attemptCount }.prefix(2)).sorted { $0.degree < $1.degree }
        }()

        if selected.isEmpty, let requestedDegree {
            let available = all.map { "\($0.degree)º" }.joined(separator: ", ")
            return "Não tenho tentativas registradas no \(requestedDegree)º grau. Hoje seus registros estão em: \(available)."
        }

        var lines: [String] = []
        for progress in selected {
            lines.append(describe(progress))
        }

        if let hardest = ClimbingAnalytics.hardestSend(from: entries) {
            lines.append("")
            lines.append("Sua ascensão mais dura até aqui é \(hardest.grade.displayLabel) — \(hardest.displayName), no estilo \(hardest.style.rawValue.lowercased()).")
        }

        return lines.joined(separator: "\n")
    }

    private static func describe(_ progress: ClimbingDegreeProgress) -> String {
        let recent = Int((progress.recentSuccessRate * 100).rounded())
        let earlier = Int((progress.earlierSuccessRate * 100).rounded())

        switch progress.trend {
        case .insufficientData:
            return "\(progress.degree)º grau: \(progress.successCount) sucessos em \(progress.attemptCount) tentativas. Ainda são poucas tentativas para eu falar em tendência — preciso de pelo menos 6."
        case .improving:
            return "\(progress.degree)º grau: sim, você está evoluindo. A taxa de sucesso subiu de \(earlier)% para \(recent)% entre a primeira e a segunda metade das suas tentativas (\(progress.attemptCount) no total)."
        case .stable:
            return "\(progress.degree)º grau: estável em torno de \(recent)% de sucesso, sem mudança relevante frente aos \(earlier)% anteriores. Platô nesse grau costuma pedir variação de estilo, não mais volume."
        case .declining:
            return "\(progress.degree)º grau: a taxa caiu de \(earlier)% para \(recent)%. Vale olhar se você passou a tentar vias mais duras dentro do grau, ou se é fadiga acumulada."
        }
    }

    private static func readinessAnswer(entries: [ClimbingSessionEntry], context: HealthAssistantContext) -> String {
        let readiness = ClimbingAnalytics.readiness(
            entries: entries,
            sleepHours: context.sleepHours,
            hrvMs: context.latestHRVMs
        )

        var lines: [String] = []
        switch readiness.level {
        case .ready:
            lines.append("Leitura de hoje: recuperação adequada para tentar um grau acima amanhã.")
        case .moderate:
            lines.append("Leitura de hoje: recuperação parcial. Dá para tentar a via mais difícil, mas com menos tentativas e aquecimento longo.")
        case .rest:
            lines.append("Leitura de hoje: sua recuperação não está adequada para buscar o limite amanhã.")
        }

        lines.append("")
        lines.append(contentsOf: readiness.reasons.map { "• \($0)" })

        lines.append("")
        switch readiness.level {
        case .ready:
            lines.append("Aqueça com 20 minutos progressivos antes da primeira tentativa séria — dedo frio é o que rompe polia.")
        case .moderate:
            lines.append("Se for tentar, limite a duas ou três tentativas de esforço máximo e pare ao sentir os dedos escorregando sem controle.")
        case .rest:
            lines.append("Um dia de escalada leve, técnica em top rope ou descanso completo rende mais que forçar o grau agora.")
        }

        return lines.joined(separator: "\n")
    }

    private static func gearAnswer(context: HealthAssistantContext) -> String {
        let gear = context.climbingGear
        guard !gear.isEmpty else {
            return "Você ainda não cadastrou equipamento. Abra o diário de escalada e monte o inventário — a partir daí eu acompanho usos e tempo de serviço de corda, costuras, cadeirinha e capacete, e aviso quando chegar a hora da inspeção."
        }

        let overdue = gear.filter { $0.status == .overdue }
        let dueSoon = gear.filter { $0.status == .dueSoon }

        if overdue.isEmpty && dueSoon.isEmpty {
            let next = gear
                .filter { !$0.isRetired }
                .max { $0.wearRatio < $1.wearRatio }
            var text = "Nada vencido: seu equipamento está em dia para a próxima escalada."
            if let next {
                text += "\n\nO próximo a pedir atenção é \(next.name) — \(next.usesRemaining) usos ou \(next.monthsRemaining) meses até a inspeção."
            }
            return text
        }

        var lines: [String] = []

        if !overdue.isEmpty {
            lines.append("Revise antes de subir:")
            lines.append(contentsOf: overdue.map { "• \($0.alertMessage)" })
            lines.append("")
            if let first = overdue.first {
                lines.append("O que olhar em \(first.type.rawValue.lowercased()): \(first.type.inspectionChecklist)")
            }
        }

        if !dueSoon.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append("Chegando no limite:")
            lines.append(contentsOf: dueSoon.map { "• \($0.alertMessage)" })
        }

        lines.append("")
        lines.append("Lembrando que uma queda severa, um corte ou contato com produto químico condena o item na hora, independentemente de usos ou idade.")

        return lines.joined(separator: "\n")
    }

    private static func conditionsAnswer(entries: [ClimbingSessionEntry]) -> String {
        let temperature = ClimbingAnalytics.temperatureBuckets(from: entries)
        let humidity = ClimbingAnalytics.humidityBuckets(from: entries)

        guard !temperature.isEmpty || !humidity.isEmpty else {
            return "Ainda não tenho clima registrado nas suas sessões. Escalando em rocha com o app aberto, eu gravo temperatura e umidade de cada sessão e passo a cruzar isso com sua taxa de sucesso."
        }

        var lines: [String] = []

        if let bestTemp = ClimbingAnalytics.bestBucket(temperature) {
            lines.append("Temperatura: seu melhor desempenho é em \(bestTemp.label), com \(bestTemp.successPercent)% de sucesso em \(bestTemp.attemptCount) tentativas.")
        } else if !temperature.isEmpty {
            lines.append("Temperatura: ainda não tenho faixa com amostra suficiente (preciso de pelo menos 4 tentativas por faixa) para apontar sua melhor janela.")
        }

        if let bestHumidity = ClimbingAnalytics.bestBucket(humidity) {
            lines.append("Umidade: você rende mais em ar \(bestHumidity.label.lowercased()), com \(bestHumidity.successPercent)% em \(bestHumidity.attemptCount) tentativas.")
        } else if !humidity.isEmpty {
            lines.append("Umidade: amostra ainda pequena por faixa para eu cravar um padrão.")
        }

        if !temperature.isEmpty {
            lines.append("")
            lines.append("Detalhe por faixa de temperatura:")
            lines.append(contentsOf: temperature.map { "• \($0.label): \($0.successPercent)% (\($0.attemptCount) tentativas)" })
        }

        lines.append("")
        lines.append("Como referência física, a borracha da sapatilha e a pele aderem melhor no frio e no seco — é por isso que a temporada de projetos duros costuma ser o inverno.")

        return lines.joined(separator: "\n")
    }

    private static func overviewAnswer(entries: [ClimbingSessionEntry]) -> String {
        let attempts = ClimbingAnalytics.allAttempts(from: entries)
        let successes = attempts.filter(\.isSuccess).count
        let weeks = ClimbingAnalytics.weeklyVolume(from: entries, weeks: 4)
        let activeMinutes = entries.reduce(0) { $0 + $1.snapshot.activeClimbingSeconds } / 60

        var lines = ["Resumo das suas \(entries.count) sessões de escalada registradas:"]
        lines.append("• \(attempts.count) tentativas, \(successes) encadenadas (\(percent(successes, of: attempts.count))%)")
        lines.append("• \(activeMinutes) minutos de tempo efetivo em parede")

        if let hardest = ClimbingAnalytics.hardestSend(from: entries) {
            lines.append("• Ascensão mais dura: \(hardest.grade.displayLabel) em \(hardest.displayName)")
        }

        if let lastWeek = weeks.last {
            lines.append("• Última semana: \(lastWeek.sessionCount) sessões e \(lastWeek.attemptCount) tentativas")
        }

        if let weakest = ClimbingAnalytics.disciplineStats(from: entries).first, weakest.attemptCount >= 5 {
            lines.append("")
            lines.append("Seu ponto fraco atual é \(weakest.discipline.rawValue), com \(weakest.successPercent)% de sucesso.")
        }

        return lines.joined(separator: "\n")
    }

    private static func emptyHistoryAnswer(name: String?) -> String {
        let greeting = name.map { "\($0), " } ?? ""
        return "\(greeting)ainda não tenho sessões de escalada registradas para analisar. Comece uma escalada em Cardio → Escalada e registre suas vias com grau e estilo. Com algumas sessões eu consigo te dizer onde você mais cai, se está evoluindo em cada grau e em quais condições de temperatura e umidade você rende melhor."
    }

    // MARK: - Helpers

    private static func trainingHint(for discipline: ClimbingDiscipline) -> String {
        switch discipline {
        case .boulder:
            return "Boulder cobra força máxima e leitura de movimento — vale sessão específica de força de dedo e treino de coordenação em blocos curtos."
        case .sport:
            return "Em esportiva, cair muito costuma ser resistência, não força: treine séries longas com pouco descanso e trabalhe a leitura da via do chão."
        case .trad:
            return "Na tradicional, boa parte do fracasso vem do tempo gasto colocando proteção. Treine a colocação em terreno fácil até ficar automática."
        case .gym:
            return "No ginásio dá para isolar o que falha: repita as vias que você caiu no mesmo dia, com descanso completo entre as tentativas."
        case .multipitch:
            return "Via longa cobra logística e ritmo. Treine manobras de parada e rapel até ficarem rápidas, e escale com margem de grau."
        case .ice:
            return "No gelo, economia de movimento vale mais que força: trabalhe a precisão da picada para não gastar o antebraço."
        }
    }

    private static func percent(_ value: Int, of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int(((Double(value) / Double(total)) * 100).rounded())
    }

    private static func withDisclaimer(_ body: String) -> String {
        "\(body)\n\n\(HealthAssistantEngine.healthSafetyDisclaimer)"
    }

    /// "6º", "6 grau", "sexto" → 6.
    private static func parseDegree(_ text: String) -> Int? {
        let named: [String: Int] = [
            "quarto": 4, "quinto": 5, "sexto": 6, "setimo": 7, "oitavo": 8, "nono": 9
        ]
        for (word, value) in named where text.contains(word) {
            return value
        }

        // Aceita "6o", "6º", "6 grau", "grau 6".
        let pattern = #"(\d)\s*(?:o\b|º|grau)|grau\s*(\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        for index in 1..<match.numberOfRanges {
            guard let captured = Range(match.range(at: index), in: text) else { continue }
            if let value = Int(text[captured]), (3...9).contains(value) {
                return value
            }
        }
        return nil
    }

    private static let climbingWords = [
        "escalada", "escalar", "escalando", "via", "vias", "boulder", "grau", "graus",
        "encadenar", "encadenei", "costura", "cadeirinha", "parede", "rocha"
    ]

    private static let gearWords = [
        "equipamento", "corda", "costura", "costuras", "cadeirinha", "mosquetao",
        "capacete", "fita", "crash pad", "sapatilha", "freio", "material"
    ]

    private static let inspectionWords = [
        "revisar", "inspecionar", "inspecao", "trocar", "aposentar", "vencido",
        "vida util", "checar", "verificar", "preciso revisar"
    ]

    private static func mentionsAny(_ text: String, _ words: [String]) -> Bool {
        words.contains { text.contains($0) }
    }

    /// Minúsculas sem acento, para casar a pergunta escrita de qualquer jeito.
    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
