import Foundation
import StoreKit

import Combine
/// StoreKit 2 — carrega produtos, compra, restaura e resolve o plano ativo.
@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published private(set) var products: [Product] = []
    @Published private(set) var storeTier: PlanTier = .free
    /// Product ID ativo mais recente (mensal ou anual) — para UI de “já ativo”.
    @Published private(set) var activeProductID: String?
    @Published private(set) var isLoading = false
    @Published private(set) var purchaseInProgress = false
    @Published var lastErrorMessage: String?
    @Published private(set) var isConfigured = false

    /// Plano efetivo (StoreKit + override DEBUG opcional).
    var currentTier: PlanTier {
        #if DEBUG
        if let override = SubscriptionConfiguration.debugPlanOverride {
            return override
        }
        #endif
        return storeTier
    }

    var isSubscribed: Bool { currentTier.isPaid }

    var activeBillingPeriod: SubscriptionBillingPeriod? {
        guard let activeProductID,
              let product = SubscriptionProductID(rawValue: activeProductID) else { return nil }
        return product.billingPeriod
    }

    private var transactionListener: Task<Void, Never>?

    private var didStartRefresh = false

    private init() {
        // Listener only — product fetch runs after first frames via `refreshIfNeeded()`.
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - API pública

    /// Carrega produtos/entitlements uma vez, adiado do cold-start.
    func refreshIfNeeded() async {
        guard !didStartRefresh else { return }
        didStartRefresh = true
        await refresh()
    }

    func canAccess(_ feature: AppFeature) -> Bool {
        FeatureGate.canAccess(feature, tier: currentTier)
    }

    func product(for tier: PlanTier, period: SubscriptionBillingPeriod = .monthly) -> Product? {
        guard let id = tier.productID(for: period)?.rawValue else { return nil }
        return products.first { $0.id == id }
    }

    func displayPrice(for tier: PlanTier, period: SubscriptionBillingPeriod = .monthly) -> String {
        if let product = product(for: tier, period: period) {
            switch period {
            case .monthly:
                return "\(product.displayPrice)/mês"
            case .yearly:
                return "\(product.displayPrice)/ano"
            }
        }
        switch period {
        case .monthly:
            return "\(tier.referencePriceBRL)/mês"
        case .yearly:
            return "\(tier.referenceYearlyPriceBRL)/ano"
        }
    }

    /// Preço mostrado no card: no anual, destaca o equivalente mensal + total.
    func displayPriceHeadline(for tier: PlanTier, period: SubscriptionBillingPeriod) -> String {
        switch period {
        case .monthly:
            return displayPrice(for: tier, period: .monthly)
        case .yearly:
            if let product = product(for: tier, period: .yearly),
               let monthly = equivalentMonthlyPrice(from: product) {
                return "\(monthly)/mês"
            }
            return "\(tier.referenceYearlyPerMonthBRL)/mês"
        }
    }

    func displayPriceSubtitle(for tier: PlanTier, period: SubscriptionBillingPeriod) -> String? {
        guard period == .yearly else { return nil }
        return displayPrice(for: tier, period: .yearly)
    }

    func savingsBadge() -> String {
        "Economize \(SubscriptionBillingPeriod.yearlyDiscountPercent)%"
    }

    func isActive(tier: PlanTier, period: SubscriptionBillingPeriod) -> Bool {
        guard currentTier == tier else { return false }
        #if DEBUG
        if SubscriptionConfiguration.debugPlanOverride != nil {
            // Override de DEBUG não distingue período.
            return period == (activeBillingPeriod ?? .monthly)
        }
        #endif
        guard let activeProductID,
              let product = SubscriptionProductID(rawValue: activeProductID) else {
            return false
        }
        return product.tier == tier && product.billingPeriod == period
    }

    func refresh() async {
        didStartRefresh = true
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }

        await loadProducts()
        await updateEntitlementsFromStore()
        isConfigured = true
    }

    func purchase(tier: PlanTier, period: SubscriptionBillingPeriod = .monthly) async -> Bool {
        await refreshIfNeeded()
        guard let product = product(for: tier, period: period) else {
            lastErrorMessage = "Plano indisponível no momento. Verifique a conexão ou tente mais tarde."
            return false
        }
        return await purchase(product)
    }

    func purchase(_ product: Product) async -> Bool {
        purchaseInProgress = true
        lastErrorMessage = nil
        defer { purchaseInProgress = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await apply(transaction: transaction)
                await transaction.finish()
                await updateEntitlementsFromStore()
                return true
            case .userCancelled:
                return false
            case .pending:
                lastErrorMessage = "Compra pendente de aprovação (Controles parentais / Ask to Buy)."
                return false
            @unknown default:
                lastErrorMessage = "Resultado de compra desconhecido."
                return false
            }
        } catch {
            lastErrorMessage = friendlyError(error)
            return false
        }
    }

    func restore() async {
        await refreshIfNeeded()
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateEntitlementsFromStore()
            if storeTier == .free {
                lastErrorMessage = "Nenhuma assinatura ativa encontrada para esta conta Apple."
            }
        } catch {
            lastErrorMessage = friendlyError(error)
        }
    }

    // MARK: - StoreKit internals

    private func loadProducts() async {
        do {
            let ids = SubscriptionProductID.storefrontCatalog.map(\.rawValue)
            let loaded = try await Product.products(for: ids)
            products = loaded.sorted { lhs, rhs in
                let lProduct = SubscriptionProductID(rawValue: lhs.id)
                let rProduct = SubscriptionProductID(rawValue: rhs.id)
                let lTier = lProduct?.tier.rawValue ?? 0
                let rTier = rProduct?.tier.rawValue ?? 0
                if lTier != rTier { return lTier < rTier }
                let lPeriod = lProduct?.billingPeriod == .yearly ? 1 : 0
                let rPeriod = rProduct?.billingPeriod == .yearly ? 1 : 0
                return lPeriod < rPeriod
            }
            if products.isEmpty {
                // Normal em Simulator sem .storekit ligado / produtos ainda inexistentes na Connect.
                lastErrorMessage = nil
            }
        } catch {
            lastErrorMessage = friendlyError(error)
            products = []
        }
    }

    private func updateEntitlementsFromStore() async {
        var active: [PlanTier] = []
        var bestProductID: String?
        var bestTier = PlanTier.free
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < Date() { continue }
            if let product = SubscriptionProductID(rawValue: transaction.productID) {
                active.append(product.tier)
                if product.tier >= bestTier {
                    bestTier = product.tier
                    bestProductID = transaction.productID
                }
            }
        }
        storeTier = PlanTier.highest(of: active)
        activeProductID = bestProductID
    }

    private func apply(transaction: Transaction) async {
        if let product = SubscriptionProductID(rawValue: transaction.productID) {
            storeTier = max(storeTier, product.tier)
            activeProductID = transaction.productID
        }
    }

    private func equivalentMonthlyPrice(from yearlyProduct: Product) -> String? {
        // StoreKit não expõe “por mês” do anual; estimamos pelo preço / 12 no locale do produto.
        let yearly = yearlyProduct.price as Decimal
        let monthly = yearly / 12
        var rounded = monthly
        var result = Decimal()
        NSDecimalRound(&result, &rounded, 2, .plain)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: result as NSDecimalNumber)
    }

    private func listenForTransactions() -> Task<Void, Never> {
        let box = WeakMainActorBox(self)
        return Task {
            for await result in Transaction.updates {
                await box.runAsync { this in
                    do {
                        let transaction = try this.checkVerified(result)
                        await this.apply(transaction: transaction)
                        await transaction.finish()
                        await this.updateEntitlementsFromStore()
                    } catch {
                        this.lastErrorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    private func friendlyError(_ error: Error) -> String {
        if let sk = error as? StoreKitError {
            switch sk {
            case .notAvailableInStorefront:
                return "Assinaturas indisponíveis nesta região da App Store."
            case .networkError:
                return "Sem conexão com a App Store. Tente de novo."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}
