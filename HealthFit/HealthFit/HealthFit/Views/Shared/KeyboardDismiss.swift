import SwiftUI
import UIKit

enum KeyboardDismiss {
    static func hide() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
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

extension View {
    /// Adiciona botão OK acima do teclado numérico (numberPad/decimalPad não têm tecla Enter).
    func numericKeyboardDismiss() -> some View {
        modifier(NumericKeyboardDismissModifier())
    }
}
