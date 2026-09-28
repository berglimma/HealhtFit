import Foundation
import StoreKit

/// Ambiente de distribuição do binário (App Store vs TestFlight/Debug).
enum AppDistribution {
    /// Vouchers de cortesia (30 dias) só em Debug e TestFlight — nunca no binário da App Store (Guideline 3.1.1).
    static var allowsCourtesyVoucherRedeem: Bool {
        #if DEBUG
        return true
        #else
        return isTestFlight
        #endif
    }

    /// TestFlight / sandbox StoreKit (`AppStore.Environment` ≠ `.production`).
    static var isTestFlight: Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cachedIsNonProduction ?? false
    }

    private static let cacheLock = NSLock()
    private static var cachedIsNonProduction: Bool?

    /// Resolve o ambiente via `AppTransaction.shared` (substitui `appStoreReceiptURL`, deprecado no iOS 18).
    static func refreshEnvironment() async {
        #if DEBUG
        setCachedIsNonProduction(true)
        return
        #else
        do {
            let result = try await AppTransaction.shared
            switch result {
            case .verified(let transaction):
                // TestFlight e sandbox usam `.sandbox`; StoreKit Testing usa `.xcode`.
                setCachedIsNonProduction(transaction.environment != .production)
            case .unverified:
                // Falha de verificação: tratar como App Store (seguro para 3.1.1).
                setCachedIsNonProduction(false)
            }
        } catch {
            setCachedIsNonProduction(false)
        }
        #endif
    }

    private static func setCachedIsNonProduction(_ value: Bool) {
        cacheLock.lock()
        cachedIsNonProduction = value
        cacheLock.unlock()
    }
}
