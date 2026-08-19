import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

enum CourtesyVoucherError: LocalizedError {
    case notSignedIn
    case unavailable
    case invalidCode
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Entre na sua conta para resgatar o código de cortesia."
        case .unavailable:
            return "Não foi possível falar com o servidor agora. Tente de novo."
        case .invalidCode:
            return "Código inválido. Confira e tente de novo."
        case .server(let message):
            return message
        }
    }
}

/// Resgata vouchers de cortesia (Cloud Function) e lê o brinde ativo no Firestore.
enum CourtesyVoucherService {
    private static let grantsCollection = "courtesyGrants"
    private static let cacheKeyPrefix = "healthfit.courtesy.grant."
    private static let functionsRegion = "southamerica-east1"

    static func cachedGrant(userId: String) -> CourtesyGrant? {
        guard let data = UserDefaults.standard.data(forKey: cacheKeyPrefix + userId),
              let payload = try? JSONDecoder().decode(CachedGrant.self, from: data) else {
            return nil
        }
        return payload.grant
    }

    static func clearCache(userId: String?) {
        if let userId, !userId.isEmpty {
            UserDefaults.standard.removeObject(forKey: cacheKeyPrefix + userId)
        }
    }

    static func fetchGrant(userId: String) async -> CourtesyGrant? {
        guard FirebaseBootstrap.isConfigured, !userId.isEmpty else {
            return cachedGrant(userId: userId)
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection(grantsCollection)
                .document(userId)
                .getDocument()
            guard let data = snapshot.data() else {
                clearCache(userId: userId)
                return nil
            }
            guard let grant = grant(from: data) else {
                return cachedGrant(userId: userId)
            }
            persistCache(grant, userId: userId)
            return grant.isActive ? grant : nil
        } catch {
            return cachedGrant(userId: userId)?.isActive == true
                ? cachedGrant(userId: userId)
                : nil
        }
    }

    static func redeem(code rawCode: String) async throws -> CourtesyGrant {
        let code = CourtesyVoucher.normalize(rawCode)
        guard CourtesyVoucher.isValidFormat(code) else {
            throw CourtesyVoucherError.invalidCode
        }
        guard FirebaseBootstrap.isConfigured else {
            throw CourtesyVoucherError.unavailable
        }
        guard let user = Auth.auth().currentUser else {
            throw CourtesyVoucherError.notSignedIn
        }

        let token = try await user.getIDToken()
        let url = try callableURL(name: "redeemCourtesyVoucher")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "data": ["code": code],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        if let errorMessage = callableErrorMessage(from: data) {
            throw CourtesyVoucherError.server(errorMessage)
        }
        guard (200..<300).contains(status) else {
            throw CourtesyVoucherError.unavailable
        }

        let payload = try JSONDecoder().decode(CallableRedeemResponse.self, from: data)
        let result = payload.result
        guard let plan = PlanTier(courtesyRaw: result.plan) else {
            throw CourtesyVoucherError.unavailable
        }
        let grant = CourtesyGrant(
            plan: plan,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(result.expiresAtMs) / 1000),
            code: code,
            durationDays: result.durationDays
        )
        persistCache(grant, userId: user.uid)
        return grant
    }

    // MARK: - Internals

    private static func persistCache(_ grant: CourtesyGrant, userId: String) {
        let payload = CachedGrant(
            planRaw: grant.plan.courtesyRawValue,
            expiresAt: grant.expiresAt.timeIntervalSince1970,
            code: grant.code,
            durationDays: grant.durationDays
        )
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: cacheKeyPrefix + userId)
        }
    }

    private static func grant(from data: [String: Any]) -> CourtesyGrant? {
        let planRaw = data["plan"] as? String
        guard let planRaw, let plan = PlanTier(courtesyRaw: planRaw) else { return nil }
        let expiresAt: Date
        if let timestamp = data["expiresAt"] as? Timestamp {
            expiresAt = timestamp.dateValue()
        } else if let millis = data["expiresAtMs"] as? Int64 {
            expiresAt = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        } else {
            return nil
        }
        let code = (data["code"] as? String) ?? ""
        let durationDays = data["durationDays"] as? Int ?? CourtesyVoucher.durationDays
        return CourtesyGrant(plan: plan, expiresAt: expiresAt, code: code, durationDays: durationDays)
    }

    private static func callableURL(name: String) throws -> URL {
        let projectID = FirebaseApp.app()?.options.projectID ?? "healthfit-30d87"
        let string = "https://\(functionsRegion)-\(projectID).cloudfunctions.net/\(name)"
        guard let url = URL(string: string) else {
            throw CourtesyVoucherError.unavailable
        }
        return url
    }

    private static func callableErrorMessage(from data: Data) -> String? {
        guard let payload = try? JSONDecoder().decode(CallableErrorResponse.self, from: data),
              let message = payload.error.message,
              !message.isEmpty else { return nil }
        return message
    }
}

private struct CachedGrant: Codable {
    var planRaw: String
    var expiresAt: TimeInterval
    var code: String
    var durationDays: Int

    var grant: CourtesyGrant? {
        guard let plan = PlanTier(courtesyRaw: planRaw) else { return nil }
        let value = CourtesyGrant(
            plan: plan,
            expiresAt: Date(timeIntervalSince1970: expiresAt),
            code: code,
            durationDays: durationDays
        )
        return value.isActive ? value : nil
    }
}

private struct CallableRedeemResponse: Decodable {
    let result: RedeemResult

    struct RedeemResult: Decodable {
        let plan: String
        let expiresAtMs: Int64
        let durationDays: Int
    }
}

private struct CallableErrorResponse: Decodable {
    let error: Body

    struct Body: Decodable {
        let message: String?
        let status: String?
    }
}

private extension PlanTier {
    var courtesyRawValue: String {
        switch self {
        case .free: return "free"
        case .basic: return "basic"
        case .fit: return "fit"
        case .ai: return "ai"
        case .complete: return "complete"
        }
    }

    init?(courtesyRaw: String) {
        switch courtesyRaw.lowercased() {
        case "basic": self = .basic
        case "fit": self = .fit
        case "ai": self = .ai
        case "complete": self = .complete
        default: return nil
        }
    }
}
