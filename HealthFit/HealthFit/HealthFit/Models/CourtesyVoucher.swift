import Foundation

/// Cortesia de plano (brinde do HealthFit, sem cobrança na App Store).
enum CourtesyVoucher {
    static let durationDays = 30
    static let codesPerPaidPlan = 20
    static let batchID = "launch-v1-30d"

    /// Sem 0/O/1/I/L para facilitar digitação.
    static let alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

    static var paidPlans: [PlanTier] { [.basic, .fit, .ai, .complete] }

    static func planPrefix(for tier: PlanTier) -> String? {
        switch tier {
        case .basic: return "BASIC"
        case .fit: return "FIT"
        case .ai: return "AI"
        case .complete: return "COMPLETE"
        case .free: return nil
        }
    }

    static func plan(fromNormalizedCode code: String) -> PlanTier? {
        let parts = code.split(separator: "-")
        guard parts.count >= 3, parts[0] == "HF" else { return nil }
        switch parts[1] {
        case "BASIC": return .basic
        case "FIT": return .fit
        case "AI": return .ai
        case "COMPLETE": return .complete
        default: return nil
        }
    }

    static func normalize(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    static func isValidFormat(_ code: String) -> Bool {
        let normalized = normalize(code)
        guard let plan = plan(fromNormalizedCode: normalized),
              let prefix = planPrefix(for: plan) else { return false }
        let expectedPrefix = "HF-\(prefix)-"
        guard normalized.hasPrefix(expectedPrefix) else { return false }
        let suffix = String(normalized.dropFirst(expectedPrefix.count))
        guard suffix.count == 6 else { return false }
        return suffix.allSatisfy { alphabet.contains($0) }
    }
}

struct CourtesyGrant: Equatable, Sendable {
    let plan: PlanTier
    let expiresAt: Date
    let code: String
    let durationDays: Int

    var isActive: Bool { expiresAt > Date() }

    var expirationDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: expiresAt)
    }
}
