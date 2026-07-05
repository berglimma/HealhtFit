import Foundation
import FirebaseAuth

enum AuthErrorMapper {
    static func message(for error: Error) -> String {
        if let social = error as? SocialSignInError,
           let description = social.errorDescription {
            return description
        }

        let nsError = error as NSError

        if nsError.domain == AuthErrorDomain,
           let code = AuthErrorCode(rawValue: nsError.code) {
            return message(for: code)
        }

        if nsError.domain == NSURLErrorDomain {
            return "Sem conexão. Verifique sua internet e tente novamente."
        }

        return "Não foi possível concluir a operação. Tente novamente."
    }

    private static func message(for code: AuthErrorCode) -> String {
        switch code {
        case .invalidEmail:
            return "E-mail inválido."
        case .wrongPassword, .invalidCredential:
            return "E-mail ou senha incorretos."
        case .userNotFound:
            return "Não encontramos uma conta com este e-mail."
        case .emailAlreadyInUse:
            return "Este e-mail já está cadastrado."
        case .weakPassword:
            return "Senha muito fraca. Use pelo menos 6 caracteres."
        case .networkError:
            return "Sem conexão. Verifique sua internet e tente novamente."
        case .tooManyRequests:
            return "Muitas tentativas. Aguarde alguns minutos e tente novamente."
        case .userDisabled:
            return "Esta conta foi desativada."
        case .operationNotAllowed:
            return "Este método de login não está habilitado no Firebase."
        case .accountExistsWithDifferentCredential:
            return "Já existe uma conta com este e-mail usando outro método de login."
        case .requiresRecentLogin:
            return "Por segurança, confirme sua identidade novamente antes de excluir a conta."
        default:
            return "Não foi possível concluir a operação. Tente novamente."
        }
    }
}
