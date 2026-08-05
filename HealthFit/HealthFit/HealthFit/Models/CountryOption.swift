import Foundation

/// Países comuns + código ISO-2 para bandeira emoji no perfil.
struct CountryOption: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }

    var flagEmoji: String {
        Self.flagEmoji(for: code)
    }

    /// Regional Indicator Symbol: BR → 🇧🇷
    static func flagEmoji(for isoCode: String) -> String {
        let code = isoCode.uppercased()
        guard code.count == 2,
              code.unicodeScalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) }) else {
            return "🏳️"
        }
        let base: UInt32 = 127_397
        var result = ""
        for scalar in code.unicodeScalars {
            if let flag = UnicodeScalar(base + scalar.value) {
                result.unicodeScalars.append(flag)
            }
        }
        return result.isEmpty ? "🏳️" : result
    }

    static let catalog: [CountryOption] = [
        CountryOption(code: "BR", name: "Brasil"),
        CountryOption(code: "PT", name: "Portugal"),
        CountryOption(code: "US", name: "Estados Unidos"),
        CountryOption(code: "AR", name: "Argentina"),
        CountryOption(code: "ES", name: "Espanha"),
        CountryOption(code: "FR", name: "França"),
        CountryOption(code: "IT", name: "Itália"),
        CountryOption(code: "DE", name: "Alemanha"),
        CountryOption(code: "GB", name: "Reino Unido"),
        CountryOption(code: "MX", name: "México"),
        CountryOption(code: "CO", name: "Colômbia"),
        CountryOption(code: "CL", name: "Chile"),
        CountryOption(code: "UY", name: "Uruguai"),
        CountryOption(code: "PY", name: "Paraguai"),
        CountryOption(code: "PE", name: "Peru"),
        CountryOption(code: "CA", name: "Canadá"),
        CountryOption(code: "JP", name: "Japão"),
        CountryOption(code: "AU", name: "Austrália"),
        CountryOption(code: "NZ", name: "Nova Zelândia"),
        CountryOption(code: "ZA", name: "África do Sul"),
        CountryOption(code: "NL", name: "Países Baixos"),
        CountryOption(code: "BE", name: "Bélgica"),
        CountryOption(code: "CH", name: "Suíça"),
        CountryOption(code: "AT", name: "Áustria"),
        CountryOption(code: "IE", name: "Irlanda"),
        CountryOption(code: "PL", name: "Polônia"),
        CountryOption(code: "SE", name: "Suécia"),
        CountryOption(code: "NO", name: "Noruega"),
        CountryOption(code: "DK", name: "Dinamarca"),
        CountryOption(code: "FI", name: "Finlândia"),
        CountryOption(code: "RU", name: "Rússia"),
        CountryOption(code: "CN", name: "China"),
        CountryOption(code: "KR", name: "Coreia do Sul"),
        CountryOption(code: "IN", name: "Índia"),
        CountryOption(code: "ID", name: "Indonésia"),
        CountryOption(code: "TH", name: "Tailândia"),
        CountryOption(code: "PH", name: "Filipinas"),
        CountryOption(code: "AE", name: "Emirados Árabes"),
        CountryOption(code: "MA", name: "Marrocos"),
        CountryOption(code: "EG", name: "Egito"),
        CountryOption(code: "AO", name: "Angola"),
        CountryOption(code: "MZ", name: "Moçambique")
    ].sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    static func option(for code: String?) -> CountryOption? {
        guard let code, !code.isEmpty else { return nil }
        return catalog.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }

    static func defaultCode(from locale: Locale = .current) -> String {
        if let region = locale.region?.identifier, region.count == 2 {
            return region.uppercased()
        }
        return "BR"
    }
}
