import Foundation

enum AppLegalConfiguration {
    /// URLs públicas com `Content-Type: text/html` (jsDelivr serve HTML como text/plain).
  private static let publicBase = "https://healthfit-30d87.web.app"

    static let privacyPolicyURL = URL(string: "\(publicBase)/privacidade/")!
    static let termsOfUseURL = URL(string: "\(publicBase)/termos/")!
    static let supportEmail = "berg.limma@gmail.com"
    /// App Store exige URL https (não mailto) no campo Support URL.
    static let supportURL = URL(string: "\(publicBase)/suporte/")!
    static let marketingURL = URL(string: "\(publicBase)/")!
}
