import SwiftUI
import MessageUI
import UIKit

/// Texto único sobre o requisito do app Mail (iPhone/iPad) para relatórios.
enum MailSetupGuidance {
    static var isConfigured: Bool {
        MailComposeView.canSendMail
    }

    static var deviceName: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }

    static let settingsPath = "Ajustes → Mail → Contas"

    static var requiredMessage: String {
        "O iOS não permite enviar e-mail em segundo plano. Para mandar relatórios ao personal ou nutricionista, configure uma conta no app Mail (\(settingsPath)) neste \(deviceName)."
    }

    static var trainerNotice: String {
        if isConfigured {
            return "Após o treino, toque em enviar: o relatório abre no Mail deste \(deviceName) para você confirmar. Sem o Mail configurado, o envio por e-mail não funciona."
        }
        return "Para enviar o relatório ao personal, é preciso ter o app Mail configurado neste \(deviceName) (\(settingsPath)). Sem isso, use Compartilhar para mandar por Gmail, Outlook ou outro app."
    }

    static var nutritionistNotice: String {
        if isConfigured {
            return "O relatório de nutrição abre no Mail deste \(deviceName) para você confirmar o envio ao nutricionista."
        }
        return "Para enviar o relatório ao nutricionista, configure uma conta no app Mail (\(settingsPath)) neste \(deviceName). Sem o Mail, use Compartilhar (Gmail, Outlook ou outro app)."
    }

    static var sendFailedMessage: String {
        "Não foi possível enviar o e-mail. Verifique se há uma conta no app Mail (\(settingsPath)) neste \(deviceName)."
    }

    static var unavailableMessage: String {
        "Configure uma conta no app Mail (\(settingsPath)) neste \(deviceName). Sem o Mail, use Compartilhar para enviar o relatório por Gmail, Outlook ou outro app."
    }
}

/// Aviso visível: relatórios por e-mail exigem o Mail do aparelho.
struct MailAccountRequiredNotice: View {
    enum Audience {
        case trainer
        case nutritionist
    }

    var audience: Audience = .trainer

    var body: some View {
        let configured = MailSetupGuidance.isConfigured
        VStack(alignment: .leading, spacing: 6) {
            Label(
                configured
                    ? "Mail configurado neste \(MailSetupGuidance.deviceName)"
                    : "Mail não configurado neste \(MailSetupGuidance.deviceName)",
                systemImage: configured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(configured ? AppTheme.accent : Color.orange)

            Text(audience == .trainer ? MailSetupGuidance.trainerNotice : MailSetupGuidance.nutritionistNotice)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Anexo opcional para `MFMailComposeViewController` (ex.: mapa da rota).
struct MailAttachment: Equatable {
    let data: Data
    let mimeType: String
    let fileName: String
}

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    var bccRecipients: [String] = []
    let subject: String
    let body: String
    /// Quando `true`, `body` é HTML (preferível com anexos de imagem).
    var isHTML: Bool = false
    var attachments: [MailAttachment] = []
    var onFinish: (MFMailComposeResult) -> Void = { _ in }

    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    /// Limite prático de `mailto:` (URLs muito longas falham no iOS / Gmail).
    static let mailtoBodyCharacterLimit = 1_800

    static func mailtoURL(recipients: [String], subject: String, body: String) -> URL? {
        guard let recipient = recipients.first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !recipient.isEmpty,
              recipient.contains("@") else {
            return nil
        }

        // Corpo grande demais → não gera mailto (caller deve usar share sheet).
        guard body.count <= mailtoBodyCharacterLimit else { return nil }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        guard let url = components.url, url.absoluteString.count < 8_000 else {
            return nil
        }
        return url
    }

    /// Grava o corpo do relatório em arquivo temporário para compartilhar (Mail / Gmail / etc.).
    static func writeShareableReportFile(
        subject: String,
        body: String,
        fileNamePrefix: String = "HealthFit-Relatorio"
    ) -> URL? {
        let safeName = fileNamePrefix
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)-\(UUID().uuidString.prefix(8)).txt")
        let content = "\(subject)\n\n\(body)"
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    func makeUIViewController(context: Context) -> MailComposeHostingController {
        let controller = MailComposeHostingController()
        controller.recipients = recipients
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        controller.bccRecipients = bccRecipients
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        controller.subject = subject
        controller.body = body
        controller.isHTML = isHTML
        controller.attachments = attachments
        controller.onFinish = onFinish
        return controller
    }

    func updateUIViewController(_ uiViewController: MailComposeHostingController, context: Context) {}
}

final class MailComposeHostingController: UIViewController, MFMailComposeViewControllerDelegate {
    var recipients: [String] = []
    var bccRecipients: [String] = []
    var subject = ""
    var body = ""
    var isHTML = false
    var attachments: [MailAttachment] = []
    var onFinish: ((MFMailComposeResult) -> Void)?

    private var didPresentMail = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentMailIfNeeded()
    }

    private func presentMailIfNeeded() {
        guard !didPresentMail else { return }
        didPresentMail = true

        guard MFMailComposeViewController.canSendMail() else {
            finish(with: .failed)
            return
        }

        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        composer.setToRecipients(recipients.isEmpty ? nil : recipients)
        if !bccRecipients.isEmpty {
            composer.setBccRecipients(bccRecipients)
        }
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: isHTML)
        for attachment in attachments {
            composer.addAttachmentData(
                attachment.data,
                mimeType: attachment.mimeType,
                fileName: attachment.fileName
            )
        }
        present(composer, animated: true)
    }

    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true) { [weak self] in
            self?.finish(with: result)
        }
    }

    private func finish(with result: MFMailComposeResult) {
        onFinish?(result)
        // O sheet SwiftUI é fechado ao limpar mailDraft no callback — evita dismiss duplo.
    }
}
