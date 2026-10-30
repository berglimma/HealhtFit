import SwiftUI
import UIKit

/// Configuração visual para Stage Manager / Organizer visual (iPhone e iPad).
/// O ícone no canto superior esquerdo da miniatura é desenhado pelo sistema a partir do App Icon.
enum StageManagerSupport {
    static var defaultWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 520 : 390
    }

    static var defaultHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 780 : 780
    }

    /// Aplica fundo e tint das cores reais do HealthFit em todas as janelas ativas.
    @MainActor
    static func applyWindowChrome() {
        let bg = UIColor(named: "Background") ?? UIColor(red: 0.06, green: 0.08, blue: 0.09, alpha: 1)
        let accent = UIColor(named: "AccentGreen") ?? UIColor(red: 0.20, green: 0.85, blue: 0.45, alpha: 1)

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.backgroundColor = bg
                window.tintColor = accent
                window.overrideUserInterfaceStyle = .dark
            }
        }
    }

    /// iPad/Stage Manager: a cena pode voltar sem janela key visível (tela só com o fundo escuro).
    @MainActor
    static func repairForegroundWindow() {
        applyWindowChrome()
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScenes = scenes.filter { $0.activationState == .foregroundActive }
        let targets = activeScenes.isEmpty ? scenes : activeScenes

        for scene in targets {
            let window = scene.windows.first(where: { $0.rootViewController != nil && !$0.isHidden })
                ?? scene.windows.first(where: \.isKeyWindow)
                ?? scene.windows.first(where: { $0.rootViewController != nil })
                ?? scene.windows.first
            guard let window else { continue }
            window.isHidden = false
            window.makeKeyAndVisible()
        }
    }
}
