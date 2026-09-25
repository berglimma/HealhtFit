import Foundation

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

    /// TestFlight (e sandbox) usam `sandboxReceipt`; a App Store usa `receipt`.
    static var isTestFlight: Bool {
        guard let url = Bundle.main.appStoreReceiptURL else { return false }
        return url.lastPathComponent == "sandboxReceipt"
    }
}
