import Foundation

enum AppLegalConfiguration {
    /// URLs públicas estáveis (jsDelivr espelha o `main`).
    /// O GitHub Pages legado ainda pode servir política antiga (13+);
    /// estas URLs garantem a versão 16+ publicada no repositório.
    private static let publicBase =
        "https://cdn.jsdelivr.net/gh/berglimma/HealhtFit@main/Docs"

    static let privacyPolicyURL = URL(string: "\(publicBase)/privacidade/index.html")!
    static let termsOfUseURL = URL(string: "\(publicBase)/termos/index.html")!
    static let supportEmail = "berg.limma@gmail.com"
    /// App Store exige URL https (não mailto) no campo Support URL.
    static let supportURL = URL(string: "\(publicBase)/suporte/index.html")!
    static let marketingURL = URL(string: "\(publicBase)/index.html")!
}
