import Combine
import FirebaseAuth
import Foundation
import SwiftUI

/// Deep link do Pulse (toque em notificação FCM de pedido de follow).
@MainActor
final class PulseNavigationRouter: ObservableObject {
    static let shared = PulseNavigationRouter()

    struct PulseDestination: Identifiable, Equatable {
        var id: String { "pulse-\(openPeople ? "people" : "feed")" }
        var openPeople: Bool
    }

    @Published var presentedPulse: PulseDestination?
    /// Garante que a Home (dashboard) fica selecionada antes do cover.
    @Published private(set) var focusHomeTabTick: Int = 0

    private init() {}

    func openPulse(peopleTab: Bool = true) {
        focusHomeTabTick &+= 1
        presentedPulse = PulseDestination(openPeople: peopleTab)
        Task {
            let uid = Auth.auth().currentUser?.uid ?? ""
            guard !uid.isEmpty else { return }
            await PulseLocalStore.shared.refreshFromCloud(currentUserId: uid)
        }
    }

    func dismissPulse() {
        presentedPulse = nil
    }

    func handleNotificationUserInfo(_ userInfo: [AnyHashable: Any], category: String) {
        let kind = stringValue(userInfo["kind"])
        let type = stringValue(userInfo["type"])
        let isFollowRequest =
            kind == "pulseFollowRequest"
            || type == "pulseFollowRequest"
            || category == "PULSE_FOLLOW"
        guard isFollowRequest else { return }
        openPulse(peopleTab: true)
    }

    private func stringValue(_ raw: Any?) -> String {
        (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
