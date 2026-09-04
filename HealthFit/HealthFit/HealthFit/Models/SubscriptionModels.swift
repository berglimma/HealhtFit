import Foundation

// MARK: - Periodicidade

enum SubscriptionBillingPeriod: String, CaseIterable, Identifiable, Codable, Hashable {
    case monthly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly: return "Mensal"
        case .yearly: return "Anual"
        }
    }

    /// Desconto do plano anual em relação a 12× o mensal (marketing + referência local).
    static let yearlyDiscountPercent = 20
}

// MARK: - Catalogo de produtos (App Store Connect)

/// IDs de assinatura. Criar com **os mesmos strings** no App Store Connect.
enum SubscriptionProductID: String, CaseIterable, Identifiable, Codable {
    case basicMonthly = "healthfit.plan.basic.monthly"
    case fitMonthly = "healthfit.plan.fit.monthly"
    case aiMonthly = "healthfit.plan.ai.monthly"
    case completeMonthly = "healthfit.plan.complete.monthly"

    case basicYearly = "healthfit.plan.basic.yearly"
    case fitYearly = "healthfit.plan.fit.yearly"
    case aiYearly = "healthfit.plan.ai.yearly"
    case completeYearly = "healthfit.plan.complete.yearly"

    var id: String { rawValue }

    var tier: PlanTier {
        switch self {
        case .basicMonthly, .basicYearly: return .basic
        case .fitMonthly, .fitYearly: return .fit
        case .aiMonthly, .aiYearly: return .ai
        case .completeMonthly, .completeYearly: return .complete
        }
    }

    var billingPeriod: SubscriptionBillingPeriod {
        switch self {
        case .basicMonthly, .fitMonthly, .aiMonthly, .completeMonthly:
            return .monthly
        case .basicYearly, .fitYearly, .aiYearly, .completeYearly:
            return .yearly
        }
    }

    /// Produtos oferecidos no paywall (mensal + anual com desconto).
    static var storefrontCatalog: [SubscriptionProductID] {
        [
            .basicMonthly, .fitMonthly, .aiMonthly, .completeMonthly,
            .basicYearly, .fitYearly, .aiYearly, .completeYearly
        ]
    }

    static func productID(tier: PlanTier, period: SubscriptionBillingPeriod) -> SubscriptionProductID? {
        switch (tier, period) {
        case (.basic, .monthly): return .basicMonthly
        case (.fit, .monthly): return .fitMonthly
        case (.ai, .monthly): return .aiMonthly
        case (.complete, .monthly): return .completeMonthly
        case (.basic, .yearly): return .basicYearly
        case (.fit, .yearly): return .fitYearly
        case (.ai, .yearly): return .aiYearly
        case (.complete, .yearly): return .completeYearly
        case (.free, _): return nil
        }
    }

    static var allKnownIDs: [String] {
        allCases.map(\.rawValue)
    }
}

// MARK: - Planos

