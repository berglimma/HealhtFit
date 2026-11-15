import Foundation

/// Contas com cortesia estendida (90 dias). Somente estes e-mails.
enum CourtesySpecialAccounts {
    static let durationDays = 90
    static let plan: PlanTier = .complete
    static let code = "ADMIN-SPECIAL-COMPLETE-90D"

    private static let emails: Set<String> = [
        "berg.limma@gmail.com",
        "cristianeribeiiro14@gmail.com",
    ]

    static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isSpecial(_ email: String?) -> Bool {
        guard let email, !email.isEmpty else { return false }
        return emails.contains(normalize(email))
    }
}
