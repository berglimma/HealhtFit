import Foundation

enum AccountDeletionError: LocalizedError {
    case appleReauthenticationRequired

    var errorDescription: String? {
        switch self {
        case .appleReauthenticationRequired:
            return "Confirme com a Apple para excluir sua conta."
        }
    }
}
