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

    /// Interpreta toque em notificação `DUO_TEAM` (mensagem / proposta de treino).
    func handleNotificationUserInfo(_ userInfo: [AnyHashable: Any], category: String) {
        guard category == "DUO_TEAM" else { return }
        let kind = (userInfo["kind"] as? String) ?? ""
        let teamId = (userInfo["teamId"] as? String) ?? ""
        let teamName = (userInfo["teamName"] as? String) ?? "Equipe"
        guard !teamId.isEmpty else { return }

        // Só mensagens / propostas de treino abrem o chat.
        guard kind == "duoChatMessage" || kind == "duoChatSchedule" else { return }
        openChat(teamId: teamId, teamName: teamName)
    }
}
