import SwiftUI
import MessageUI

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
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
        controller.onFinish = onFinish
        return controller
    }

    func updateUIViewController(_ uiViewController: MailComposeHostingController, context: Context) {}
}

final class MailComposeHostingController: UIViewController, MFMailComposeViewControllerDelegate {
    var recipients: [String] = []
    var subject = ""
    var body = ""
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
        composer.setMessageBody(body, isHTML: false)
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
        dismiss(animated: true)
    }
}
