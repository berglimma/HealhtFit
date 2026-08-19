import SwiftUI
import MessageUI

struct LegalLinksView: View {
    var style: Style = .inline
    var showsSupportLink = false

    @State private var presentedDocument: LegalDocument?
    @State private var showSupport = false

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
        .sheet(isPresented: $showSupport) {
            SupportContactView()
        }
    }

    private var inlineLinks: some View {
        VStack(spacing: 6) {
            ViewThatFits(in: .horizontal) {
                legalLinksRow
                    .fixedSize(horizontal: true, vertical: false)

                VStack(spacing: 4) {
                    legalButton(title: "Política de Privacidade", document: .privacyPolicy)
                    legalButton(title: "Termos de Uso", document: .termsOfUse)
                }
            }
            .font(.caption)
            .multilineTextAlignment(.center)

            if showsSupportLink {
                Button("Suporte") {
                    showSupport = true
                }
                .font(.caption)
                .foregroundStyle(AppTheme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    private var legalLinksRow: some View {
        HStack(spacing: 4) {
            legalButton(title: "Política de Privacidade", document: .privacyPolicy)
            Text("·")
                .foregroundStyle(AppTheme.textSecondary)
            legalButton(title: "Termos de Uso", document: .termsOfUse)
        }
    }

    private var listLinks: some View {
        Group {
            legalRow(title: "Política de Privacidade", icon: "hand.raised", document: .privacyPolicy)
            legalRow(title: "Termos de Uso", icon: "doc.text", document: .termsOfUse)
            if showsSupportLink {
                Button {
                    showSupport = true
                } label: {
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

enum AppFeedbackKind: String, CaseIterable, Identifiable {
    case complaint = "Reclamação"
    case suggestion = "Sugestão"
    case improvement = "Melhoria"
    case question = "Dúvida"

    var id: String { rawValue }
}

struct SupportContactView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Fale com a equipe HealthFit sobre a sua conta, treinos ou o funcionamento do aplicativo.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } footer: {
                    Text("O destino da mensagem fica só com o app — o endereço de e-mail não é exibido.")
                }

                AppFeedbackFormSections()
            }
            .navigationTitle("Suporte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

/// Formulário de reclamações, sugestões, melhorias e dúvidas.
/// O destinatário vai em cópia oculta (BCC) e não aparece na tela do HealthFit.
struct AppFeedbackFormSections: View {
    @EnvironmentObject private var authService: AuthService

    @State private var kind: AppFeedbackKind = .suggestion
    @State private var message = ""
    @State private var mailDraft: AppFeedbackMailDraft?
    @State private var isSending = false
    @State private var showSentAlert = false
    @State private var showFailedAlert = false
    @State private var failureMessage = "Tente de novo em instantes."

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !trimmedMessage.isEmpty && !isSending && mailDraft == nil
    }

    var body: some View {
        Section {
            Picker("Tipo", selection: $kind) {
                ForEach(AppFeedbackKind.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.menu)
            .disabled(isSending)

            ZStack(alignment: .topLeading) {
                if trimmedMessage.isEmpty {
                    Text("Escreva sua reclamação, sugestão, melhoria ou dúvida…")
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $message)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .disabled(isSending)
            }

            Button {
                sendFeedback()
            } label: {
                HStack {
                    Spacer()
                    if isSending {
                        ProgressView()
                            .tint(AppTheme.accent)
                    } else {
                        Label("Enviar", systemImage: "paperplane.fill")
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .disabled(!canSend)
            .tint(AppTheme.accent)
        } header: {
            Text("Feedback do aplicativo")
        }
        .sheet(item: $mailDraft, onDismiss: {
            isSending = false
        }) { draft in
            MailComposeView(
                recipients: [AppLegalConfiguration.supportEmail],
                subject: draft.subject,
                body: draft.body
            ) { result in
                mailDraft = nil
                isSending = false
                switch result {
                case .sent:
                    let sentKind = draft.kind
                    let sentText = draft.message
                    let sentName = draft.accountName
                    let sentEmail = draft.accountEmail
                    message = ""
                    showSentAlert = true
                    Task {
                        await AppFeedbackFirestoreService.persistIfPossible(
                            kind: sentKind,
                            message: sentText,
                            accountName: sentName,
                            accountEmail: sentEmail
                        )
                    }
                case .failed:
                    failureMessage = MailSetupGuidance.sendFailedMessage
                    showFailedAlert = true
                default:
                    break
                }
            }
        }
        .alert("Feedback enviado", isPresented: $showSentAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Obrigado. Sua mensagem foi enviada para \(AppLegalConfiguration.supportEmail).")
        }
        .alert("Não foi possível enviar", isPresented: $showFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failureMessage)
        }
    }

    private func sendFeedback() {
        let text = trimmedMessage
        guard !text.isEmpty, !isSending else { return }

        guard MailComposeView.canSendMail else {
            failureMessage = MailSetupGuidance.unavailableMessage
            showFailedAlert = true
            return
        }

        let user = authService.currentUser
        let name = user?.greetingName ?? user?.name ?? "—"
        let account = user?.email ?? "—"
        isSending = true
        mailDraft = AppFeedbackMailDraft(
            kind: kind.rawValue,
            message: text,
            accountName: name,
            accountEmail: account,
            subject: "HealthFit · \(kind.rawValue)",
            body: AppFeedbackFirestoreService.composedBody(
                kind: kind.rawValue,
                message: text,
                accountName: name,
                accountEmail: account
            )
        )
    }
}

private struct AppFeedbackMailDraft: Identifiable {
    let id = UUID()
    let kind: String
    let message: String
    let accountName: String
    let accountEmail: String
    let subject: String
    let body: String
}
