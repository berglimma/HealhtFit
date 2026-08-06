import Foundation

enum AppLegalConfiguration {
    /// Páginas públicas via GitHub Pages (workflow `.github/workflows/pages.yml`).
    /// Quando blswiftsolutions.com estiver online, troque o `publicBase`.
    private static let publicBase = "https://berglimma.github.io/HealhtFit"

    static let privacyPolicyURL = URL(string: "\(publicBase)/privacidade/")!
    static let termsOfUseURL = URL(string: "\(publicBase)/termos/")!
    static let developerNames = "Berg Limma e Luan Chiminelli"
    static let supportEmail = "berg.limma@gmail.com"
    /// App Store exige URL https (não mailto) no campo Support URL.
    static let supportURL = URL(string: "\(publicBase)/suporte/")!
    static let marketingURL = URL(string: "\(publicBase)/")!
}
