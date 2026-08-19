import Combine
import Foundation
import SwiftUI

/// Navegação profunda para Dupla/equipe (ex.: toque em notificação de chat).
@MainActor
final class DuoNavigationRouter: ObservableObject {
    static let shared = DuoNavigationRouter()

    struct ChatDestination: Identifiable, Equatable {
        let teamId: String
        let teamName: String
        var id: String { teamId }
    }

    /// Quando definido, a UI principal deve abrir o chat dessa equipe.
    @Published var presentedChat: ChatDestination?
    /// Alterna para a aba Treinos antes de apresentar o chat.
    @Published private(set) var focusWorkoutsTabTick: Int = 0

    private init() {}

    func openChat(teamId: String, teamName: String) {
        let trimmedId = teamId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return }
        let name = teamName.trimmingCharacters(in: .whitespacesAndNewlines)
        focusWorkoutsTabTick &+= 1
        presentedChat = ChatDestination(
            teamId: trimmedId,
            teamName: name.isEmpty ? "Equipe" : name
        )
        Task {
            await DuoTeamService.shared.loadMessages(teamId: trimmedId)
            DuoTeamService.shared.restartListening(teamId: trimmedId)
        }
    }

    func dismissChat() {
        presentedChat = nil
    }

    /// Interpreta toque em notificação local ou FCM de chat (app aberto, em background ou fechado).
    func handleNotificationUserInfo(_ userInfo: [AnyHashable: Any], category: String) {
        let kind = stringValue(userInfo["kind"])
        let type = stringValue(userInfo["type"])
        let teamId = stringValue(userInfo["teamId"])
        let teamName = stringValue(userInfo["teamName"])
        guard !teamId.isEmpty else { return }

        let isDuoChat =
            kind == "duoChatMessage"
            || kind == "duoChatSchedule"
            || type.hasPrefix("duoChat")
            || (category == "DUO_TEAM" && (kind == "duoChatMessage" || kind == "duoChatSchedule"))
        guard isDuoChat else { return }
        openChat(teamId: teamId, teamName: teamName.isEmpty ? "Equipe" : teamName)
    }

    private func stringValue(_ raw: Any?) -> String {
        (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