enum PlanTier: Int, CaseIterable, Codable, Comparable, Identifiable {
    case free = 0
    case basic = 1
    case fit = 2
    case ai = 3
    case complete = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .free: return "Gratuito"
        case .basic: return "Básico"
        case .fit: return "Fit"
        case .ai: return "IA Plus"
        case .complete: return "Completo"
        }
    }

    /// Preço mensal de referência (Apple define o valor real na Connect).
    var referencePriceBRL: String {
        switch self {
        case .free: return "R$ 0"
        case .basic: return "R$ 9,90"
        case .fit: return "R$ 12,90"
        case .ai: return "R$ 19,90"
        case .complete: return "R$ 24,90"
        }
    }

    /// Preço anual de referência (~20% off vs 12× mensal).
    var referenceYearlyPriceBRL: String {
        switch self {
        case .free: return "R$ 0"
        case .basic: return "R$ 94,90"
        case .fit: return "R$ 123,90"
        case .ai: return "R$ 190,90"
        case .complete: return "R$ 239,90"
        }
    }

    /// Equivalente mensal do anual, para comparação no paywall.
    var referenceYearlyPerMonthBRL: String {
        switch self {
        case .free: return "R$ 0"
        case .basic: return "R$ 7,91"
        case .fit: return "R$ 10,33"
        case .ai: return "R$ 15,91"
        case .complete: return "R$ 19,99"
        }
    }

    var tagline: String {
        switch self {
        case .free: return "Comece com o essencial"
        case .basic: return "Treine todo dia no iPhone e Watch"
        case .fit: return "Treino + cardápio + foco em metas calóricas"
        case .ai: return "IA no dia a dia + análises de evolução"
        case .complete: return "Plano completo HealthFit, sem limites"
        }
    }

    var monthlyProductID: SubscriptionProductID? {
        SubscriptionProductID.productID(tier: self, period: .monthly)
    }

    var yearlyProductID: SubscriptionProductID? {
        SubscriptionProductID.productID(tier: self, period: .yearly)
    }

    func productID(for period: SubscriptionBillingPeriod) -> SubscriptionProductID? {
        SubscriptionProductID.productID(tier: self, period: period)
    }

    var isPaid: Bool { self != .free }

    static func < (lhs: PlanTier, rhs: PlanTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Tier efetivo = maior entre todas as entitlements ativas (upgrade entre planos).
    static func highest(of tiers: [PlanTier]) -> PlanTier {
        tiers.max() ?? .free
    }
}

// MARK: - Features

enum AppFeature: String, CaseIterable, Identifiable {
    case fullWorkouts
    case appleWatchSync
    case duoTeam
    case customWorkouts
    case advancedModalities
    case mealPlan
    case shoppingList
    case nutritionCoach
    case mealPhotoAnalysis
    case aiChatLimited
    case advancedSportAnalytics
    case aiChatUnlimited
    case monthlyReport
    case bodyEvolutionExport
    case liveActivityPremium
    case completePriority
    case healthFitCoach

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullWorkouts: return "Treinos completos"
        case .appleWatchSync: return "Sincronização Apple Watch"
        case .duoTeam: return "Treino em dupla / equipe"
        case .customWorkouts: return "Criar treinos personalizados"
        case .advancedModalities: return "Modalidades avançadas"
        case .mealPlan: return "Cardápio e nutrição"
        case .shoppingList: return "Lista de compras"
        case .nutritionCoach: return "Orientação nutricional assistida"
        case .mealPhotoAnalysis: return "Análise de refeição por foto"
        case .aiChatLimited: return "Assistente IA (limitado)"
        case .advancedSportAnalytics: return "Diários e análise por modalidade"
        case .aiChatUnlimited: return "Assistente IA ilimitado"
        case .monthlyReport: return "Relatórios e análise mensal"
        case .bodyEvolutionExport: return "Evolução corporal / exportação"
        case .liveActivityPremium: return "Live Activity e insights premium"
        case .completePriority: return "Acesso prioritário / tudo liberado"
        case .healthFitCoach: return "HealthFit Coach (personal / nutri)"
        }
    }

    /// Frase de upsell exibida na tela bloqueada e no paywall.
    var upsellDescription: String {
        switch self {
        case .fullWorkouts:
            return "Fichas de musculação, treino em casa, mobilidade e corrida com GPS."
        case .appleWatchSync:
            return "Batimentos, calorias e controle da sessão no Apple Watch."
        case .duoTeam:
            return "Crie equipes, convide parceiros, chat e ranking — sem localização ao vivo."
        case .customWorkouts:
            return "Monte e edite suas próprias fichas de treino."
        case .advancedModalities:
            return "Surf, Kitesurf, Remo, Escalada e Luta — modalidades com sensores dedicados, cronômetro de combate e registro de condições."
        case .mealPlan:
            return "Cardápio do dia, metas calóricas e registro de refeições."
        case .shoppingList:
            return "Lista de compras gerada a partir do seu cardápio."
        case .nutritionCoach:
            return "Orientação nutricional assistida dentro do app."
        case .mealPhotoAnalysis:
            return "Tire foto do prato ou do rótulo e estime macros com IA — recurso do plano IA Plus."
        case .aiChatLimited:
            return "Converse com o IAssistente sobre treino, sono e recuperação."
        case .advancedSportAnalytics:
            return "Diários de natação, bike, surf/kite e escalada: evolução por grau, taxa de sucesso, volume semanal, mapa de áreas e inspeção de equipamento."
        case .aiChatUnlimited:
            return "IAssistente sem limite diário de mensagens."
        case .monthlyReport:
            return "Relatório mensal com tendências e comparativos."
        case .bodyEvolutionExport:
            return "Comparativo de fotos e exportação em PDF."
        case .liveActivityPremium:
            return "Live Activity na tela de bloqueio e insights avançados."
        case .completePriority:
            return "Tudo liberado, sem limites."
        case .healthFitCoach:
            return "Receba fichas do personal, cardápio do nutricionista e chat 1:1 — o profissional não paga; você precisa do plano Fit ou superior."
        }
    }

    /// Menor plano que libera a feature (alinhado ao ROADMAP).
    var minimumTier: PlanTier {
        switch self {
        case .fullWorkouts, .appleWatchSync, .duoTeam:
            return .basic
        case .customWorkouts, .advancedModalities, .mealPlan, .shoppingList, .aiChatLimited, .healthFitCoach:
            return .fit
        case .nutritionCoach, .mealPhotoAnalysis, .advancedSportAnalytics, .aiChatUnlimited,
             .monthlyReport, .bodyEvolutionExport, .liveActivityPremium:
            return .ai
        case .completePriority:
            return .complete
        }
    }
}

