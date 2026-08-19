import FirebaseAuth
import FirebaseFirestore
import Foundation

enum AppFeedbackError: LocalizedError {
    case unavailable
    case notSignedIn
    case invalidMessage
    case mailNotConfigured

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Não foi possível enviar o e-mail agora. Tente de novo em instantes."
        case .notSignedIn:
            return "Entre na sua conta para enviar o feedback."
        case .invalidMessage:
            return "Escreva uma mensagem antes de enviar."
        case .mailNotConfigured:
            return MailSetupGuidance.unavailableMessage
        }
    }
}

/// Arquiva o feedback na conta. O e-mail sai pelo Mail do aparelho (BCC oculto na UI do HealthFit).
enum AppFeedbackFirestoreService {
    static let maxMessageLength = 4_000

    static let allowedKinds: Set<String> = [
        "Reclamação", "Sugestão", "Melhoria", "Dúvida",
    ]

    static func composedBody(
        kind: String,
        message: String,
        accountName: String,
        accountEmail: String
    ) -> String {
        """
        Tipo: \(kind)

        \(message)

        —
        App: HealthFit \(AppInfo.appVersion)
        Conta: \(accountName)
        E-mail da conta: \(accountEmail)
        """
    }

    static func persistIfPossible(
        kind: String,
        message: String,
        accountName: String,
        accountEmail: String
    ) async {
        guard FirebaseBootstrap.isConfigured else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, allowedKinds.contains(kind) else { return }

        let document = Firestore.firestore().collection("appFeedback").document()
        try? await document.setData([
            "userId": uid,
            "kind": kind,
            "message": String(trimmed.prefix(maxMessageLength)),
            "accountName": String(accountName.prefix(120)),
            "accountEmail": String(accountEmail.prefix(200)),
            "appVersion": AppInfo.appVersion,
            "createdAt": FieldValue.serverTimestamp(),
        ])
    }
}
