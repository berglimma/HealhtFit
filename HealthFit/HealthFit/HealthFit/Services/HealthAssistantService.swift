import Foundation
import UIKit

import Combine
struct HealthChatMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date

    init(id: UUID = UUID(), text: String, isUser: Bool, timestamp: Date = .now) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

struct HealthAssistantContext {
    let user: UserProfile?
    let waterIntakeMl: Int
    let sleepHours: Double?
    let weeklyWorkoutCount: Int
    let hoursSinceLastWorkout: Double?
    let todayWorkoutSessions: [WorkoutSession]
    /// Histórico recente de sessões (`WorkoutStore.sessionHistory`) para análise de progresso.
    let recentWorkoutSessions: [WorkoutSession]
    let dailyCalorieTarget: Int
    let basalMetabolicRate: Int
    let estimatedTDEE: Int
    let caloricDeficit: Int
    let sweetConsumption: SweetConsumptionLevel
    let lactoseTolerance: LactoseTolerance?
    /// Há cardápio semanal gerado no app.
    let hasMealPlan: Bool
    let todayMealsCompleted: Int
    let todayMealsTotal: Int
    let weekMealsCompleted: Int
    let weekMealsTotal: Int
    let supplementsLoggedToday: Int
}

enum HealthAssistantEngine {
    static let idleReturnMessage = "Vi que você está focado em outra demanda, qualquer dúvida estou à disposição, bom treino e foco sempre, você vai vencer!"

    /// Aviso de segurança exibido nas mensagens do IAssistente.
    static let healthSafetyDisclaimer =
        "Importante: em caso de qualquer dúvida, desconforto ou dor no exercício, procure um profissional de saúde qualificado e habilitado. " +
        "Se sentir dor, mal-estar, tontura ou sintoma preocupante, busque atendimento imediatamente. " +
        "Não use ferramentas de IA (incluindo este assistente) para diagnóstico, tratamento ou decisão médica."

    static let suggestedQuestions: [String] = [
        "Montar treino sem personal",
        "Treino em casa funciona?",
        "Como treinar em casa sem equipamento?",
        "Qual é meu IMC?",
        "O que é ectomorfo?",
        "O que é mesomorfo?",
        "O que é endomorfo?",
        "Como dormir corretamente?",
        "Como treinar conforme o personal?",
        "Quanto de proteína comer?",
        "Quantas séries e repetições?",
        "O que fazer no déficit calórico?",
        "Posso beber álcool ou cerveja?",
        "Cerveja zero álcool é liberada?",
        "Cerveja light faz mal?",
        "Treino, cardio ou meditação?",
        "Quais suplementos devo tomar?",
        "Para que serve a creatina?",
        "Whey protein faz mal?",
        "Como está minha evolução corporal?",
        "O que preciso melhorar?",
    ]

    static func welcomeMessage(context: HealthAssistantContext) -> String {
        let greeting = MotivationMessages.namedGreeting(name: context.user?.greetingName)
        var sections = ["\(greeting) Sou o assistente HealthFit.", ""]

        let summary = buildWelcomeAlerts(context)
        if !summary.messages.isEmpty {
            sections.append("Atenção ao seu dia:")
            summary.messages.forEach { sections.append("• \($0)") }
            sections.append("")
            sections.append(
                MotivationMessages.chatWelcomeMotivation(
                    hasSleepAlert: summary.hasSleepIssue,
                    hasWaterAlert: summary.hasWaterIssue,
                    hasWorkoutAlert: summary.hasWorkoutIssue
                )
            )
            sections.append("")
        } else {
            sections.append(MotivationMessages.dailyMessage())
            sections.append("")
        }

        sections.append("Posso tirar dúvidas sobre dieta, IMC, biotipos (ecto/meso/endo), sono, treinos (academia ou em casa), cardio, meditação, macros, suplementação, álcool e evolução corporal (fotos e medidas).")
        sections.append("")
        sections.append(healthSafetyDisclaimer)
        sections.append("")
        sections.append("Toque em uma sugestão abaixo ou escreva sua pergunta.")

        return sections.joined(separator: "\n")
    }

    private struct WelcomeAlertSummary {
        let messages: [String]
        let hasSleepIssue: Bool
        let hasWaterIssue: Bool
        let hasWorkoutIssue: Bool
    }

    private static func buildWelcomeAlerts(_ context: HealthAssistantContext) -> WelcomeAlertSummary {
        var alerts: [String] = []
        var hasSleepIssue = false
        var hasWaterIssue = false
        var hasWorkoutIssue = false

        if let hours = context.sleepHours {
            let formatted = String(format: "%.1f", hours)
            switch SleepAssessment.evaluate(hours: hours) {
            case .unregulated:
                hasSleepIssue = true
                alerts.append("Sono desregulado: você registrou \(formatted) h. O ideal é 7–9 h — priorize descanso para recuperar dos treinos.")
            case .needsMore:
                hasSleepIssue = true
                alerts.append("Sono abaixo do ideal: \(formatted) h registradas. Tente dormir entre 7 e 9 horas por noite.")
            case .aboveRecommended:
                hasSleepIssue = true
                alerts.append("Sono acima do recomendado: \(formatted) h. O ideal é 7–9 h — avalie se há fadiga ou rotina irregular.")
            case .ideal:
                break
            }
        }

        if let user = context.user {
            let goal = user.recommendedDailyWaterML
            let current = context.waterIntakeMl
            if goal > 0, current < goal {
                hasWaterIssue = true
                let remaining = goal - current
                let pct = Int((Double(current) / Double(goal) * 100).rounded())
                if pct < 50 {
                    alerts.append("Hidratação baixa: apenas \(current) ml de \(goal) ml (\(pct)% da meta). Beba água ao longo do dia.")
                } else {
                    alerts.append("Meta de água não atingida: \(current) ml de \(goal) ml. Faltam \(remaining) ml.")
                }
            }
        }

        if context.weeklyWorkoutCount == 0 {
            hasWorkoutIssue = true
            if let hours = context.hoursSinceLastWorkout, hours >= 48 {
                let days = max(Int(hours / 24), 2)
                alerts.append("Treinos: nenhum registrado nos últimos 7 dias. Faz \(days) dias desde o último treino.")
            } else if context.hoursSinceLastWorkout == nil {
                alerts.append("Treinos: nenhum treino registrado ainda. Comece na aba Treinos!")
            } else {
                alerts.append("Treinos: nenhum treino registrado nos últimos 7 dias.")
            }
        } else if let hours = context.hoursSinceLastWorkout, hours >= 48 {
            hasWorkoutIssue = true
            let days = max(Int(hours / 24), 2)
            alerts.append("Treinos: faz \(days) dia(s) desde seu último treino. O ideal é manter a consistência semanal.")
        } else if context.weeklyWorkoutCount < 3 {
            hasWorkoutIssue = true
            let label = context.weeklyWorkoutCount == 1 ? "treino" : "treinos"
            alerts.append("Treinos: apenas \(context.weeklyWorkoutCount) \(label) esta semana. O ideal é pelo menos 3.")
        }

        if let tideWelcome = AssistantTideAlertEngine.welcomeAlertIfNeeded(
            sessions: context.recentWorkoutSessions,
            snapshot: nil
        ) {
            alerts.append(tideWelcome)
        }

        return WelcomeAlertSummary(
            messages: alerts,
            hasSleepIssue: hasSleepIssue,
            hasWaterIssue: hasWaterIssue,
            hasWorkoutIssue: hasWorkoutIssue
        )
    }

    static func welcomeMessage(for name: String?) -> String {
        welcomeMessage(context: HealthAssistantContext(
            user: name.map { UserProfile(name: $0, email: "") },
            waterIntakeMl: 0,
            sleepHours: nil,
            weeklyWorkoutCount: 0,
            hoursSinceLastWorkout: nil,
            todayWorkoutSessions: [],
            recentWorkoutSessions: [],
            dailyCalorieTarget: 0,
            basalMetabolicRate: 0,
            estimatedTDEE: 0,
            caloricDeficit: 0,
            sweetConsumption: .moderate,
            lactoseTolerance: nil,
            hasMealPlan: false,
            todayMealsCompleted: 0,
            todayMealsTotal: 0,
            weekMealsCompleted: 0,
            weekMealsTotal: 0,
            supplementsLoggedToday: 0
        ))
    }

    static func answer(for question: String, context: HealthAssistantContext) -> String {
        if AssistantImprovementAnalysisEngine.matches(question) {
            return AssistantImprovementAnalysisEngine.answer(context: context)
        }

        let normalized = normalize(question)
        let scores = topics.map { topic -> (HealthAssistantTopic, Int) in
            let score = topic.keywords.reduce(0) { partial, keyword in
                normalized.contains(keyword) ? partial + keyword.count : partial
            }
            return (topic, score)
        }
        .sorted { $0.1 > $1.1 }

        if let best = scores.first, best.1 > 0 {
            return best.0.respond(context)
        }

        return fallbackAnswer(context)
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
    }

