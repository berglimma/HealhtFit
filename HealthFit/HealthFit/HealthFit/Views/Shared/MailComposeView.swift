import SwiftUI
import MessageUI

/// Anexo opcional para `MFMailComposeViewController` (ex.: mapa da rota).
struct MailAttachment: Equatable {
    let data: Data
    let mimeType: String
    let fileName: String
}

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    /// Quando `true`, `body` é HTML (preferível com anexos de imagem).
    var isHTML: Bool = false
    var attachments: [MailAttachment] = []
    var onFinish: (MFMailComposeResult) -> Void = { _ in }

    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    static func mailtoURL(recipients: [String], subject: String, body: String) -> URL? {
        guard let recipient = recipients.first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !recipient.isEmpty,
              recipient.contains("@") else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }

    func makeUIViewController(context: Context) -> MailComposeHostingController {
        let controller = MailComposeHostingController()
        controller.recipients = recipients
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
        composer.setToRecipients(recipients)
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
