import SwiftUI

struct LegalLinksView: View {
    var style: Style = .inline
    var showsSupportLink = false

    @State private var presentedDocument: LegalDocument?

    enum Style {
        case inline
        case list
    }

    var body: some View {
        Group {
            switch style {
            case .inline:
                inlineLinks
            case .list:
                listLinks
            }
        }
        .sheet(item: $presentedDocument) { document in
            LegalDocumentView(document: document)
        }
    }

    private var inlineLinks: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                legalButton(title: "Política de Privacidade", document: .privacyPolicy)
                Text("·")
                    .foregroundStyle(AppTheme.textSecondary)
                legalButton(title: "Termos de Uso", document: .termsOfUse)
            }
            .font(.caption)
            .multilineTextAlignment(.center)

            if showsSupportLink {
                Link("Suporte: \(AppLegalConfiguration.supportEmail)", destination: AppLegalConfiguration.supportURL)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var listLinks: some View {
        Group {
            legalRow(title: "Política de Privacidade", icon: "hand.raised", document: .privacyPolicy)
            legalRow(title: "Termos de Uso", icon: "doc.text", document: .termsOfUse)
            if showsSupportLink {
                Link(destination: AppLegalConfiguration.supportURL) {
                    Label("Suporte", systemImage: "envelope")
                }
            }
        }
    }

    private func legalButton(title: String, document: LegalDocument) -> some View {
        Button(title) {
            presentedDocument = document
        }
        .foregroundStyle(AppTheme.accent)
    }

    private func legalRow(title: String, icon: String, document: LegalDocument) -> some View {
        Button {
            presentedDocument = document
        } label: {
            Label(title, systemImage: icon)
        }
    }
}