    private static func fallbackAnswer(_ context: HealthAssistantContext) -> String {
        var lines = [
            "Não encontrei uma resposta exata, mas posso ajudar com estes temas:",
            "• Dieta: cardápio, macros, proteína, carboidrato, açúcar, lactose e álcool",
            "• IMC, peso, altura e composição corporal",
            "• Biotipos: ectomorfo, mesomorfo e endomorfo",
            "• Sono e recuperação",
            "• Treinos conforme orientação do personal",
            "• Suplementação: whey, creatina, pré-treino, ômega 3 e mais",
            "",
            healthSafetyDisclaimer,
            "",
            "Reformule a pergunta ou toque em uma sugestão abaixo."
        ]
        if let user = context.user {
            lines.insert("Seu objetivo: \(user.goal.rawValue). IMC: \(String(format: "%.1f", user.bmi)). Meta: \(context.dailyCalorieTarget) kcal/dia.", at: 1)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func bmiInfo(for user: UserProfile) -> (label: String, advice: String) {
        let bmi = user.bmi
        switch bmi {
        case ..<18.5:
            return (
                "Abaixo do peso",
                "Priorize superávit calórico moderado, proteína adequada e treino de força para ganhar massa com saúde."
            )
        case 18.5..<25:
            return (
                "Peso normal",
                "Mantenha hábitos equilibrados. Ajuste calorias conforme objetivo (ganho, perda ou manutenção)."
            )
        case 25..<30:
            return (
                "Sobrepeso",
                "Déficit calórico moderado + treino de força ajudam a reduzir gordura preservando músculo."
            )
        case 30..<35:
            return (
                "Obesidade grau I",
                "Combine alimentação controlada, movimento regular e acompanhamento profissional se possível."
            )
        case 35..<40:
            return (
                "Obesidade grau II",
                "Priorize hábitos sustentáveis. Evite dietas extremas; busque orientação médica/nutricional."
            )
        default:
            return (
                "Obesidade grau III",
                "Recomendamos acompanhamento de profissionais de saúde para um plano seguro e personalizado."
            )
        }
    }

    private static func proteinRecommendation(for user: UserProfile, calories: Int) -> String {
        let gramsPerKg: Double
        switch user.goal {
        case .muscleGain: gramsPerKg = 2.0
        case .fatLoss: gramsPerKg = 2.2
        case .endurance: gramsPerKg = 1.6
        case .maintenance: gramsPerKg = 1.8
        }
        let grams = Int((user.weight * gramsPerKg).rounded())
        let kcal = grams * 4
        let pct = calories > 0 ? Int((Double(kcal) / Double(calories) * 100).rounded()) : 0
        return "Sugestão: ~\(grams) g/dia (~\(gramsPerKg) g/kg). Isso representa cerca de \(kcal) kcal (\(pct)% da meta)."
    }

    private static func goalTrainingSummary(_ goal: FitnessGoal) -> String {
        switch goal {
        case .muscleGain:
            return "3–5 treinos de força/semana, progressão de carga, superávit calórico e proteína alta."
        case .fatLoss:
            return "3–4 treinos de força/semana + déficit calórico. Cardio 2–3x opcional."
        case .endurance:
            return "3–4 sessões de cardio/semana + 2 treinos de força para prevenir lesões."
        case .maintenance:
            return "2–4 treinos/semana equilibrados entre força e cardio leve."
        }
    }

    private static func ectomorphDefinition(isUserType: Bool) -> String {
        let prefix = isUserType ? "Seu biotipo é ectomorfo.\n\n" : ""
        return """
        \(prefix)Ectomorfo — definição:
        Somatotipo caracterizado por estrutura corporal magra, ossatura fina e metabolismo acelerado. Tende a ter dificuldade em ganhar peso e massa muscular.

        Características:
        • Corpo esguio, ombros e quadris estreitos
        • Pulsos e tornozelos finos
        • Ganha pouco peso mesmo comendo bastante
        • Metabolismo acelerado (+10% no TDEE no app)

        Alimentação: superávit calórico moderado, proteína alta, refeições frequentes.
        Treino: musculação 3–5x/semana com progressão de carga; cardio leve e curto.
        """
    }

    private static func mesomorphDefinition(isUserType: Bool) -> String {
        let prefix = isUserType ? "Seu biotipo é mesomorfo.\n\n" : ""
        return """
        \(prefix)Mesomorfo — definição:
        Somatotipo atlético, com facilidade natural para ganhar músculo e perder gordura. Estrutura corporal equilibrada e boa resposta ao treino.

        Características:
        • Ombros largos e cintura marcada
        • Estrutura muscular visível
        • Ganha músculo e perde gordura com relativa facilidade
        • TDEE padrão no app (sem ajuste extra)

        Alimentação: balanceada conforme objetivo (superávit para massa, déficit para cutting).
        Treino: responde bem a volume moderado-alto; combine força e cardio.
        """
    }

    private static func endomorphDefinition(isUserType: Bool) -> String {
        let prefix = isUserType ? "Seu biotipo é endomorfo.\n\n" : ""
        return """
        \(prefix)Endomorfo — definição:
        Somatotipo com tendência a acumular gordura, estrutura mais arredondada e metabolismo mais lento. Ganha peso com mais facilidade.

        Características:
        • Estrutura arredondada, cintura e quadril mais largos
        • Acumula gordura com facilidade
        • Ganha peso mais rápido que os outros biotipos
        • Metabolismo mais lento (−10% no TDEE no app)

        Alimentação: controle calórico, proteína alta, menos ultraprocessados e frituras.
        Treino: musculação + cardio regular; consistência é chave.
        """
    }

    private static func sleepStatusLine(hours: Double?) -> String {
        guard let hours else {
            return "Registre suas horas de sono no check-in diário para acompanhar."
        }
        let assessment = SleepAssessment.evaluate(hours: hours)
        return "Hoje você registrou \(String(format: "%.1f", hours)) h — \(assessment.title.lowercased()). \(assessment.message)"
    }

    private static let supplementTopics: [HealthAssistantTopic] = SupplementationGuideEngine.assistantTopics().map {
        HealthAssistantTopic(keywords: $0.keywords, respond: $0.respond)
    }

    private static let topics: [HealthAssistantTopic] = steroidTopics + supplementTopics + dietTopics + imcTopics + bodyEvolutionTopics + workoutTopics + biotypeTopics + generalTopics

    // MARK: - Esteróides anabolizantes (alerta de saúde)

    private static let steroidTopics: [HealthAssistantTopic] = [
        HealthAssistantTopic(
            keywords: [
                "esteroides anabolizantes", "esteróides anabolizantes", "esteroides anabolicos", "esteróides anabólicos",
                "anabolizante", "anabolizantes", "anabolico", "anabólico", "anabolico androgenico", "anabólico androgênico",
                "hormonio anabolico", "hormônio anabólico", "uso de esteroides", "ciclo de esteroides", "ciclo de hormonio",
                "ciclo de hormônio", "ciclo de bomba", "fazer ciclo", "iniciar ciclo", "efetuar um ciclo", "efetuar ciclo",
                "quero efetuar um ciclo", "quero fazer um ciclo", "quero iniciar um ciclo", "quero comecar um ciclo",
                "quero começar um ciclo", "montar um ciclo", "primeiro ciclo", "meu primeiro ciclo",
                "ciclar", "quero ciclar", "vou ciclar", "posso ciclar", "como ciclar", "ta ciclando", "tá ciclando",
                "ciclado", "ciclada", "to ciclando", "tô ciclando", "ciclo de bulking", "ciclo de cutting",
                "tomar suco", "quero tomar suco", "vou tomar suco", "tomei suco", "pegar suco", "usar suco",
                "suco anabolico", "suco anabólico", "suco hormonal", "suco de bomba", "suco no ciclo",
                "pct esteroide", "trt ilegal",
                "testosterona exógena", "testosterona exogena", "testosterona sintetica", "testosterona sintética",
                "testosterona", "testo enantato", "testo cipionato", "testo propionato", "enantato de testosterona",
                "cipionato de testosterona", "propionato de testosterona", "undecanoato de testosterona", "sustanon",
                "durateston", "nandrolona", "deca durabolin", "deca-durabolin", "deca durabolin", "deca",
                "decanoato de nandrolona", "trenbolona", "trenbolone", "acetato de trenbolona", "enantato de trenbolona",
                "tren ace", "tren e", "boldenona", "equipoise", "stanozolol", "winstrol", "oxandrolona", "anavar",
                "metandienona", "metandrostenolona", "dianabol", "d-bol", "dbol", "oximetolona", "hemogenin", "anadrol",
                "fluoxymesterone", "fluoximesterona", "halotestin", "mesterolona", "proviron", "turinabol",
                "clorodehidrometiltestosterona", "metenolona", "methenolone", "primobolan", "primo",
                "drostanolona", "masteron", "metiltestosterona", "superdrol", "metasterona", "turinabol",
                "oximetolona", "stanozolol injetavel", "stanozolol injetável", "bomba de ferro", "bomba hormonal",
                "peptideo de crescimento ilegal", "hgh ilegal", "hormonio do crescimento ilegal", "sarm ilegal",
                "ostarine", "ligandrol", "rad 140", "rad-140", "cardarine", "yk-11", "andarine",
                "prohormona", "pro-hormona", "designer steroid", "esteroides orais", "esteroides injetaveis",
                "esteroides injetáveis", "stack de esteroides", "stack anabolico", "stack anabólico"
            ],
            respond: { _ in anabolicSteroidsWarning() }
        ),
    ]

    private static func anabolicSteroidsWarning() -> String {
        """
        ⚠️ ALERTA DE SAÚDE — ESTERÓIDES ANABOLIZANTES

        O HealthFit NÃO recomenda, NÃO orienta e NÃO incentiva o uso de esteróides anabolizantes.
        Jamais faça uso por conta própria. Isso prejudica o corpo de forma grave e, muitas vezes, irreversível.
        Procure um médico (endocrinologista ou médico do esporte) para qualquer dúvida sobre hormônios.

        O uso sem prescrição e acompanhamento médico é ilegal no Brasil e pode causar danos permanentes.

        Principais esteróides anabolizantes (todos com riscos sérios):
        • Testosterona e ésteres — enantato, cipionato, propionato, undecanoato, Sustanon/Durateston
        • Nandrolona — Deca-Durabolin (decanoato de nandrolona)
        • Trenbolona — acetato, enantato (Tren)
        • Boldenona — Equipoise
        • Stanozolol — Winstrol (oral e injetável)
        • Oxandrolona — Anavar
        • Metandienona — Dianabol (D-Bol)
        • Oximetolona — Hemogenin/Anadrol
        • Fluoximesterona — Halotestin
        • Mesterolona — Proviron
        • Turinabol (clorodehidrometiltestosterona)
        • Metenolona — Primobolan
        • Drostanolona — Masteron
        • Metiltestosterona
        • Metasterona — Superdrol
        • Outros andrógenos sintéticos e “designer steroids”

        Substâncias frequentemente associadas (também perigosas sem supervisão):
        • SARMs (ostarine, ligandrol, RAD-140, andarine, etc.)
        • Pro-hormônias
        • Hormônio do crescimento (HGH) usado de forma ilegal

        Riscos ao corpo:
        • Coração — hipertensão, arritmias, infarto, AVC, colesterol alterado
        • Fígado — hepatotoxicidade, icterícia, tumores
        • Hormônios — queda da produção natural de testosterona, infertilidade, ginecomastia
        • Pele e cabelo — acne severa, queda de cabelo, estrias
        • Psique — agressividade, ansiedade, depressão, dependência
        • Sistema reprodutor — atrofia testicular, queda de libido, alterações menstruais
        • Crescimento — fechamento precoce de placa óssea em jovens
        • Infecções — abscessos e contaminação por agulhas compartilhadas
        • Legal e esportivo — sanções, doping, prisão

        O que fazer em vez disso:
        • Treino progressivo com orientação profissional
        • Dieta adequada com proteína, carboidrato e gordura de qualidade
        • Sono de 7–9 horas por noite
        • Suplementos seguros (creatina, whey, ômega 3) com orientação profissional

        Repetindo: jamais use esteróides anabolizantes por conta própria. Procure um médico.
        Ganhos rápidos com hormônios não valem a saúde destruída.
        """
    }

    // MARK: - Dieta

    private static let dietTopics: [HealthAssistantTopic] = [
        HealthAssistantTopic(
            keywords: ["cardapio", "refeicao", "refeição", "dieta", "nutricao", "nutrição", "compras", "lista", "montar", "alimentacao", "alimentação"],
            respond: { ctx in
                let lactose = ctx.lactoseTolerance?.rawValue ?? "não informada"
                let sweet = ctx.sweetConsumption.rawValue
                let goal = ctx.user?.goal.rawValue ?? "seu objetivo"
                return """
                Seu cardápio no HealthFit é montado com base no objetivo (\(goal)), biotipo, TMB e preferências.

                • 6 refeições: café, lanches, almoço, janta e ceia
                • Consumo de doces: \(sweet)
                • Tolerância à lactose: \(lactose)
                • Meta calórica: \(ctx.dailyCalorieTarget) kcal/dia

                Na aba Nutrição você monta o cardápio e gera a lista de compras (proteínas, frutas, grãos e suplementos).

                Para perda de gordura, há opções mais restritivas com menos carboidrato e sem frituras.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["proteina", "proteína", "proteinas", "proteínas", "whey", "carne", "frango", "ovo", "ovos"],
            respond: { ctx in
                guard let user = ctx.user else {
                    return """
                    Proteína é essencial para músculos, saciedade e recuperação.
                    • Ganho de massa: ~1,6–2,2 g/kg/dia
                    • Perda de gordura: ~2,0–2,4 g/kg/dia
                    • Manutenção: ~1,6–2,0 g/kg/dia

                    Complete seu perfil para ver a meta personalizada.
                    """
                }
                return """
                Proteína constrói e preserva músculo, aumenta saciedade e acelera recuperação pós-treino.

                \(proteinRecommendation(for: user, calories: ctx.dailyCalorieTarget))

                Fontes no cardápio: frango, carne magra, peixe, ovos, iogurte (se tolera lactose), whey e leguminosas.

                Distribua ao longo do dia — café, almoço, janta e lanches.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["carboidrato", "carbo", "carbos", "arroz", "pao", "pão", "macarrao", "macarrão", "batata", "aveia"],
            respond: { ctx in
                let goal = ctx.user?.goal ?? .maintenance
                let advice: String
                switch goal {
                case .muscleGain:
                    advice = "Carboidratos são importantes para energia nos treinos e recuperação. Inclua arroz, batata, aveia e frutas."
                case .fatLoss:
                    advice = "Carboidratos não são vilões — controle porções e priorize integrais. Reduza em jantar/ceia se necessário."
                case .endurance:
                    advice = "Carboidratos são sua principal fonte de energia para cardio e resistência."
                case .maintenance:
                    advice = "Mantenha carboidratos equilibrados: integrais, frutas e legumes."
                }
                return """
                Carboidratos fornecem energia para treinos e funções cerebrais.

                Objetivo (\(goal.rawValue)): \(advice)

                Meta calórica: \(ctx.dailyCalorieTarget) kcal/dia.
                Tipicamente 40–55% das calorias vêm de carboidratos, ajustados ao objetivo.

                Prefira: arroz integral, batata doce, aveia, frutas e pães integrais. Evite excesso de ultraprocessados e frituras.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["gordura", "gorduras", "lipidio", "lipídio", "oleo", "óleo", "azeite", "abacate"],
            respond: { ctx in
                return """
                Gorduras são essenciais para hormônios, absorção de vitaminas e saúde cerebral.

                Tipos:
                • Insaturadas (azeite, abacate, castanhas, peixes) — priorize
                • Saturadas (carnes, manteiga) — moderação
                • Trans (industrializados, frituras) — evite

                Meta: cerca de 20–35% das calorias diárias (\(ctx.dailyCalorieTarget) kcal → ~\(Int(Double(ctx.dailyCalorieTarget) * 0.25 / 9)) g/dia de gordura).

                No cardápio de perda de gordura, reduzimos frituras e opções muito gordurosas.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["macro", "macronutriente", "macronutrientes", "distribuicao", "distribuição"],
            respond: { ctx in
                guard let user = ctx.user else {
                    return "Macronutrientes são proteína, carboidrato e gordura. Configure seu perfil para ver a distribuição sugerida."
                }
                let cal = ctx.dailyCalorieTarget
                let proteinG = Int((user.weight * 2.0).rounded())
                let proteinKcal = proteinG * 4
                let fatKcal = Int(Double(cal) * 0.25)
                let fatG = fatKcal / 9
                let carbKcal = max(cal - proteinKcal - fatKcal, 0)
                let carbG = carbKcal / 4
                return """
                Macronutrientes na sua meta (\(cal) kcal/dia):

                • Proteína: ~\(proteinG) g (\(proteinKcal) kcal)
                • Gordura: ~\(fatG) g (\(fatKcal) kcal)
                • Carboidrato: ~\(carbG) g (\(carbKcal) kcal)

                Objetivo: \(user.goal.rawValue).

                O cardápio do app distribui isso em 6 refeições. Ajuste doces e lactose em Nutrição.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["cafe da manha", "café da manhã", "cafe", "café da manha", "breakfast"],
            respond: { ctx in
                return """
                Café da manhã (~20% das calorias ≈ \(Int(Double(ctx.dailyCalorieTarget) * 0.20)) kcal).

                Função: quebrar o jejum noturno, energia para o dia e proteína matinal.

                Opções no app: ovos, aveia, frutas, pão integral, iogurte (conforme lactose).

                Dica: inclua proteína no café — ajuda na saciedade e no ganho muscular.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["almoco", "almoço", "lunch"],
            respond: { ctx in
                return """
                Almoço (~30% das calorias ≈ \(Int(Double(ctx.dailyCalorieTarget) * 0.30)) kcal) — refeição principal.

                Estrutura ideal:
                • Proteína (carne, frango, peixe, leguminosas)
                • Carboidrato (arroz, batata, macarrão integral)
                • Vegetais e salada
                • Gordura boa (azeite)

                No app, escolha opções alinhadas ao objetivo \(ctx.user?.goal.rawValue.lowercased() ?? "atual").
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["jantar", "janta", "jantar", "ceia", "supper", "dinner"],
            respond: { ctx in
                let isFatLoss = ctx.user?.goal == .fatLoss
                return """
                Jantar (~22%) e ceia (~8%) completam o dia.

                Jantar: ~\(Int(Double(ctx.dailyCalorieTarget) * 0.22)) kcal
                Ceia: ~\(Int(Double(ctx.dailyCalorieTarget) * 0.08)) kcal

                \(isFatLoss ? "Em perda de gordura: jantar mais leve, menos carboidrato e sem fritura." : "Mantenha proteína no jantar para recuperação noturna.")

                Ceia: opções leves — iogurte, fruta ou whey — ajudam a evitar fome noturna.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["lanche", "snack", "lanche da tarde", "lanche manha"],
            respond: { ctx in
                return """
                Lanches (~10% cada ≈ \(Int(Double(ctx.dailyCalorieTarget) * 0.10)) kcal) mantêm energia estável entre refeições.

                Ideias no cardápio: frutas, castanhas, iogurte, whey, sanduíche integral.

                Evite pular lanches se treina à tarde — você precisa de combustível antes do treino.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["acucar", "doce", "doces", "açucar", "sobremesa", "docinho"],
            respond: { ctx in
                let level = ctx.sweetConsumption
                return """
                Consumo de açúcar no seu plano: \(level.rawValue).
                \(level.detail)

                A OMS recomenda limitar açúcares livres a menos de 10% das calorias (idealmente 5%). Em 2000 kcal: até 50 g (10%) ou 25 g (5%).

                Prefira frutas, aveia e doces ocasionais. Ajuste em Nutrição → "Você consome muito doce?".
                """
            }
        ),
        HealthAssistantTopic(
            keywords: [
                "alcool", "álcool", "alcoolica", "alcoólica", "beber alcool", "beber álcool",
                "cerveja", "cervejas", "chopp", "chope", "vinho", "vodka", "whisky", "uisque",
                "destilada", "destiladas", "bebida alcoolica", "bebida alcoólica", "drinque", "drink",
                "caipirinha", "gin", "rum", "tequila", "pinga", "cachaca", "cachaça", "bebida destilada"
            ],
            respond: { ctx in
                let goal = ctx.user?.goal.rawValue ?? "seu objetivo"
                let calorieNote = "Sua meta: \(ctx.dailyCalorieTarget) kcal/dia."
                return """
                Álcool, cerveja e bebidas destiladas têm influência negativa relevante no plano (\(goal)).

                Por que prejudica:
                • Calorias vazias — o corpo queima álcool antes de gordura (atrapalha perda de peso)
                • Cerveja: ~90–180 kcal/lata + carboidratos; destilados: ~70–100 kcal/dose (40 ml), mas o efeito do etanol é maior por concentração
                • Reduz síntese proteica e recuperação muscular pós-treino
                • Piora sono (menos REM), desidrata e aumenta fome no dia seguinte
                • Em excesso: fígado, pressão arterial e adesão à dieta caem

                \(calorieNote)

                Se for consumir (não é recomendado em fase de cutting):
                • Máximo ocasional — não é parte do cardápio HealthFit
                • Evite no dia de treino intenso ou antes de dormir
                • Não compense "comendo menos" no dia — priorize proteína e água
                • Destilados com calorias de mixers (refrigerante, suco) somam ainda mais

                Para ganho de massa ou perda de gordura, menos álcool = melhor resultado.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: [
                "cerveja zero", "zero alcool", "zero álcool", "sem alcool", "sem álcool",
                "nao alcoolica", "não alcoólica", "cerveja sem alcool", "cerveja sem álcool",
                "heineken 0", "brahma 0", "antarctica 0", "bebida zero alcool"
            ],
            respond: { ctx in
                return """
                Cerveja zero álcool — o que pode e o que não pode:

                ✅ Pode (com moderação):
                • Opção social sem etanol — não intoxica nem prejudica o fígado como álcool
                • Geralmente menos calorias que cerveja comum (~15–35 kcal/100 ml vs ~40–50)
                • Cabe melhor na meta de \(ctx.dailyCalorieTarget) kcal/dia se contabilizar no dia
                • Hidratação levemente melhor que cerveja alcoólica (sem efeito diurético do álcool)

                ❌ Não pode / cuidados:
                • Não é "liberado à vontade" — ainda tem carboidrato, sódio e calorias
                • Pode conter açúcar ou maltose — leia o rótulo
                • Não substitui água, leite ou refeições
                • Algumas marcas têm traços de álcool (<0,5%) — atletas em competição devem verificar
                • Pode manter hábito de "cerveja todo dia" — o ideal é ocasional

                Resumo: melhor que cerveja comum para saúde e dieta, mas trate como bebida calórica ocasional, não como hidratação ou suplemento.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: [
                "cerveja light", "cerveja diet", "cerveja baixa caloria", "cerveja baixa calorias",
                "cerveja low carb", "pode cerveja light", "cerveja menos calorias", "cerveja light faz mal"
            ],
            respond: { ctx in
                let goal = ctx.user?.goal.rawValue ?? "seu objetivo"
                return """
                Cerveja light / de baixa caloria — pontos positivos e negativos:

                👍 Influência positiva (relativa):
                • Menos calorias que cerveja tradicional (~80–100 kcal/lata vs ~140–180)
                • Facilita encaixar 1 unidade ocasional na meta de \(ctx.dailyCalorieTarget) kcal/dia
                • Pode ser escolha "menos pior" em eventos sociais (objetivo: \(goal))

                👎 Influência negativa (ainda presente):
                • Continua com álcool — etanol segue atrapalhando queima de gordura e recuperação
                • Álcool permanece (~3,5–4,5%) — efeito no sono, fígado e treino é similar
                • Risco de beber mais unidades ("é light, então pode mais")
                • Carboidratos e sódio ainda existem; pouca proteína ou nutriente útil

                Comparativo rápido:
                • Pior: destilado + mixer, cerveja comum em excesso
                • Médio: cerveja light ocasional
                • Melhor para dieta/treino: zero álcool ou não beber

                Em perda de gordura ou ganho de massa, menos é mais. Se beber, 1 light ocasional e conte as calorias no dia.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["lactose", "intolerancia", "intolerância", "leite", "iogurte", "queijo", "laticinio", "laticínio"],
            respond: { ctx in
                let tolerance = ctx.lactoseTolerance
                return """
                \(tolerance.map { "Sua tolerância à lactose: \($0.rawValue). \($0.detail)" } ?? "Informe sua tolerância à lactose em Nutrição para filtrar opções com leite e queijo.")

                Se intolerante, o cardápio prioriza opções sem lactose (leite vegetal, ovos, carnes, frutas).
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["fruta", "frutas", "banana", "maca", "maçã", "morango", "vitamina"],
            respond: { _ in
                """
                Frutas são fonte de fibras, vitaminas e carboidratos naturais.

                • 2–4 porções/dia é uma boa referência
                • Melhor com refeições ou lanches (não substituem proteína)
                • Priorize frutas inteiras em vez de sucos industrializados

                Na lista de compras do app: banana, maçã, morango, mamão e outras sazonais.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["fritura", "frituras", "frito", "fast food", "ultraprocessado", "industrializado"],
            respond: { ctx in
                let isFatLoss = ctx.user?.goal == .fatLoss
                return """
                Frituras e ultraprocessados têm muita gordura, sódio e calorias vazias.

                \(isFatLoss ? "Seu plano de perda de gordura exclui frituras do cardápio." : "Consuma com moderação — ocasionalmente não arruína o progresso.")

                Prefira: grelhados, assados, cozidos e airfryer.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["jejum", "jejuar", "intermitente", "fasting"],
            respond: { ctx in
                return """
                Jejum intermitente (ex.: 16/8) pode funcionar para algumas pessoas, mas não é obrigatório.

                O que importa para \(ctx.user?.goal.rawValue.lowercased() ?? "seus objetivos"): total calórico diário (\(ctx.dailyCalorieTarget) kcal) e proteína adequada.

                Se treina de manhã, não pule proteína pré/pós-treino.
                Consulte um profissional se tiver condições médicas.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["fibras", "fibra", "constipacao", "constipação", "intestino"],
            respond: { _ in
                """
                Fibras melhoram digestão, saciedade e controle glicêmico.

                Meta: 25–30 g/dia (adultos).
                Fontes: frutas, vegetais, aveia, arroz integral, leguminosas.

                Aumente aos poucos e beba água — fibras sem hidratação podem causar desconforto.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["deficit", "deficit calorico", "déficit calórico", "emagrecer", "perda de gordura", "perder peso", "emagrecimento"],
            respond: { ctx in
                guard let user = ctx.user else {
                    return "Déficit calórico é consumir menos calorias do que você gasta para perder gordura. Configure peso, altura e objetivo em Nutrição."
                }
                let deficit = ctx.caloricDeficit
                let weekly = user.estimatedWeeklyWeightLoss
                return """
                Déficit calórico = gastar mais energia do que consome.

                Seu TDEE: \(ctx.estimatedTDEE) kcal/dia.
                Déficit configurado: \(deficit > 0 ? "−\(deficit) kcal/dia" : "sem déficit ativo").
                Meta calórica: \(ctx.dailyCalorieTarget) kcal/dia.
                \(weekly > 0 ? String(format: "Estimativa: ~%.2f kg/semana de perda.", weekly) : "")

                O que fazer no déficit:
                • Priorize proteína (preserva músculo)
                • Mantenha treino de força
                • Inclua cardio moderado se quiser
                • Beba água e durma 7–9 h
                • Evite déficits extremos (não fique abaixo de ~1200 kcal sem acompanhamento)
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["ganho de massa", "bulking", "hipertrofia", "massa muscular alimentacao", "massa muscular alimentação", "engordar musculo", "engordar músculo"],
            respond: { ctx in
                guard let user = ctx.user else {
                    return "Ganho de massa exige superávit calórico (~300–500 kcal acima do TDEE) e proteína alta com treino de força."
                }
                return """
                Ganho de massa muscular (bulking):

                • Meta calórica: \(ctx.dailyCalorieTarget) kcal/dia (superávit sobre TDEE de \(ctx.estimatedTDEE))
                • Proteína: \(proteinRecommendation(for: user, calories: ctx.dailyCalorieTarget))
                • Treino: 3–5x/semana com progressão de carga
                • Biotipo \(user.biotype.rawValue): \(user.biotype.description)

                Ganho de 0,25–0,5 kg/semana indica progresso sem excesso de gordura.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["lista de compras", "compras semana", "supermercado", "feira"],
            respond: { _ in
                """
                A lista de compras do HealthFit inclui:

                • Proteínas: frango, carne, peixe, ovos
                • Frutas e vegetais da semana
                • Grãos: arroz, aveia, feijão
                • Suplementos: creatina, ômega 3, beta-alanina, pré-treino
                • Energéticos (configurável — alerta OMS acima de 2/semana)

                Gere em Nutrição → Lista de Compras após montar o cardápio.
                """
            }
        ),
    ]

    // MARK: - IMC

    private static let imcTopics: [HealthAssistantTopic] = [
        HealthAssistantTopic(
            keywords: ["imc", "bmi", "indice de massa", "índice de massa", "massa corporal", "qual meu imc", "qual é meu imc"],
            respond: { ctx in
                guard let user = ctx.user else {
                    return """
                    IMC (Índice de Massa Corporal) = peso (kg) ÷ altura (m)²

                    Classificação (OMS):
                    • Abaixo de 18,5 — abaixo do peso
                    • 18,5–24,9 — peso normal
                    • 25–29,9 — sobrepeso
                    • 30+ — obesidade

                    Complete peso e altura em Nutrição ou Perfil.
                    """
                }
                let bmi = user.bmi
                let info = bmiInfo(for: user)
                return """
                IMC (Índice de Massa Corporal) mede a relação peso/altura — não mede gordura diretamente, mas é um indicador útil.

                Seus dados:
                • Peso: \(String(format: "%.1f", user.weight)) kg
                • Altura: \(String(format: "%.0f", user.height)) cm
                • IMC: \(String(format: "%.1f", bmi))
                • Classificação: \(info.label)

                \(info.advice)

                Atletas com muito músculo podem ter IMC alto sem excesso de gordura. Combine com medidas corporais e % gordura se possível.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["peso ideal", "peso saudavel", "peso saudável", "quanto devo pesar", "meta de peso"],
            respond: { ctx in
                guard let user = ctx.user else {
                    return "Peso ideal varia com altura, composição corporal e objetivo. IMC entre 18,5–24,9 é referência geral para adultos."
                }
                let heightM = user.height / 100
                let minWeight = 18.5 * heightM * heightM
                let maxWeight = 24.9 * heightM * heightM
                return """
                Faixa de peso saudável (IMC 18,5–24,9) para sua altura (\(String(format: "%.0f", user.height)) cm):

                • Mínimo: ~\(String(format: "%.1f", minWeight)) kg
                • Máximo: ~\(String(format: "%.1f", maxWeight)) kg
                • Seu peso atual: \(String(format: "%.1f", user.weight)) kg (IMC \(String(format: "%.1f", user.bmi)))

                Objetivo no app: \(user.goal.rawValue).
                \(user.estimatedWeeklyWeightLoss > 0 ? String(format: "Ritmo estimado: ~%.2f kg/semana.", user.estimatedWeeklyWeightLoss) : "Ajuste calorias conforme progresso semanal.")

                Composição corporal importa mais que o número na balança — treino de força preserva músculo.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["sobrepeso", "obesidade", "obeso", "gordo", "acima do peso", "magreza", "abaixo do peso", "muito magro"],
            respond: { ctx in
                guard let user = ctx.user else {
                    return """
                    Classificação IMC (OMS):
                    • < 18,5 — abaixo do peso
                    • 18,5–24,9 — normal
                    • 25–29,9 — sobrepeso
                    • 30–34,9 — obesidade I
                    • 35–39,9 — obesidade II
                    • ≥ 40 — obesidade III
                    """
                }
                let info = bmiInfo(for: user)
                return """
                Seu IMC: \(String(format: "%.1f", user.bmi)) — \(info.label)

                \(info.advice)

                Objetivo configurado: \(user.goal.rawValue).
                Meta calórica: \(ctx.dailyCalorieTarget) kcal/dia.

                Mudanças graduais e consistentes vencem dietas radicais. O app acompanha treino, nutrição e hidratação.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["peso", "balanca", "balança", "engordar", "emagreci", "subi de peso", "desci de peso"],
            respond: { ctx in
                guard let user = ctx.user else {
                    return "Registre peso e altura em Nutrição para calcular IMC, TMB e metas calóricas."
                }
                let info = bmiInfo(for: user)
                return """
                Seu peso: \(String(format: "%.1f", user.weight)) kg
                Altura: \(String(format: "%.0f", user.height)) cm
                IMC: \(String(format: "%.1f", user.bmi)) (\(info.label))

                Para \(user.goal.rawValue.lowercased()):
                • Meta calórica: \(ctx.dailyCalorieTarget) kcal/dia
                • TDEE: \(ctx.estimatedTDEE) kcal/dia
                \(user.estimatedWeeklyWeightLoss > 0 ? String(format: "• Estimativa: ~%.2f kg/semana", user.estimatedWeeklyWeightLoss) : "")

                Pese-se no mesmo horário (ex.: ao acordar) 1–2x/semana. Flutuações diárias de 1–2 kg são normais (água, alimento).
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["composicao corporal", "composição corporal", "gordura corporal", "percentual de gordura", "bf", "body fat"],
            respond: { ctx in
                let bmiNote = ctx.user.map { "Seu IMC (\(String(format: "%.1f", $0.bmi))) é um proxy, não mede % gordura diretamente." } ?? ""
                return """
                Composição corporal = proporção de gordura vs músculo (mais relevante que peso sozinho).

                \(bmiNote)

                Para melhorar composição:
                • Treino de força (preserva/ganha músculo)
                • Proteína adequada
                • Déficit moderado se perder gordura

                Bioimpedância, adipômetro ou DEXA dão medidas mais precisas que a balança comum.
                """
            }
        ),
    ]

    // MARK: - Evolução corporal

    private static let bodyEvolutionTopics: [HealthAssistantTopic] = [
        HealthAssistantTopic(
            keywords: [
                "evolucao corporal", "evolução corporal", "fotos de evolucao", "fotos de evolução",
                "comparar medidas", "comparativo de medidas", "progresso corporal", "antes e depois",
                "lote de fotos", "pdf de medidas",
            ],
            respond: { ctx in
                let measuresNote: String = {
                    guard let user = ctx.user else {
                        return "Cadastre-se e preencha as medidas no Perfil para um laudo completo."
                    }
                    if let comparison = user.latestMeasurementComparison,
                       comparison.periodDays >= BodyMeasurements.comparisonIntervalDays {
                        if comparison.changes.isEmpty {
                            return "Suas medidas mais recentes não variaram de forma mensurável no período."
                        }
                        let lines = comparison.changes.prefix(5).map {
                            "• \($0.label): \(BodyMeasurements.formatCm($0.previous)) → \(BodyMeasurements.formatCm($0.current)) (\(BodyMeasurements.formatDelta($0.delta)))"
                        }
                        return "Comparativo de medidas (\(comparison.periodDays) dias):\n" + lines.joined(separator: "\n")
                    }
                    if user.bodyMeasurements.hasAnyValue {
                        return "Você já tem medidas salvas. Após 30 dias (e um novo lote de fotos), o app gera o comparativo automático."
                    }
                    return "Ainda não há medidas corporais salvas. Preencha em Perfil → Medidas Corporais."
                }()

                return """
                Evolução Corporal no HealthFit:
                • Fotos são opcionais (até 6 ângulos) e privadas — só você pode ver ou acessar.
                • O laudo principal usa as medidas corporais do Perfil.
                • Após 30 dias, registre uma nova avaliação (com ou sem fotos).
                • Se houver fotos antigas, elas são excluídas após a comparação.
                • Os PDFs das últimas 4 avaliações ficam salvos só na sua conta.

                \(measuresNote)

                Abra Perfil → Evolução Corporal para iniciar ou ver o histórico.
                """
            }
        ),
    ]

    // MARK: - Treinos

    private static let workoutTopics: [HealthAssistantTopic] = [
        HealthAssistantTopic(
            keywords: [
                "montar treino", "criar treino", "gerar treino", "montar ficha", "criar ficha", "gerar ficha",
                "treino sem personal", "nao tenho personal", "não tenho personal", "sem personal",
                "ficha personalizada", "treino pelo assistente", "sugestao de treino", "sugestão de treino"
            ],
            respond: { ctx in
                if ctx.user?.hasPersonalTrainer == true {
                    let name = ctx.user?.personalTrainerName.isEmpty == false
                        ? ctx.user!.personalTrainerName
                        : "seu personal"
                    return """
                    Você tem personal cadastrado (\(name)). O ideal é seguir a ficha prescrita em Treinos.

                    Se mesmo assim quiser uma sugestão educativa do IAssistente, diga: “montar treino mesmo assim”.

                    \(AssistantWorkoutBuilder.professionalDisclaimer)

                    \(healthSafetyDisclaimer)
                    """
                }
                return """
                Posso montar uma sugestão de treino para quem não tem personal.

                Digite “montar treino” (ou toque na sugestão) para começarmos: perfil masculino/feminino, se treina só em casa ou na academia, experiência e o foco (massa, resistência ou perda de gordura).

                \(AssistantWorkoutBuilder.professionalDisclaimer)
                """
            }
        ),
        HealthAssistantTopic(
            keywords: [
                "treino em casa", "treinar em casa", "sem academia", "sem equipamento",
                "peso corporal", "bodyweight", "casa funciona", "só em casa", "so em casa",
                "treino caseiro", "montar treino em casa", "como treinar em casa"
            ],
            respond: { _ in
                """
                Treinar em casa funciona — principalmente com consistência, progressão e boa técnica.

                O que priorizar em casa:
                • Full body ou divisão simples (superior/inferior) 3–5x/semana
                • Progressão: mais reps, menos descanso, variações mais difíceis (ex.: flexão diamante)
                • Core, pernas e empurrar/puxar com peso corporal
                • Use demos em GIF no app (**Treinos → Treine em Casa**)

                Limitações honestas:
                • Hipertrofia avançada de certos grupos fica mais fácil com carga externa
                • Elásticos/halteres leves ajudam, mas não são obrigatórios para começar

                Quer uma ficha personalizada? Digite “montar treino” e escolha **Sim, só em casa** no fluxo.

                \(AssistantWorkoutBuilder.professionalDisclaimer)

                \(healthSafetyDisclaimer)
                """
            }
        ),
        HealthAssistantTopic(
            keywords: [
                "ganhar massa em casa", "hipertrofia em casa", "crescer em casa",
                "musculo em casa", "músculo em casa"
            ],
            respond: { _ in
                """
                Dá para ganhar músculo em casa, sobretudo no início e intermediário:

                • Chegue perto da falha em 8–20 reps (flexões, agachamentos, afundos, ponte, mergulhos)
                • Aumente dificuldade: pausas, tempo sob tensão, unilateral, elevações
                • Proteína adequada + sono 7–9 h + superávit leve se o objetivo for massa
                • 3–4 sessões/semana com recuperação entre estímulos do mesmo grupo

                No app: peça “montar treino” → **Sim, só em casa** → foco **Ganho de massa**, ou use as fichas em **Treine em Casa**.

                \(AssistantWorkoutBuilder.professionalDisclaimer)

                \(healthSafetyDisclaimer)
                """
            }
        ),
        HealthAssistantTopic(
            keywords: [
                "emagrecer em casa", "perder gordura em casa", "secar em casa",
                "hiit em casa", "cardio em casa"
            ],
            respond: { _ in
                """
                Emagrecer em casa combina déficit calórico + movimento consistente:

                • Circuitos com agachamento, burpee, polichinelo, mountain climber e prancha
                • 20–35 min, 3–5x/semana, mantendo esforço sustentável
                • Força em casa 2–3x ajuda a preservar músculo no déficit
                • Água, sono e proteína continuam essenciais

                Peça “montar treino” e escolha **Só em casa** + foco **Perda de gordura**, ou veja HIIT em **Treinos → Treine em Casa**.

                \(healthSafetyDisclaimer)
                """
            }
        ),
        HealthAssistantTopic(
            keywords: [
                "espaco pequeno", "espaço pequeno", "apartamento", "vizinho",
                "sem barulho", "treino silencioso"
            ],
            respond: { _ in
                """
                Em apartamento / espaço pequeno:

                • Prefira afundos, agachamento controlado, ponte, prancha, flexões e isometrias
                • Evite burpees/saltos se o barulho incomodar vizinhos
                • Tapete antiderrapante e janela ventilada ajudam
                • Sessões curtas (20–30 min) bem feitas valem mais que treinos longos irregulares

                No IAssistente: “montar treino” → **Sim, só em casa**. Em **Treine em Casa** há fichas full body e core com demos.

                \(healthSafetyDisclaimer)
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["treino", "musculacao", "musculação", "forca", "força", "exercicio", "exercício", "academia", "ficha"],
            respond: { ctx in
                let goal = ctx.user?.goal ?? .maintenance
                let tip = (ctx.user?.hasPersonalTrainer == true)
                    ? "No app: Treinos → Musculação. Escolha a ficha do seu plano."
                    : "Sem personal? Peça “montar treino” ao IAssistente (casa ou academia) para uma sugestão personalizada (sempre valide com um profissional de Educação Física)."
                return """
                Treino de musculação (força) ganha/preserva massa muscular, acelera metabolismo e melhora composição corporal.

                Para \(goal.rawValue):
                \(goalTrainingSummary(goal))

                \(tip)

                Também há **Treine em Casa** (peso corporal) e **Mobilidade** dentro de Musculação.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["serie", "série", "series", "séries", "repeticao", "repetição", "repeticoes", "repetições", "reps", "quantas series"],
            respond: { ctx in
                let goal = ctx.user?.goal ?? .maintenance
                let scheme: String
                switch goal {
                case .muscleGain:
                    scheme = "3–5 séries × 6–12 reps (hipertrofia). Descanso 60–90 s."
                case .fatLoss:
                    scheme = "3–4 séries × 8–15 reps. Mantenha carga desafiadora."
                case .endurance:
                    scheme = "2–3 séries × 15–20 reps ou circuitos."
                case .maintenance:
                    scheme = "3 séries × 8–12 reps — equilíbrio força e volume."
                }
                return """
                Séries e repetições dependem do objetivo (\(goal.rawValue)):

                \(scheme)

                Regras gerais:
                • Últimas 2–3 reps devem ser difíceis (RPE 7–9)
                • Progressão: aumente carga ou reps quando completar o topo da faixa
                • Registre no app para acompanhar evolução
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["descanso", "intervalo", "pausa entre", "descanso entre series", "descanso entre séries"],
            respond: { _ in
                """
                Descanso entre séries:

                • Força (1–5 reps): 2–5 min
                • Hipertrofia (6–12 reps): 60–90 s
                • Resistência (15+ reps): 30–60 s
                • Exercícios compostos (agachamento, terra): mais descanso
                • Isolados (rosca, extensora): menos descanso

                Descanso insuficiente reduz performance; excessivo esfria o músculo. Use o timer do app durante o treino.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["aquecimento", "alongamento", "warm up", "warmup", "mobilidade", "flexibilidade"],
            respond: { _ in
                """
                Aquecimento (5–10 min antes do treino):
                • Cardio leve (esteira, bike)
                • Mobilidade articular
                • 1–2 séries leves do primeiro exercício

                Alongamento:
                • Dinâmico antes do treino
                • Estático após o treino (15–30 s por músculo)

                Reduz risco de lesão e melhora amplitude de movimento.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["progressao", "progressão", "carga", "sobrecarga", "evoluir", "aumentar peso", "plateau", "estagnado"],
            respond: { _ in
                """
                Progressão de carga (sobrecarga progressiva):

                • Quando completar todas as reps com boa forma → aumente 2,5–5 kg (membros superiores) ou 5–10 kg (inferiores)
                • Ou adicione 1–2 reps por série
                • Anote pesos no app — compare semana a semana

                Estagnou? Varie exercícios, aumente volume ou revise sono/alimentação.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["cardio", "corrida", "caminhada", "esteira", "bike", "bicicleta", "aerobico", "aeróbico", "eliptico", "elíptico"],
            respond: { ctx in
                let goal = ctx.user?.goal.rawValue ?? "seu objetivo"
                return """
                Cardio melhora condicionamento, queima calorias e saúde cardiovascular.

                Indicado para \(goal) e recuperação ativa.
                • Leve: caminhada, bike leve — recuperação
                • Moderado: corrida leve, elíptico — queima calorias
                • Intenso: HIIT, sprints — condicionamento avançado

                No HealthFit: Treinos → Cardio. Combine 1–3 sessões/semana com musculação.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["hiit", "intervalado", "sprint", "alta intensidade"],
            respond: { ctx in
                return """
                HIIT (treino intervalado de alta intensidade) alterna esforço máximo e recuperação.

                Benefícios: condicionamento rápido, queima calórica elevada.
                Riscos: exige base cardiovascular; não ideal para iniciantes ou todos os dias.

                Para \(ctx.user?.goal.rawValue.lowercased() ?? "seu objetivo"): 1–2x/semana, além de musculação.
                No app: Treinos → Cardio → opções intensas.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["meditacao", "meditação", "mindfulness", "relaxar", "ansiedade", "estresse"],
            respond: { _ in
                """
                Meditação reduz estresse, melhora foco e apoia recuperação.

                Benefícios:
                • Melhor qualidade do sono
                • Menos cortisol
                • Mais consistência nos hábitos

                No app: Treinos → Meditação. 5–10 minutos já fazem diferença. Complementa treino e dieta.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["melhor", "qual escolher", "treino ou", "cardio ou", "comparar", "versus", " vs "],
            respond: { ctx in
                let goal = ctx.user?.goal ?? .maintenance
                let recommendation: String
                switch goal {
                case .muscleGain:
                    recommendation = "Priorize musculação (4–5x/semana). Cardio leve 1–2x. Meditação para recuperação."
                case .fatLoss:
                    recommendation = "Musculação 3–4x + déficit calórico. Cardio 2–3x. Meditação para sono e adesão."
                case .endurance:
                    recommendation = "Cardio 3–4x + musculação 2x para prevenir lesões. Meditação para foco."
                case .maintenance:
                    recommendation = "Combine musculação 2–3x, cardio 2x e meditação 2–3x por semana."
                }
                return """
                Não existe um só "melhor" — depende do objetivo (\(goal.rawValue)):

                • Musculação — massa muscular, força, metabolismo
                • Cardio — condicionamento, calorias, coração
                • Meditação — mente, sono, estresse

                Recomendação para você: \(recommendation)

                O ideal é combinar os três ao longo da semana.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["peito", "supino", "costas", "dorsal", "perna", "pernas", "agachamento", "gluteo", "glúteo", "ombro", "ombros", "braco", "braço", "biceps", "bíceps", "triceps", "tríceps", "abdomen", "abdômen", "abdominal", "core"],
            respond: { _ in
                """
                Grupos musculares no app:

                • Peito — supino reto/inclinado, crucifixo, crossover
                • Costas — remada, puxada, levantamento terra
                • Pernas — agachamento, leg press, extensora, flexora, panturrilha
                • Ombros — desenvolvimento, elevação lateral/frontal
                • Braços — rosca (bíceps), tríceps pulley/testa
                • Core — estabilização em compostos + abdominais

                Fichas divididas (A/B/C) cobrem todos os grupos na semana. Veja guia de execução em cada exercício.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["frequencia", "frequência", "quantos treinos", "vezes por semana", "dias de treino", "split"],
            respond: { ctx in
                let goal = ctx.user?.goal ?? .maintenance
                return """
                Frequência de treinos para \(goal.rawValue):

                \(goalTrainingSummary(goal))

                Splits comuns:
                • Full body — 3x/semana (iniciantes)
                • ABC — 3–6x/semana (intermediários)
                • Push/Pull/Legs — 4–6x/semana (avançados)

                Descanse 48 h entre treinos do mesmo grupo muscular.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: [
                "lesao", "lesão", "dor", "machucado", "contusao", "contusão", "tendinite",
                "mal-estar", "mal estar", "tontura", "ferido", "inflamacao", "inflamação",
                "desconforto", "duvida no exercicio", "dúvida no exercício"
            ],
            respond: { _ in
                """
                \(healthSafetyDisclaimer)

                Dor vs desconforto muscular:
                • Desconforto muscular (DOMS) 24–48 h após treino — normal
                • Dor aguda, articular, pontual, com formigamento ou falta de ar — pare imediatamente

                Se sentir dor, dúvida ou desconforto no exercício:
                • Interrompa o exercício na hora
                • Não treine a região afetada
                • Procure um profissional de saúde qualificado e habilitado (médico, fisioterapeuta ou emergência)
                • Não busque diagnóstico, tratamento ou “o que fazer” em ferramentas de IA

                Este assistente é apenas informativo e não substitui atendimento médico.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["personal", "relatorio", "relatório", "email", "e-mail", "enviar treino"],
            respond: { ctx in
                let hasTrainer = ctx.user?.hasPersonalTrainer ?? false
                return """
                Relatórios de treino no HealthFit:

                • Ao finalizar musculação ou cardio, o app gera resumo
                \(hasTrainer ? "• Seu personal (\(ctx.user?.personalTrainerName ?? "")) recebe por e-mail automaticamente" : "• Configure e-mail do personal em Perfil para envio automático")
                • Inclui exercícios, séries, cargas, cardio e uso de pré-treino

                Relatório semanal em Início → Progresso Semanal.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: [
                "conforme o personal", "conforme personal", "orientacao profissional", "orientação profissional",
                "seguir ficha", "ficha do personal", "treinar certo", "execucao correta", "execução correta",
                "como treinar", "guia de exercicio", "guia de exercício", "profissional prescreveu",
                "prescricao", "prescrição", "seguir treino", "treino profissional"
            ],
            respond: { ctx in
                let hasTrainer = ctx.user?.hasPersonalTrainer ?? false
                let trainerName = ctx.user?.personalTrainerName ?? "seu personal"
                return """
                Como treinar conforme orientação profissional no HealthFit:

                1. Siga a ficha prescrita
                • Treinos → Musculação → escolha a ficha do seu plano
                • Respeite séries, repetições e descanso indicados
                • Não aumente carga por conta própria sem aval do \(trainerName)

                2. Execução correta
                • Toque em cada exercício para ver o guia passo a passo
                • Priorize amplitude e forma antes de peso
                • Use o timer de descanso entre séries

                3. Registre tudo
                • Anote cargas e reps reais durante o treino
                • Informe se tomou pré-treino ao iniciar
                • Ao finalizar, o relatório é gerado automaticamente

                4. Comunicação com o personal
                \(hasTrainer
                    ? "• Relatório enviado para \(trainerName) (\(ctx.user?.personalTrainerEmail ?? ""))\n                • Relatório semanal em Início consolida volume e evolução"
                    : "• Cadastre nome e e-mail do personal em Perfil para envio automático\n                • Leve o histórico de treinos nas consultas")

                O app complementa o acompanhamento — dúvidas técnicas ou dores persistentes, consulte sempre o profissional.

                \(healthSafetyDisclaimer)
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["overtraining", "excesso de treino", "treinar todo dia", "fadiga", "cansaco", "cansaço"],
            respond: { _ in
                """
                Sinais de overtraining (excesso):
                • Queda de performance
                • Fadiga persistente
                • Sono ruim, irritabilidade
                • Dores que não passam

                Prevenção:
                • 1–2 dias de descanso/semana
                • Durma 7–9 h
                • Alimentação e hidratação adequadas
                • Periodize intensidade (nem todo treino é máximo)
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["objetivo", "ganho de massa treino", "resistencia", "resistência", "manutencao", "manutenção"],
            respond: { ctx in
                guard let user = ctx.user else {
                    return "Objetivos no app: Ganho de Massa, Perda de Gordura, Manutenção e Resistência. Configure em Nutrição ou Perfil."
                }
                return """
                Seu objetivo: \(user.goal.rawValue)

                Dieta: \(ctx.dailyCalorieTarget) kcal/dia (TDEE \(ctx.estimatedTDEE)).
                Treino: \(goalTrainingSummary(user.goal))

                Cardápio e fichas se adaptam ao objetivo. Altere em Perfil quando mudar de fase.
                """
            }
        ),
    ]

    // MARK: - Biotipos

    private static let biotypeTopics: [HealthAssistantTopic] = [
        HealthAssistantTopic(
            keywords: [
                "ectomorfo", "o que e ectomorfo", "o que é ectomorfo", "definicao ectomorfo",
                "definição ectomorfo", "significado ectomorfo", "ecto morfo", "sou ectomorfo"
            ],
            respond: { ctx in
                let isUser = ctx.user?.biotype == .ectomorph
                var text = ectomorphDefinition(isUserType: isUser)
                if let user = ctx.user {
                    if isUser {
                        text += "\n\nSeu TDEE ajustado: \(ctx.estimatedTDEE) kcal/dia (metabolismo +10%)."
                    } else {
                        text += "\n\nNo app, ectomorfos recebem +10% no TDEE. Seu biotipo: \(user.biotype.rawValue). TDEE: \(ctx.estimatedTDEE) kcal/dia."
                    }
                }
                return text
            }
        ),
        HealthAssistantTopic(
            keywords: [
                "mesomorfo", "o que e mesomorfo", "o que é mesomorfo", "definicao mesomorfo",
                "definição mesomorfo", "significado mesomorfo", "meso morfo", "sou mesomorfo"
            ],
            respond: { ctx in
                let isUser = ctx.user?.biotype == .mesomorph
                var text = mesomorphDefinition(isUserType: isUser)
                if let user = ctx.user {
                    if isUser {
                        text += "\n\nSeu TDEE: \(ctx.estimatedTDEE) kcal/dia."
                    } else {
                        text += "\n\nSeu biotipo: \(user.biotype.rawValue). TDEE: \(ctx.estimatedTDEE) kcal/dia."
                    }
                }
                return text
            }
        ),
        HealthAssistantTopic(
            keywords: [
                "endomorfo", "o que e endomorfo", "o que é endomorfo", "definicao endomorfo",
                "definição endomorfo", "significado endomorfo", "endo morfo", "sou endomorfo"
            ],
            respond: { ctx in
                let isUser = ctx.user?.biotype == .endomorph
                var text = endomorphDefinition(isUserType: isUser)
                if let user = ctx.user {
                    if isUser {
                        text += "\n\nSeu TDEE ajustado: \(ctx.estimatedTDEE) kcal/dia (metabolismo −10%)."
                    } else {
                        text += "\n\nNo app, endomorfos recebem −10% no TDEE. Seu biotipo: \(user.biotype.rawValue). TDEE: \(ctx.estimatedTDEE) kcal/dia."
                    }
                }
                return text
            }
        ),
        HealthAssistantTopic(
            keywords: ["biotipo", "biotipos", "somatotipo", "somatotipos", "tipos corporais", "tipo corporal"],
            respond: { ctx in
                guard let user = ctx.user else {
                    return """
                    Biotipo (somatotipo) descreve tendências naturais do corpo:

                    • Ectomorfo — magro, metabolismo acelerado, dificuldade em ganhar massa
                    • Mesomorfo — atlético, ganha músculo e perde gordura com facilidade
                    • Endomorfo — tende a acumular gordura, metabolismo mais lento

                    Pergunte "O que é ectomorfo?", "O que é mesomorfo?" ou "O que é endomorfo?" para ver cada definição.
                    Defina o seu em Nutrição ou Perfil.
                    """
                }
                return """
                Seu biotipo: \(user.biotype.rawValue)
                \(user.biotype.description)

                Como identificar: \(user.biotype.identificationGuide)

                Resumo dos três biotipos:
                • Ectomorfo — magro, metabolismo rápido (+10% TDEE)
                • Mesomorfo — atlético, responde bem ao treino
                • Endomorfo — acumula gordura com facilidade (−10% TDEE)

                O biotipo ajusta levemente calorias e estratégias, mas não limita seus resultados.
                """
            }
        ),
    ]

    // MARK: - Geral

    private static let generalTopics: [HealthAssistantTopic] = [
        HealthAssistantTopic(
            keywords: ["metabolismo basal", "tmb", "basal"],
            respond: { ctx in
                guard let user = ctx.user else {
                    return "Metabolismo basal (TMB) é a energia que seu corpo gasta em repouso. Complete seu perfil para ver sua estimativa."
                }
                return """
                Metabolismo basal (TMB) = calorias em repouso absoluto (respiração, circulação, órgãos).

                Sua TMB: \(ctx.basalMetabolicRate) kcal/dia.
                TDEE (atividade moderada): \(ctx.estimatedTDEE) kcal/dia.
                Meta: \(ctx.dailyCalorieTarget) kcal/dia para \(user.goal.rawValue.lowercased()).

                Varia com peso, altura, idade, sexo e biotipo (\(user.biotype.rawValue)).
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["tdee", "gasto calorico", "gasto calórico", "meta calorica", "meta calórica", "calorias"],
            respond: { ctx in
                """
                TDEE = gasto calórico total (TMB + atividade diária).

                Sua TMB: \(ctx.basalMetabolicRate) kcal/dia.
                TDEE estimado: \(ctx.estimatedTDEE) kcal/dia.
                Meta do plano: \(ctx.dailyCalorieTarget) kcal/dia.

                Emagrecer → abaixo do TDEE. Ganhar massa → acima. Manter → perto do TDEE.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: ["agua", "hidrata", "beber", "desidrata", "liquido", "líquido"],
            respond: { ctx in
                guard let user = ctx.user else {
                    return "Beber água suficiente mantém energia, digestão e performance. Meta: ~35 ml/kg/dia."
                }
                let goal = user.recommendedDailyWaterML
                let current = ctx.waterIntakeMl
                let remaining = max(goal - current, 0)
                return """
                Sem água suficiente: cansaço, dor de cabeça, queda no treino, recuperação lenta, confusão fome/sede.

                Meta: \(goal) ml/dia (~\(String(format: "%.1f", user.recommendedDailyWaterLiters)) L).
                Hoje: \(current) ml.
                \(remaining > 0 ? "Faltam ~\(remaining) ml." : "Meta atingida hoje!")

                Beba ao longo do dia; aumente em dias de treino ou calor.
                """
            }
        ),
        HealthAssistantTopic(
            keywords: [
                "sono", "dormir", "descanso", "recuperacao", "recuperação",
                "dormir corretamente", "dormir bem", "higiene do sono", "rotina de sono",
                "insomnia", "insônia", "noite", "cama", "horas de sono", "qualidade do sono"
            ],
            respond: { ctx in
                let todayNote = sleepStatusLine(hours: ctx.sleepHours)
                return """
                Como dormir corretamente:

                Meta: 7–9 horas por noite (adultos).
                • < 5 h — sono não regulado; hormônios e recuperação prejudicados
                • 5–7 h — aumente gradualmente
                • 7–9 h — ideal para treino, músculo e perda de gordura
                • > 9 h — ok ocasionalmente; avalie se há fadiga excessiva

                \(todayNote)

                Higiene do sono:
                • Horário fixo para deitar e acordar (inclusive fim de semana)
                • Quarto escuro, silencioso e fresco
                • Evite telas 30–60 min antes de dormir
                • Sem cafeína/energético à tarde/noite
                • Jantar leve 2–3 h antes de deitar
                • Meditação no app (Treinos → Meditação) ajuda a relaxar

                Sono ruim sabota treino e dieta — trate o descanso como parte do plano.
                """
            }
        ),
    ]
}

private struct HealthAssistantTopic {
    let keywords: [String]
    let respond: (HealthAssistantContext) -> String
}

@MainActor
final class HealthAssistantService: ObservableObject {
    @Published private(set) var messages: [HealthChatMessage] = []
    @Published private(set) var isTyping = false

    private enum WorkoutBuilderPhase {
        case askingGender
        case askingHomeOnly
        case askingAlreadyTrains
        case askingFirstTimeGym
        case askingExperienceLevel
        case askingFocus
        case confirming
    }

    private var replyTask: Task<Void, Never>?
    private var hasAppearedOnce = false
    private(set) var lastUserInteractionAt = Date()
    private var lastUserMessageAt: Date?
    private var inactivityFollowUpDelivered = false
    private var cardioMeditationNudgeDelivered = false
    private var supplementNudgeDelivered = false
    private var tideAlertDelivered = false
    private var activePostWorkoutCheckIn: PendingPostWorkoutCheckIn?
    private var isDailyMorningCheckInActive = false
    private var isDailyEveningCheckInActive = false
    private var lastEveningDayFeeling: DailyEveningDayFeeling?
    private var workoutBuilderPhase: WorkoutBuilderPhase?
    private var draftWorkoutGender: Gender?
    private var draftWorkoutLocation: AssistantTrainingLocation?
    private var draftWorkoutExperience: AssistantTrainingExperience?
    private var draftWorkoutFocus: AssistantWorkoutGoalFocus?
    /// Minimum time the typing bubble stays visible before showing an assistant reply.
    /// `nonisolated` so default args / static helpers can read it under Swift 6 concurrency.
    nonisolated private static let replyDelay: Duration = .seconds(3)
    nonisolated private static let workoutBuilderReplyDelay: Duration = .seconds(1)
    private static let idleReturnThreshold: TimeInterval = 180

    private func deliverAssistantMessage(_ text: String) {
        messages.append(HealthChatMessage(text: text, isUser: false))

        let viewingAssistant = PostWorkoutCheckInService.shared.isAssistantTabActive
            && UIApplication.shared.applicationState == .active
        guard !viewingAssistant else { return }

        PostWorkoutCheckInService.shared.notifyAssistantMessagePending()
        NotificationService.shared.deliverAssistantMessageNotification(body: text)
    }

    /// Keeps typing on for at least `minDuration` from `startedAt`, then delivers.
    /// If work overruns the budget, delivers as soon as ready (still at least min duration only when work is faster).
    private func deliverAfterMinimumTyping(
        minDuration: Duration = replyDelay,
        buildMessage: @escaping () -> String,
        afterDeliver: (() -> Void)? = nil
    ) {
        isTyping = true
        replyTask?.cancel()
        let startedAt = ContinuousClock.now
        replyTask = Task {
            do {
                let text = buildMessage()
                try await Self.waitForMinimumTyping(startedAt: startedAt, minDuration: minDuration)
                guard !Task.isCancelled else { return }
                deliverAssistantMessage(text)
                afterDeliver?()
                isTyping = false
            } catch {
                isTyping = false
            }
        }
    }

    private static func waitForMinimumTyping(
        startedAt: ContinuousClock.Instant,
        minDuration: Duration = replyDelay
    ) async throws {
        let remaining = minDuration - (ContinuousClock.now - startedAt)
        if remaining > .zero {
            try await Task.sleep(for: remaining)
        }
    }

    var isInPostWorkoutCheckIn: Bool {
        activePostWorkoutCheckIn != nil || PostWorkoutCheckInService.shared.isAwaitingFeelingReply
    }

    var isInDailyMorningCheckIn: Bool {
        isDailyMorningCheckInActive || DailyMorningCheckInService.shared.isAwaitingFeelingReply
    }

    var isInDailyEveningCheckIn: Bool {
        isDailyEveningCheckInActive || DailyEveningCheckInService.shared.isAwaitingReply
    }

    var isInWorkoutBuilder: Bool {
        workoutBuilderPhase != nil
    }

    var isInGuidedCheckIn: Bool {
        isInPostWorkoutCheckIn || isInDailyMorningCheckIn || isInDailyEveningCheckIn || isInWorkoutBuilder
    }

    var workoutBuilderQuickReplies: [String] {
        switch workoutBuilderPhase {
        case .askingGender:
            return AssistantWorkoutBuilder.quickGenderReplies
        case .askingHomeOnly:
            return AssistantWorkoutBuilder.quickHomeOnlyReplies
        case .askingAlreadyTrains:
            return AssistantWorkoutBuilder.quickAlreadyTrainsReplies
        case .askingFirstTimeGym:
            return AssistantWorkoutBuilder.quickFirstTimeReplies
        case .askingExperienceLevel:
            return AssistantWorkoutBuilder.quickLevelReplies
        case .askingFocus:
            return AssistantWorkoutBuilder.quickFocusReplies
        case .confirming:
            return AssistantWorkoutBuilder.quickConfirmReplies
        case .none:
            return []
        }
    }

    func bootstrap(context: HealthAssistantContext) {
        guard messages.isEmpty else { return }
        guard PostWorkoutCheckInService.shared.dueCheckIn == nil,
              !PostWorkoutCheckInService.shared.isAwaitingFeelingReply else { return }
        guard !DailyMorningCheckInService.shared.isDue,
              !DailyMorningCheckInService.shared.isAwaitingFeelingReply else { return }
        guard !DailyEveningCheckInService.shared.isDue,
              !DailyEveningCheckInService.shared.isAwaitingReply else { return }
        messages.append(
            HealthChatMessage(
                text: HealthAssistantEngine.welcomeMessage(context: context),
                isUser: false
            )
        )
        deliverPendingBodyEvolutionAnnouncementIfNeeded()
        deliverPendingSupplementAcknowledgmentIfNeeded()
        lastUserInteractionAt = Date()
    }

    /// Entrega anúncio de evolução corporal gerado após uma comparação.
    func deliverPendingBodyEvolutionAnnouncementIfNeeded() {
        guard let message = BodyEvolutionService.shared.consumePendingAssistantMessage() else { return }
        deliverAssistantMessage(message)
    }

    /// Entrega agradecimento após o usuário registrar um suplemento.
    func deliverPendingSupplementAcknowledgmentIfNeeded() {
        guard let message = AssistantSupplementNudgeEngine.consumePendingAcknowledgment() else { return }
        if let last = messages.last, !last.isUser, last.text == message { return }
        deliverAssistantMessage(message)
    }

    /// Reage imediatamente quando o usuário registra suplemento com o chat aberto.
    func deliverSupplementLoggedMessage(_ text: String) {
        guard !text.isEmpty else { return }
        if let last = messages.last, !last.isUser, last.text == text { return }
        // Consome o pending para não duplicar no próximo bootstrap.
        _ = AssistantSupplementNudgeEngine.consumePendingAcknowledgment()
        deliverAssistantMessage(text)
        lastUserInteractionAt = Date()
    }

    func bootstrap(userName: String?) {
        bootstrap(context: HealthAssistantContext(
            user: userName.map { UserProfile(name: $0, email: "") },
            waterIntakeMl: 0,
            sleepHours: nil,
            weeklyWorkoutCount: 0,
            hoursSinceLastWorkout: nil,
            todayWorkoutSessions: [],
            recentWorkoutSessions: [],
            dailyCalorieTarget: 0,
            basalMetabolicRate: 0,
            estimatedTDEE: 0,
            caloricDeficit: 0,
            sweetConsumption: .moderate,
            lactoseTolerance: nil,
            hasMealPlan: false,
            todayMealsCompleted: 0,
            todayMealsTotal: 0,
            weekMealsCompleted: 0,
            weekMealsTotal: 0,
            supplementsLoggedToday: 0
        ))
    }

    func send(_ question: String, context: HealthAssistantContext, workoutStore: WorkoutStore? = nil) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isTyping else { return }

        recordUserInteraction()
        lastUserMessageAt = Date()
        inactivityFollowUpDelivered = false
        cardioMeditationNudgeDelivered = false
        supplementNudgeDelivered = false
        tideAlertDelivered = false
        replyTask?.cancel()
        messages.append(HealthChatMessage(text: trimmed, isUser: true))

        if isInPostWorkoutCheckIn {
            handlePostWorkoutReply(trimmed, context: context)
            return
        }

        if isInDailyEveningCheckIn {
            handleDailyEveningReply(trimmed, context: context)
            return
        }

        if isInDailyMorningCheckIn {
            handleDailyMorningReply(trimmed, context: context)
            return
        }

        if isInWorkoutBuilder {
            handleWorkoutBuilderReply(trimmed, context: context, workoutStore: workoutStore)
            return
        }

        if AssistantWorkoutBuilder.detectsWorkoutBuildIntent(trimmed) {
            beginWorkoutBuilderFlow(context: context, forceDespitePersonal: AssistantWorkoutBuilder.detectsForceBuildDespitePersonal(trimmed))
            return
        }

        deliverAfterMinimumTyping {
            HealthAssistantEngine.answer(for: trimmed, context: context)
        }
    }

    private func resetWorkoutBuilderDraft() {
        workoutBuilderPhase = nil
        draftWorkoutGender = nil
        draftWorkoutLocation = nil
        draftWorkoutExperience = nil
        draftWorkoutFocus = nil
    }

    private func beginWorkoutBuilderFlow(context: HealthAssistantContext, forceDespitePersonal: Bool) {
        if context.user?.hasPersonalTrainer == true, !forceDespitePersonal {
            deliverDelayedWorkoutBuilderMessage("""
            Você tem personal cadastrado\(context.user?.personalTrainerName.isEmpty == false ? " (\(context.user!.personalTrainerName))" : ""). \
            O ideal é seguir a ficha do profissional em Treinos.

            Se quiser uma sugestão educativa do IAssistente mesmo assim, diga: “montar treino mesmo assim”.

            \(AssistantWorkoutBuilder.professionalDisclaimer)
            """)
            return
        }

        workoutBuilderPhase = .askingGender
        draftWorkoutGender = nil
        draftWorkoutLocation = nil
        draftWorkoutExperience = nil
        draftWorkoutFocus = nil

        let name = context.user?.greetingName ?? ""
        let greeting = name.isEmpty ? "" : "\(name), "

        deliverDelayedWorkoutBuilderMessage("""
        \(greeting)posso montar uma sugestão de treino personalizada.

        Vou entender seu perfil: se treina em casa ou academia, experiência e foco — depois gero a ficha.

        \(AssistantWorkoutBuilder.professionalDisclaimer)

        Primeiro: deseja treino **Masculino** ou **Feminino**?
        """)
    }

    private func handleWorkoutBuilderReply(
        _ text: String,
        context: HealthAssistantContext,
        workoutStore: WorkoutStore?
    ) {
        switch workoutBuilderPhase {
        case .askingGender:
            guard let gender = AssistantWorkoutBuilder.parseGender(from: text) else {
                divertOrRepromptWorkoutBuilder(
                    text,
                    context: context,
                    pendingQuestion: "deseja treino **Masculino** ou **Feminino**?",
                    fallback: "Não entendi o perfil. Responda **Masculino** ou **Feminino**."
                )
                return
            }
            draftWorkoutGender = gender
            workoutBuilderPhase = .askingHomeOnly
            deliverDelayedWorkoutBuilderMessage("""
            Perfil \(gender == .female ? "feminino" : "masculino") selecionado.

            Você deseja treinar **apenas em casa** (peso corporal, sem academia)?
            Responda **Sim, só em casa** ou **Não, na academia**.
            """)

        case .askingHomeOnly:
            guard let homeOnly = AssistantWorkoutBuilder.parseHomeOnly(from: text) else {
                divertOrRepromptWorkoutBuilder(
                    text,
                    context: context,
                    pendingQuestion: "você prefere treinar **só em casa** ou **na academia**?",
                    fallback: "Prefere treinar só em casa ou na academia? Responda **Sim, só em casa** ou **Não, na academia**."
                )
                return
            }
            draftWorkoutLocation = homeOnly ? .homeOnly : .gym
            workoutBuilderPhase = .askingAlreadyTrains
            let place = homeOnly ? "em casa" : "na academia"
            deliverDelayedWorkoutBuilderMessage("""
            Beleza — montarei a ficha para treinar \(place).

            Você **já treina** atualmente?
            Responda **Sim, já treino** ou **Não, ainda não**.
            """)

        case .askingAlreadyTrains:
            guard let alreadyTrains = AssistantWorkoutBuilder.parseAlreadyTrains(from: text) else {
                divertOrRepromptWorkoutBuilder(
                    text,
                    context: context,
                    pendingQuestion: "você **já treina** atualmente?",
                    fallback: "Me diga se você já treina: **Sim, já treino** ou **Não, ainda não**."
                )
                return
            }
            if alreadyTrains {
                workoutBuilderPhase = .askingExperienceLevel
                deliverDelayedWorkoutBuilderMessage("""
                Ótimo — então vamos calibrar a intensidade.

                Qual o seu nível hoje?
                • **Iniciante**
                • **Intermediário**
                • **Avançado**
                """)
            } else {
                workoutBuilderPhase = .askingFirstTimeGym
                let firstTimePrompt = draftWorkoutLocation == .homeOnly
                    ? "É a sua **primeira vez** com treinos estruturados em casa?"
                    : "É a sua **primeira vez na academia**?"
                deliverDelayedWorkoutBuilderMessage("""
                Sem problemas — começamos com calma.

                \(firstTimePrompt)
                Responda **Sim, primeira vez** ou **Não, já treinei antes**.
                """)
            }

        case .askingFirstTimeGym:
            guard let isFirstTime = AssistantWorkoutBuilder.parseFirstTimeAtGym(from: text) else {
                let pending = draftWorkoutLocation == .homeOnly
                    ? "é a sua **primeira vez** com treinos estruturados em casa?"
                    : "é a sua **primeira vez na academia**?"
                let hint = draftWorkoutLocation == .homeOnly
                    ? "É a primeira vez treinando em casa?"
                    : "É a primeira vez na academia?"
                divertOrRepromptWorkoutBuilder(
                    text,
                    context: context,
                    pendingQuestion: pending,
                    fallback: "\(hint) Responda **Sim, primeira vez** ou **Não, já treinei antes**."
                )
                return
            }
            draftWorkoutExperience = AssistantTrainingExperience.fromFirstTimeAnswer(isFirstTime)
            workoutBuilderPhase = .askingFocus
            let experienceNote: String
            if draftWorkoutLocation == .homeOnly {
                experienceNote = isFirstTime
                    ? "Perfil: primeira vez em casa — volume moderado e foco em técnica (use os GIFs)."
                    : "Perfil: retomando em casa — progressão cuidadosa sem equipamentos."
            } else {
                experienceNote = isFirstTime
                    ? "Perfil: primeira vez na academia — cargas leves e foco em técnica."
                    : "Perfil: retomando após pausa — progressão cuidadosa."
            }
            deliverDelayedWorkoutBuilderMessage("""
            \(experienceNote)

            Qual o foco do treino?
            • Ganho de massa
            • Resistência
            • Perda de gordura
            """)

        case .askingExperienceLevel:
            guard let level = AssistantTrainingExperience.parseLevel(from: text) else {
                divertOrRepromptWorkoutBuilder(
                    text,
                    context: context,
                    pendingQuestion: "qual o seu nível hoje — **Iniciante**, **Intermediário** ou **Avançado**?",
                    fallback: "Escolha o nível: **Iniciante**, **Intermediário** ou **Avançado**."
                )
                return
            }
            draftWorkoutExperience = level
            workoutBuilderPhase = .askingFocus
            deliverDelayedWorkoutBuilderMessage("""
            Nível \(level.rawValue.lowercased()) anotado.

            Qual o foco do treino?
            • Ganho de massa
            • Resistência
            • Perda de gordura
            """)

        case .askingFocus:
            guard let focus = AssistantWorkoutGoalFocus.parse(from: text) else {
                divertOrRepromptWorkoutBuilder(
                    text,
                    context: context,
                    pendingQuestion: "qual o foco do treino — **Ganho de massa**, **Resistência** ou **Perda de gordura**?",
                    fallback: "Escolha um foco: **Ganho de massa**, **Resistência** ou **Perda de gordura**."
                )
                return
            }
            draftWorkoutFocus = focus
            workoutBuilderPhase = .confirming

            guard let profile = context.user, AssistantWorkoutBuilder.hasRequiredProfileData(profile) else {
                resetWorkoutBuilderDraft()
                let gaps = AssistantWorkoutBuilder.profileGaps(for: context.user).map { "• \($0)" }.joined(separator: "\n")
                deliverDelayedWorkoutBuilderMessage("""
                Antes de montar, preciso dos seus dados básicos atualizados.

                \(gaps.isEmpty ? "• Complete peso, altura e idade em Perfil." : gaps)

                Atualize em **Perfil** (e biotipo em **Nutrição**) e diga de novo “montar treino”.

                \(AssistantWorkoutBuilder.professionalDisclaimer)
                """)
                return
            }

            deliverDelayedWorkoutBuilderMessage(
                AssistantWorkoutBuilder.confirmationSummary(
                    gender: draftWorkoutGender ?? .male,
                    focus: focus,
                    profile: profile,
                    experience: draftWorkoutExperience ?? .intermediate,
                    location: draftWorkoutLocation ?? .gym
                )
            )

        case .confirming:
            if AssistantWorkoutBuilder.isNegative(text) {
                resetWorkoutBuilderDraft()
                deliverDelayedWorkoutBuilderMessage(
                    "Tudo bem — cancelei a criação. Quando quiser, diga “montar treino” novamente."
                )
                return
            }

            guard AssistantWorkoutBuilder.isAffirmative(text) else {
                divertOrRepromptWorkoutBuilder(
                    text,
                    context: context,
                    pendingQuestion: "posso gerar a ficha? Responda **Sim, autorizo** ou **Não, cancelar**.",
                    fallback: "Para continuar, responda **Sim, autorizo** ou **Não, cancelar**."
                )
                return
            }

            guard let gender = draftWorkoutGender,
                  let focus = draftWorkoutFocus,
                  let experience = draftWorkoutExperience,
                  let location = draftWorkoutLocation,
                  let profile = context.user,
                  AssistantWorkoutBuilder.hasRequiredProfileData(profile) else {
                resetWorkoutBuilderDraft()
                deliverDelayedWorkoutBuilderMessage(
                    "Faltam dados do perfil. Atualize Perfil/Nutrição e peça “montar treino” de novo."
                )
                return
            }

            guard let workoutStore else {
                resetWorkoutBuilderDraft()
                deliverDelayedWorkoutBuilderMessage(
                    "Não consegui salvar a ficha agora. Tente novamente em instantes."
                )
                return
            }

            let sheet = AssistantWorkoutBuilder.buildSheet(
                gender: gender,
                focus: focus,
                profile: profile,
                experience: experience,
                location: location
            )
            workoutStore.addWorkoutSheet(sheet)
            resetWorkoutBuilderDraft()

            deliverDelayedWorkoutBuilderMessage("""
            Pronto! Com base no seu perfil (\(experience.summaryLabel(for: location))), criei a ficha **\(sheet.title)** com \(sheet.totalExercises) exercícios.

            \(AssistantWorkoutBuilder.createdSheetLocationHint(gender: gender, location: location))

            \(AssistantWorkoutBuilder.professionalDisclaimer)

            \(HealthAssistantEngine.healthSafetyDisclaimer)
            """)

        case .none:
            break
        }
    }

    /// Se a mensagem parece pergunta nova, responde primeiro e lembra a pergunta pendente do fluxo.
    private func divertOrRepromptWorkoutBuilder(
        _ text: String,
        context: HealthAssistantContext,
        pendingQuestion: String,
        fallback: String
    ) {
        guard PostWorkoutCheckInEngine.looksLikeOffTopicQuestion(text) else {
            deliverDelayedWorkoutBuilderMessage(fallback)
            return
        }

        deliverAfterMinimumTyping {
            let answer = HealthAssistantEngine.answer(for: text, context: context)
            let reminder = PostWorkoutCheckInEngine.pendingQuestionReminder(pendingQuestion)
            return "\(answer)\n\n\(reminder)"
        }
    }

    private func deliverDelayedWorkoutBuilderMessage(_ text: String) {
        deliverAfterMinimumTyping(minDuration: Self.workoutBuilderReplyDelay) { text }
    }

    func refreshGuidedCheckInsIfNeeded(context: HealthAssistantContext) {
        refreshPostWorkoutCheckInIfNeeded(context: context)
        if !isInPostWorkoutCheckIn {
            refreshDailyEveningCheckInIfNeeded(context: context)
            if !isInDailyEveningCheckIn {
                refreshDailyMorningCheckInIfNeeded(context: context)
            }
        }
    }

    func refreshPostWorkoutCheckInIfNeeded(context: HealthAssistantContext) {
        guard !isTyping else { return }

        if let checkIn = PostWorkoutCheckInService.shared.dueCheckIn {
            beginPostWorkoutCheckInIfNeeded(checkIn: checkIn, context: context)
        } else if PostWorkoutCheckInService.shared.isAwaitingFeelingReply,
                  let checkIn = PostWorkoutCheckInService.shared.pendingCheckIn {
            resumePostWorkoutCheckIn(checkIn: checkIn)
        }
    }

    func refreshDailyMorningCheckInIfNeeded(context: HealthAssistantContext) {
        guard !isTyping else { return }
        guard !isInPostWorkoutCheckIn else { return }
        guard !isInDailyEveningCheckIn else { return }
        guard !DailyEveningCheckInEngine.isCheckInWindowOpen() else { return }

        DailyMorningCheckInService.shared.refreshForToday()

        if DailyMorningCheckInService.shared.isDue,
           DailyMorningCheckInService.shared.state?.phase == .pending {
            beginDailyMorningCheckInIfNeeded(context: context)
        } else if DailyMorningCheckInService.shared.isAwaitingFeelingReply {
            isDailyMorningCheckInActive = true
        }
    }

    func beginDailyMorningCheckInIfNeeded(context: HealthAssistantContext) {
        guard DailyMorningCheckInService.shared.isDue,
              DailyMorningCheckInService.shared.state?.phase == .pending else { return }
        guard !isInPostWorkoutCheckIn else { return }
        guard activePostWorkoutCheckIn == nil else { return }
        guard !isDailyMorningCheckInActive || messages.isEmpty else { return }

        isDailyMorningCheckInActive = true
        let athleteName = context.user?.greetingName ?? ""

        isTyping = true
        replyTask?.cancel()
        replyTask = Task {
            do {
                try await Task.sleep(for: Self.replyDelay)
                guard !Task.isCancelled else { return }
                let opening = DailyMorningCheckInEngine.openingMessage(
                    athleteName: athleteName,
                    context: context
                )
                deliverAssistantMessage(opening)
                DailyMorningCheckInService.shared.markAskedFeeling()
                isTyping = false
                lastUserInteractionAt = Date()
            } catch {
                isTyping = false
            }
        }
    }

    func restoreInterruptedDailyMorningCheckIn(context: HealthAssistantContext) {
        isDailyMorningCheckInActive = true
        guard messages.isEmpty else { return }
        redeliverDailyMorningOpening(context: context)
    }

    private func handleDailyMorningReply(_ text: String, context: HealthAssistantContext) {
        if !DailyMorningCheckInEngine.isFeelingReply(text) {
            isTyping = true
            replyTask = Task {
                do {
                    try await Task.sleep(for: Self.replyDelay)
                    guard !Task.isCancelled else { return }
                    let answer = HealthAssistantEngine.answer(for: text, context: context)
                    let reminder = DailyMorningCheckInEngine.reminderToAnswerFeeling()
                    deliverAssistantMessage("\(answer)\n\n\(reminder)")
                    isTyping = false
                } catch {
                    isTyping = false
                }
            }
            return
        }

        let feeling = DailyMorningCheckInEngine.classifyFeeling(text)
        let responses = DailyMorningCheckInEngine.responseSequence(
            feeling: feeling,
            context: context
        )

        isTyping = true
        replyTask = Task {
            do {
                for response in responses {
                    try await Task.sleep(for: Self.replyDelay)
                    guard !Task.isCancelled else { return }
                    deliverAssistantMessage(response)
                }
                isDailyMorningCheckInActive = false
                DailyMorningCheckInService.shared.markCompleted()
                PostWorkoutCheckInService.shared.clearUnreadAssistantMessage()
                isTyping = false
            } catch {
                isTyping = false
            }
        }
    }

    private func redeliverDailyMorningOpening(context: HealthAssistantContext) {
        let athleteName = context.user?.greetingName ?? ""
        isTyping = true
        replyTask = Task {
            do {
                try await Task.sleep(for: Self.replyDelay)
                guard !Task.isCancelled else { return }
                let opening = DailyMorningCheckInEngine.openingMessage(
                    athleteName: athleteName,
                    context: context
                )
                deliverAssistantMessage(opening)
                isTyping = false
            } catch {
                isTyping = false
            }
        }
    }

    func refreshDailyEveningCheckInIfNeeded(context: HealthAssistantContext) {
        guard !isTyping else { return }
        guard !isInPostWorkoutCheckIn else { return }

        DailyEveningCheckInService.shared.refreshForToday()

        if DailyEveningCheckInService.shared.isDue,
           DailyEveningCheckInService.shared.state?.phase == .pending {
            beginDailyEveningCheckInIfNeeded(context: context)
        } else if DailyEveningCheckInService.shared.isAwaitingReply {
            isDailyEveningCheckInActive = true
        }
    }

    func beginDailyEveningCheckInIfNeeded(context: HealthAssistantContext) {
        guard DailyEveningCheckInService.shared.isDue,
              DailyEveningCheckInService.shared.state?.phase == .pending else { return }
        guard !isInPostWorkoutCheckIn else { return }
        guard activePostWorkoutCheckIn == nil else { return }
        guard !isDailyEveningCheckInActive || messages.isEmpty else { return }

        isDailyEveningCheckInActive = true
        lastEveningDayFeeling = nil
        let athleteName = context.user?.greetingName ?? ""

        isTyping = true
        replyTask?.cancel()
        replyTask = Task {
            do {
                try await Task.sleep(for: Self.replyDelay)
                guard !Task.isCancelled else { return }
                let opening = DailyEveningCheckInEngine.openingMessage(
                    athleteName: athleteName,
                    context: context
                )
                deliverAssistantMessage(opening)
                DailyEveningCheckInService.shared.markAskedDayReflection()
                isTyping = false
                lastUserInteractionAt = Date()
            } catch {
                isTyping = false
            }
        }
    }

    func restoreInterruptedDailyEveningCheckIn(context: HealthAssistantContext) {
        isDailyEveningCheckInActive = true
        guard messages.isEmpty else { return }
        redeliverDailyEveningOpening(context: context)
    }

    private func handleDailyEveningReply(_ text: String, context: HealthAssistantContext) {
        let phase = DailyEveningCheckInService.shared.state?.phase

        switch phase {
        case .askedDayReflection:
            handleEveningDayReflectionReply(text, context: context)
        case .askedRestReadiness:
            handleEveningRestReadinessReply(text, context: context)
        default:
            break
        }
    }

    private func handleEveningDayReflectionReply(_ text: String, context: HealthAssistantContext) {
        if !DailyEveningCheckInEngine.isDayFeelingReply(text) {
            isTyping = true
            replyTask = Task {
                do {
                    try await Task.sleep(for: Self.replyDelay)
                    guard !Task.isCancelled else { return }
                    let answer = HealthAssistantEngine.answer(for: text, context: context)
                    let reminder = DailyEveningCheckInEngine.reminderToAnswerDayFeeling()
                    deliverAssistantMessage("\(answer)\n\n\(reminder)")
                    isTyping = false
                } catch {
                    isTyping = false
                }
            }
            return
        }

        let feeling = DailyEveningCheckInEngine.classifyDayFeeling(text)
        lastEveningDayFeeling = feeling
        let followUp = DailyEveningCheckInEngine.dayReflectionFollowUp(
            feeling: feeling,
            context: context
        )

        isTyping = true
        replyTask = Task {
            do {
                try await Task.sleep(for: Self.replyDelay)
                guard !Task.isCancelled else { return }
                deliverAssistantMessage(followUp)
                DailyEveningCheckInService.shared.markAskedRestReadiness()
                isTyping = false
            } catch {
                isTyping = false
            }
        }
    }

    private func handleEveningRestReadinessReply(_ text: String, context: HealthAssistantContext) {
        if !DailyEveningCheckInEngine.isRestReadinessReply(text) {
            isTyping = true
            replyTask = Task {
                do {
                    try await Task.sleep(for: Self.replyDelay)
                    guard !Task.isCancelled else { return }
                    let answer = HealthAssistantEngine.answer(for: text, context: context)
                    let reminder = DailyEveningCheckInEngine.reminderToAnswerRestReadiness()
                    deliverAssistantMessage("\(answer)\n\n\(reminder)")
                    isTyping = false
                } catch {
                    isTyping = false
                }
            }
            return
        }

        let readiness = DailyEveningCheckInEngine.classifyRestReadiness(text)
        let dayFeeling = lastEveningDayFeeling ?? .neutral
        let responses = DailyEveningCheckInEngine.closingSequence(
            readiness: readiness,
            dayFeeling: dayFeeling,
            context: context
        )

        isTyping = true
        replyTask = Task {
            do {
                for response in responses {
                    try await Task.sleep(for: Self.replyDelay)
                    guard !Task.isCancelled else { return }
                    deliverAssistantMessage(response)
                }
                isDailyEveningCheckInActive = false
                lastEveningDayFeeling = nil
                DailyEveningCheckInService.shared.markCompleted()
                PostWorkoutCheckInService.shared.clearUnreadAssistantMessage()
                isTyping = false
            } catch {
                isTyping = false
            }
        }
    }

    private func redeliverDailyEveningOpening(context: HealthAssistantContext) {
        let athleteName = context.user?.greetingName ?? ""
        isTyping = true
        replyTask = Task {
            do {
                try await Task.sleep(for: Self.replyDelay)
                guard !Task.isCancelled else { return }
                let opening = DailyEveningCheckInEngine.openingMessage(
                    athleteName: athleteName,
                    context: context
                )
                deliverAssistantMessage(opening)
                isTyping = false
            } catch {
                isTyping = false
            }
        }
    }

    func beginPostWorkoutCheckInIfNeeded(checkIn: PendingPostWorkoutCheckIn, context: HealthAssistantContext) {
        guard checkIn.phase == .scheduled else { return }
        guard activePostWorkoutCheckIn?.sessionId != checkIn.sessionId || messages.isEmpty else { return }

        activePostWorkoutCheckIn = checkIn
        let athleteName = context.user?.greetingName ?? ""

        isTyping = true
        replyTask?.cancel()
        replyTask = Task {
            do {
                try await Task.sleep(for: Self.replyDelay)
                guard !Task.isCancelled else { return }
                let opening = PostWorkoutCheckInEngine.openingMessage(checkIn: checkIn, athleteName: athleteName)
                deliverAssistantMessage(opening)
                PostWorkoutCheckInService.shared.markAskedFeeling()
                activePostWorkoutCheckIn = PostWorkoutCheckInService.shared.pendingCheckIn
                isTyping = false
                lastUserInteractionAt = Date()
            } catch {
                isTyping = false
            }
        }
    }

    func resumePostWorkoutCheckIn(checkIn: PendingPostWorkoutCheckIn) {
        activePostWorkoutCheckIn = checkIn
    }

    func restoreInterruptedPostWorkoutCheckIn(checkIn: PendingPostWorkoutCheckIn, context: HealthAssistantContext) {
        resumePostWorkoutCheckIn(checkIn: checkIn)
        guard messages.isEmpty else { return }
        redeliverPostWorkoutOpening(checkIn: checkIn, context: context)
    }

    private func handlePostWorkoutReply(_ text: String, context: HealthAssistantContext) {
        guard let checkIn = activePostWorkoutCheckIn ?? PostWorkoutCheckInService.shared.pendingCheckIn else { return }

        // Pergunta paralela: responde o tema, mas mantém o check-in aberto.
        if !PostWorkoutCheckInEngine.isFeelingReply(text) {
            isTyping = true
            replyTask = Task {
                do {
                    try await Task.sleep(for: Self.replyDelay)
                    guard !Task.isCancelled else { return }
                    let answer = HealthAssistantEngine.answer(for: text, context: context)
                    let reminder = PostWorkoutCheckInEngine.reminderToAnswerFeeling(checkIn: checkIn)
                    deliverAssistantMessage("\(answer)\n\n\(reminder)")
                    isTyping = false
                } catch {
                    isTyping = false
                }
            }
            return
        }

        let feeling = PostWorkoutCheckInEngine.classifyFeeling(text)
        let athleteName = context.user?.greetingName ?? ""
        let responses = PostWorkoutCheckInEngine.responseSequence(
            feeling: feeling,
            checkIn: checkIn,
            athleteName: athleteName
        )

        isTyping = true
        replyTask = Task {
            do {
                for response in responses {
                    try await Task.sleep(for: Self.replyDelay)
                    guard !Task.isCancelled else { return }
                    deliverAssistantMessage(response)
                }
                activePostWorkoutCheckIn = nil
                PostWorkoutCheckInService.shared.markCompleted()
                PostWorkoutCheckInService.shared.clearIfCompleted()
                isTyping = false
            } catch {
                isTyping = false
            }
        }
    }

    func clear(context: HealthAssistantContext) {
        replyTask?.cancel()
        isTyping = false
        messages.removeAll()
        activePostWorkoutCheckIn = nil
        isDailyMorningCheckInActive = false
        isDailyEveningCheckInActive = false
        lastEveningDayFeeling = nil
        lastUserMessageAt = nil
        inactivityFollowUpDelivered = false
        cardioMeditationNudgeDelivered = false
        supplementNudgeDelivered = false
        tideAlertDelivered = false
        resetWorkoutBuilderDraft()

        if let checkIn = PostWorkoutCheckInService.shared.dueCheckIn {
            beginPostWorkoutCheckInIfNeeded(checkIn: checkIn, context: context)
        } else if PostWorkoutCheckInService.shared.isAwaitingFeelingReply,
                  let checkIn = PostWorkoutCheckInService.shared.pendingCheckIn {
            resumePostWorkoutCheckIn(checkIn: checkIn)
            redeliverPostWorkoutOpening(checkIn: checkIn, context: context)
        } else if DailyEveningCheckInService.shared.isDue,
                  DailyEveningCheckInService.shared.state?.phase == .pending {
            beginDailyEveningCheckInIfNeeded(context: context)
        } else if DailyEveningCheckInService.shared.isAwaitingReply {
            restoreInterruptedDailyEveningCheckIn(context: context)
        } else if DailyMorningCheckInService.shared.isDue,
                  DailyMorningCheckInService.shared.state?.phase == .pending {
            beginDailyMorningCheckInIfNeeded(context: context)
        } else if DailyMorningCheckInService.shared.isAwaitingFeelingReply {
            restoreInterruptedDailyMorningCheckIn(context: context)
        } else {
            bootstrap(context: context)
        }
    }

    private func redeliverPostWorkoutOpening(checkIn: PendingPostWorkoutCheckIn, context: HealthAssistantContext) {
        let athleteName = context.user?.greetingName ?? ""
        isTyping = true
        replyTask = Task {
            do {
                try await Task.sleep(for: Self.replyDelay)
                guard !Task.isCancelled else { return }
                let opening = PostWorkoutCheckInEngine.openingMessage(checkIn: checkIn, athleteName: athleteName)
                deliverAssistantMessage(opening)
                isTyping = false
            } catch {
                isTyping = false
            }
        }
    }

    func recordUserInteraction() {
        lastUserInteractionAt = Date()
    }

    func checkInactivityFollowUpIfNeeded(
        context: HealthAssistantContext,
        sessions: [WorkoutSession]
    ) {
        guard !messages.isEmpty else { return }
        guard !isTyping else { return }
        guard !inactivityFollowUpDelivered else { return }

        let lastAssistantPrompt = messages.last(where: { !$0.isUser })?.timestamp
        guard AssistantInactivityFollowUpEngine.shouldDeliverFollowUp(
            lastUserMessageAt: lastUserMessageAt,
            lastAssistantPromptAt: lastAssistantPrompt
        ) else { return }

        let text = AssistantInactivityFollowUpEngine.message(context: context, sessions: sessions)
        if let last = messages.last, !last.isUser, last.text == text { return }

        deliverAssistantMessage(text)
        inactivityFollowUpDelivered = true
        lastUserInteractionAt = Date()
    }

    func checkCardioMeditationNudgeIfNeeded(
        context: HealthAssistantContext,
        sessions: [WorkoutSession],
        accountCreatedAt: Date?
    ) {
        guard !isTyping else { return }
        guard !isInGuidedCheckIn else { return }
        guard !cardioMeditationNudgeDelivered else { return }

        guard let evaluation = AssistantCardioMeditationNudgeEngine.evaluate(
            sessions: sessions,
            recordedCardioAt: NotificationService.shared.lastRecordedCardioAt,
            recordedMeditationAt: NotificationService.shared.lastRecordedMeditationAt,
            accountCreatedAt: accountCreatedAt
        ) else { return }

        let needsCardio = evaluation.cardioReference.map {
            !NotificationService.shared.hasAssistantCardioNudge(for: $0)
        } ?? false
        let needsMeditation = evaluation.meditationReference.map {
            !NotificationService.shared.hasAssistantMeditationNudge(for: $0)
        } ?? false

        let kindToDeliver: AssistantCardioMeditationNudgeKind?
        switch evaluation.kind {
        case .both:
            if needsCardio && needsMeditation {
                kindToDeliver = .both
            } else if needsCardio {
                kindToDeliver = .cardio
            } else if needsMeditation {
                kindToDeliver = .meditation
            } else {
                kindToDeliver = nil
            }
        case .cardio:
            kindToDeliver = needsCardio ? .cardio : nil
        case .meditation:
            kindToDeliver = needsMeditation ? .meditation : nil
        }

        guard let kindToDeliver else {
            cardioMeditationNudgeDelivered = true
            return
        }

        let name = context.user?.greetingName ?? "Atleta"
        let text = AssistantCardioMeditationNudgeEngine.message(kind: kindToDeliver, athleteName: name)
        if let last = messages.last, !last.isUser, last.text == text {
            cardioMeditationNudgeDelivered = true
            return
        }

        deliverAssistantMessage(text)
        switch kindToDeliver {
        case .cardio:
            if let reference = evaluation.cardioReference {
                NotificationService.shared.markAssistantCardioNudgeDelivered(for: reference)
            }
        case .meditation:
            if let reference = evaluation.meditationReference {
                NotificationService.shared.markAssistantMeditationNudgeDelivered(for: reference)
            }
        case .both:
            if let reference = evaluation.cardioReference {
                NotificationService.shared.markAssistantCardioNudgeDelivered(for: reference)
            }
            if let reference = evaluation.meditationReference {
                NotificationService.shared.markAssistantMeditationNudgeDelivered(for: reference)
            }
        }
        cardioMeditationNudgeDelivered = true
        lastUserInteractionAt = Date()
    }

    func checkSupplementNudgeIfNeeded(
        context: HealthAssistantContext,
        todayIntakes: [SupplementIntakeEntry]
    ) {
        guard !isTyping else { return }
        guard !isInGuidedCheckIn else { return }
        guard !supplementNudgeDelivered else { return }

        guard AssistantSupplementNudgeEngine.shouldDeliverDailyNudge(todayIntakes: todayIntakes) else {
            supplementNudgeDelivered = true
            return
        }

        let name = context.user?.greetingName ?? "Atleta"
        let text = AssistantSupplementNudgeEngine.dailyNudgeMessage(athleteName: name)
        if let last = messages.last, !last.isUser, last.text == text {
            supplementNudgeDelivered = true
            AssistantSupplementNudgeEngine.markDailyNudgeDelivered()
            return
        }

        deliverAssistantMessage(text)
        AssistantSupplementNudgeEngine.markDailyNudgeDelivered()
        supplementNudgeDelivered = true
        lastUserInteractionAt = Date()
    }

    /// Alerta de maré para quem pratica Surf / Kitesurf (no máximo 1×/dia).
    func checkTideAlertIfNeeded(
        context: HealthAssistantContext,
        sessions: [WorkoutSession]
    ) {
        guard !isTyping else { return }
        guard !isInGuidedCheckIn else { return }
        guard !tideAlertDelivered else { return }

        let name = context.user?.greetingName ?? "Atleta"
        guard let text = AssistantTideAlertEngine.proactiveMessageIfNeeded(
            athleteName: name,
            sessions: sessions,
            snapshot: OpenMeteoWindService.shared.lastSuccessfulSnapshot
        ) else {
            tideAlertDelivered = true
            return
        }

        if let last = messages.last, !last.isUser, last.text == text {
            tideAlertDelivered = true
            return
        }

        deliverAssistantMessage(text)
        tideAlertDelivered = true
        lastUserInteractionAt = Date()
    }

    func handleTabReturn() {
        guard hasAppearedOnce else {
            hasAppearedOnce = true
            lastUserInteractionAt = Date()
            return
        }

        guard !isInGuidedCheckIn else { return }

        let idleSeconds = Date().timeIntervalSince(lastUserInteractionAt)
        guard idleSeconds >= Self.idleReturnThreshold else { return }

        appendIdleReturnMessageIfNeeded()
        lastUserInteractionAt = Date()
    }

    private func appendIdleReturnMessageIfNeeded() {
        guard !isTyping else { return }

        let text = HealthAssistantEngine.idleReturnMessage
        if let last = messages.last, !last.isUser, last.text == text { return }

        deliverAssistantMessage(text)
    }

    #if DEBUG
    func setLastUserInteractionForTests(_ date: Date) {
        lastUserInteractionAt = date
    }

    func setLastUserMessageForTests(_ date: Date?) {
        lastUserMessageAt = date
    }

    func setInactivityFollowUpDeliveredForTests(_ delivered: Bool) {
        inactivityFollowUpDelivered = delivered
    }
    #endif

    func clear(userName: String?) {
        clear(context: HealthAssistantContext(
            user: userName.map { UserProfile(name: $0, email: "") },
            waterIntakeMl: 0,
            sleepHours: nil,
            weeklyWorkoutCount: 0,
            hoursSinceLastWorkout: nil,
            todayWorkoutSessions: [],
            recentWorkoutSessions: [],
            dailyCalorieTarget: 0,
            basalMetabolicRate: 0,
            estimatedTDEE: 0,
            caloricDeficit: 0,
            sweetConsumption: .moderate,
            lactoseTolerance: nil,
            hasMealPlan: false,
            todayMealsCompleted: 0,
            todayMealsTotal: 0,
            weekMealsCompleted: 0,
            weekMealsTotal: 0,
            supplementsLoggedToday: 0
        ))
    }
}
