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
    case customWorkouts
    case advancedModalities
    case mealPlan
    case shoppingList
    case nutritionCoach
    case aiChatLimited
    case advancedSportAnalytics
    case aiChatUnlimited
    case monthlyReport
    case bodyEvolutionExport
    case liveActivityPremium
    case completePriority

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullWorkouts: return "Treinos completos"
        case .appleWatchSync: return "Sincronização Apple Watch"
        case .customWorkouts: return "Criar treinos personalizados"
        case .advancedModalities: return "Modalidades avançadas"
        case .mealPlan: return "Cardápio e nutrição"
        case .shoppingList: return "Lista de compras"
        case .nutritionCoach: return "Orientação nutricional assistida"
        case .aiChatLimited: return "Assistente IA (limitado)"
        case .advancedSportAnalytics: return "Diários e análise por modalidade"
        case .aiChatUnlimited: return "Assistente IA ilimitado"
        case .monthlyReport: return "Relatórios e análise mensal"
        case .bodyEvolutionExport: return "Evolução corporal / exportação"
        case .liveActivityPremium: return "Live Activity e insights premium"
        case .completePriority: return "Acesso prioritário / tudo liberado"
        }
    }

    /// Frase de upsell exibida na tela bloqueada e no paywall.
    var upsellDescription: String {
        switch self {
        case .fullWorkouts:
            return "Todas as fichas de musculação, treino em casa e mobilidade."
        case .appleWatchSync:
            return "Batimentos, calorias e controle da sessão no Apple Watch."
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
        }
    }

    /// Menor plano que libera a feature.
    var minimumTier: PlanTier {
        switch self {
        case .mealPlan, .shoppingList, .nutritionCoach:
            return .free
        case .fullWorkouts, .appleWatchSync:
            return .basic
        case .customWorkouts, .advancedModalities, .aiChatLimited:
            return .fit
        case .advancedSportAnalytics, .aiChatUnlimited, .monthlyReport,
             .bodyEvolutionExport, .liveActivityPremium:
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
    /// Com `gatesEnabled == false`, tudo liberado (modo preparação / soft launch).
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

// MARK: - Configuração de rollout

enum SubscriptionConfiguration {
    static let subscriptionGroupName = "HealthFit Plans"
    static let subscriptionGroupIDPlaceholder = "COLE_O_GROUP_ID_DA_CONNECT"

    /// Bloqueios por plano. **Desligados por padrão** (soft launch / testes).
    /// Reative em DEBUG → Meu plano → “Ativar feature gates”, ou mude o default abaixo
    /// quando for cobrar assinatura de novo.
    static var featureGatesEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: gatesKey) != nil else { return false }
            return UserDefaults.standard.bool(forKey: gatesKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: gatesKey) }
    }

    /// Chave nova para ignorar valor antigo que deixava os gates ligados.
    private static let gatesKey = "healthfit.subscription.gatesEnabled.testingOff"

    #if DEBUG
    /// Em DEBUG, permite simular plano sem compra (Perfil → Meu plano).
    static var debugPlanOverride: PlanTier? {
        get {
            let raw = UserDefaults.standard.integer(forKey: debugTierKey)
            // 0 é free; usamos -1 sentinel “sem override”
            if UserDefaults.standard.object(forKey: debugTierKey) == nil { return nil }
            if raw == -1 { return nil }
            return PlanTier(rawValue: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.rawValue, forKey: debugTierKey)
            } else {
                UserDefaults.standard.set(-1, forKey: debugTierKey)
            }
        }
    }

    private static let debugTierKey = "healthfit.subscription.debugTier"
    #endif
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
                "Cardápio, metas calóricas e lista de compras",
                "Check-ins e treinos limitados",
                "Sem cartão"
            ]
        case .basic:
            return ["Treinos guiados e cardio", "Apple Watch", "Metas de treino", "Nutrição incluída"]
        case .fit:
            return [
                "Tudo do Básico",
                "Surf, Kitesurf, Remo, Escalada e Luta",
                "Criar treinos personalizados",
                "IAssistente com 5 mensagens por dia"
            ]
        case .ai:
            return [
                "Tudo do Fit",
                "IAssistente ilimitado",
                "Diários e evolução por modalidade",
                "Relatório mensal e evolução corporal em PDF"
            ]
        case .complete:
            return ["Tudo liberado", "Prioridade no app", "Sem limites de recursos premium"]
        }
    }
}
