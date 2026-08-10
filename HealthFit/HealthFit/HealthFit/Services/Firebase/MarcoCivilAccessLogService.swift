import FirebaseFirestore
import Foundation
import UIKit

/// Registros de acesso à aplicação (Marco Civil da Internet — Lei 12.965/2014, art. 15).
/// Retenção: 6 meses em ambiente controlado (Firestore); exclusão automática após o prazo.
enum MarcoCivilAccessLogService {
    /// Prazo de retenção dos registros de acesso (meses).
    static let retentionMonths = 6

    enum Event: String {
        case register
        case login
        case sessionStart
        case logout
    }

    private static var db: Firestore { Firestore.firestore() }
    private static var isAvailable: Bool { FirebaseBootstrap.isConfigured }

    private static func collection() -> CollectionReference {
        db.collection("accessLogs")
    }

    /// Grava um registro de acesso e remove logs do usuário já vencidos (> 6 meses).
    static func record(event: Event, userId: String) async {
        guard isAvailable, !userId.isEmpty else { return }

        let now = Date()
        let expiresAt = Calendar.current.date(
            byAdding: .month,
            value: retentionMonths,
            to: now
        ) ?? now.addingTimeInterval(TimeInterval(retentionMonths) * 30 * 24 * 3600)

        let ip = await resolvePublicIP()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

        var data: [String: Any] = [
            "userId": userId,
            "event": event.rawValue,
            "createdAt": Timestamp(date: now),
            "expiresAt": Timestamp(date: expiresAt),
            "retentionMonths": retentionMonths,
            "legalBasis": "Marco Civil da Internet — Lei 12.965/2014, art. 15",
            "appVersion": appVersion,
            "appBuild": build,
            "deviceModel": UIDevice.current.model,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion,
            "sessionId": currentSessionId(),
        ]
        if let ip, !ip.isEmpty {
            data["ipAddress"] = ip
        }

        do {
            try await collection().addDocument(data: data)
        } catch {
            print("[HealthFit] AccessLog record failed: \(error.localizedDescription)")
        }

        await purgeExpiredLogs(forUserId: userId)
    }

    /// Remove registros com `expiresAt` anterior a agora (próprios do usuário).
    static func purgeExpiredLogs(forUserId userId: String) async {
        guard isAvailable, !userId.isEmpty else { return }
        do {
            // Filtro de expiração no cliente — evita índice composto obrigatório.
            let snap = try await collection()
                .whereField("userId", isEqualTo: userId)
                .limit(to: 80)
                .getDocuments()
            let now = Date()
            let expired = snap.documents.filter { doc in
                guard let expires = (doc.data()["expiresAt"] as? Timestamp)?.dateValue() else {
                    return false
                }
                return expires < now
            }
            guard !expired.isEmpty else { return }
            let batch = db.batch()
            for doc in expired.prefix(50) {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        } catch {
            print("[HealthFit] AccessLog purge failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Session throttle

    private static let sessionIdKey = "healthfit.marco_civil.session_id"
    private static let lastSessionStartKeyPrefix = "healthfit.marco_civil.last_session_start."

    private static func currentSessionId() -> String {
        if let existing = UserDefaults.standard.string(forKey: sessionIdKey), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: sessionIdKey)
        return id
    }

    /// Registra no máximo um `sessionStart` por dia civil (evita inundar o Firestore).
    static func recordSessionStartIfNeeded(userId: String) async {
        guard !userId.isEmpty else { return }
        let key = lastSessionStartKeyPrefix + userId
        let last = UserDefaults.standard.object(forKey: key) as? Date
        if let last, Calendar.current.isDateInToday(last) {
            return
        }
        UserDefaults.standard.set(Date(), forKey: key)
        await record(event: .sessionStart, userId: userId)
    }

    static func rotateSessionId() {
        UserDefaults.standard.set(UUID().uuidString, forKey: sessionIdKey)
    }

    // MARK: - IP (melhor esforço)

    private static func resolvePublicIP() async -> String? {
        guard let url = URL(string: "https://api.ipify.org?format=text") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let ip = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let ip, !ip.isEmpty, ip.count <= 64 else { return nil }
            return ip
        } catch {
            return nil
        }
    }
}
