import Foundation

enum PasswordPolicy {
    static let minimumLength = 8

    enum Requirement: String, CaseIterable, Identifiable {
        case minLength
        case uppercase
        case lowercase
        case number
        case specialCharacter

        var id: String { rawValue }

        var label: String {
            switch self {
            case .minLength:
                return "Pelo menos \(PasswordPolicy.minimumLength) caracteres"
            case .uppercase:
                return "Pelo menos 1 letra maiúscula (A–Z)"
            case .lowercase:
                return "Pelo menos 1 letra minúscula (a–z)"
            case .number:
                return "Pelo menos 1 número (0–9)"
            case .specialCharacter:
                return "Pelo menos 1 caractere especial (!@#$%…)"
            }
        }

        func isSatisfied(by password: String) -> Bool {
            switch self {
            case .minLength:
                return password.count >= PasswordPolicy.minimumLength
            case .uppercase:
                return password.rangeOfCharacter(from: .uppercaseLetters) != nil
            case .lowercase:
                return password.rangeOfCharacter(from: .lowercaseLetters) != nil
            case .number:
                return password.rangeOfCharacter(from: .decimalDigits) != nil
            case .specialCharacter:
                return password.rangeOfCharacter(from: Self.specialCharacterSet) != nil
            }
        }

        private static let specialCharacterSet = CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:'\",.<>/?`~\\")
    }

    static func evaluate(_ password: String) -> [(requirement: Requirement, isSatisfied: Bool)] {
        Requirement.allCases.map { ($0, $0.isSatisfied(by: password)) }
    }

    static func isValid(_ password: String) -> Bool {
        Requirement.allCases.allSatisfy { $0.isSatisfied(by: password) }
    }

    static var summaryHint: String {
        "Mín. \(minimumLength) caracteres, com maiúscula, minúscula, número e símbolo"
    }

    static var failureMessage: String {
        "A senha deve ter no mínimo \(minimumLength) caracteres, incluindo letra maiúscula, minúscula, número e caractere especial."
    }
}
