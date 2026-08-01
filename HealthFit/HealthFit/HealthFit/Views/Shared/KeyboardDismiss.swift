import SwiftUI
import UIKit

enum KeyboardDismiss {
    static func hide() {
        // endEditing nas janelas costuma ser mais confiável que só resignFirstResponder.
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                window.endEditing(true)
            }
        }
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    /// Publisher for system keyboard hide — use to clear FocusState / custom insets.
    static var willHidePublisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
    }
}

private struct NumericKeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") {
                        KeyboardDismiss.hide()
                    }
                    .fontWeight(.semibold)
                }
            }
    }
}

private struct TapToDismissKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture().onEnded {
                    KeyboardDismiss.hide()
                }
            )
    }
}

extension View {
    /// Adiciona botão OK acima do teclado numérico (numberPad/decimalPad não têm tecla Enter).
    func numericKeyboardDismiss() -> some View {
        modifier(NumericKeyboardDismissModifier())
    }

    /// Fecha o teclado ao tocar fora do campo (não bloqueia botões).
    func dismissKeyboardOnTap() -> some View {
        modifier(TapToDismissKeyboardModifier())
    }
}
