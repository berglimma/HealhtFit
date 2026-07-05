import SwiftUI
import WebKit

enum LegalDocument: String, Identifiable {
    case privacyPolicy
    case termsOfUse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacyPolicy: "Política de Privacidade"
        case .termsOfUse: "Termos de Uso"
        }
    }

    var resourceName: String {
        switch self {
        case .privacyPolicy: "privacy-policy"
        case .termsOfUse: "terms-of-use"
        }
    }

    var htmlContent: String? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "html") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss

    let document: LegalDocument

    var body: some View {
        NavigationStack {
            Group {
                if let html = document.htmlContent {
                    LegalHTMLWebView(html: html)
                } else {
                    ContentUnavailableView(
                        "Documento indisponível",
                        systemImage: "doc.text",
                        description: Text("Não foi possível carregar \(document.title).")
                    )
                }
            }
            .background(AppTheme.background)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

private struct LegalHTMLWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedHTML: String?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if url.scheme == "mailto" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}