// MARK: - Limites por plano

extension PlanTier {
    /// Mensagens diárias no IAssistente. `nil` = sem limite.
    var dailyAssistantMessageLimit: Int? {
        switch self {
        case .free, .basic: return 0
        case .fit: return 5
        case .ai, .complete: return nil
        }
    }
}

// MARK: - Feature gate

enum FeatureGate {
    static func canAccess(_ feature: AppFeature, tier: PlanTier, gatesEnabled: Bool = SubscriptionConfiguration.featureGatesEnabled) -> Bool {
        guard gatesEnabled else { return true }
        return tier >= feature.minimumTierEffective
    }

    static func minimumPlan(for feature: AppFeature) -> PlanTier {
        feature.minimumTierEffective
    }
}

private extension AppFeature {
    /// Ajuste fino: Básico tem treinos full; Fit tem custom (sugerido: basic limitado).
    var minimumTierEffective: PlanTier {
        switch self {
        case .customWorkouts:
            // Fase 1: custom exige Fit; free/basic usam catálogo.
            return .fit
        default:
            return minimumTier
        }
    }
}

// MARK: - Configuração (App Store Connect)

enum SubscriptionConfiguration {
    static let subscriptionGroupName = "HealthFit Plans"
    /// ID do grupo na App Store Connect (HealthFit Plans).
    static let subscriptionGroupID = "22332052"

    /// Bloqueios por plano ativos em produção.
    static let featureGatesEnabled = true
}

// MARK: - Marketing / copy paywall

struct PlanMarketingCopy: Identifiable, Hashable {
    let tier: PlanTier
    var id: PlanTier { tier }

    var isFeatured: Bool { tier == .complete }

    var bulletPoints: [String] {
        switch tier {
        case .free:
            return [
                "Dashboard básico",
                "Check-ins e treinos limitados",
                "Sem cartão"
            ]
        case .basic:
            return ["Treinos guiados e cardio", "Apple Watch", "Treino em dupla (Duo)", "Metas de treino"]
        case .fit:
            return [
                "Tudo do Básico",
                "Surf, Kitesurf, Remo, Escalada e Luta",
                "Criar treinos personalizados",
                "Cardápio, metas e lista de compras",
                "IAssistente com 5 mensagens por dia"
            ]
        case .ai:
            return [
                "Tudo do Fit",
                "IAssistente ilimitado",
                "Análise de refeição por foto",
                "Diários e evolução por modalidade",
                "Relatório mensal e evolução corporal em PDF"
            ]
        case .complete:
            return ["Tudo liberado", "Prioridade no app", "Sem limites de recursos premium"]
        }
    }
}
