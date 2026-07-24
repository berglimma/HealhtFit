import SwiftUI

struct PasswordRequirementsView: View {
    let password: String
    var confirmPassword: String = ""
    var showsMatchRequirement = true

    private var evaluations: [(requirement: PasswordPolicy.Requirement, isSatisfied: Bool)] {
        PasswordPolicy.evaluate(password)
    }

    private var passwordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A senha deve conter:")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(evaluations, id: \.requirement.id) { item in
                requirementRow(
                    label: item.requirement.label,
                    isSatisfied: item.isSatisfied
                )
            }

            if showsMatchRequirement {
                requirementRow(
                    label: "As senhas coincidem",
                    isSatisfied: passwordsMatch
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: password)
        .animation(.easeInOut(duration: 0.2), value: confirmPassword)
    }

    private func requirementRow(label: String, isSatisfied: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isSatisfied ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(isSatisfied ? Color.green : Color.red)
                .accessibilityHidden(true)

            Text(label)
                .font(.caption)
                .foregroundStyle(isSatisfied ? Color.green : Color.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(isSatisfied ? "Atendido" : "Pendente")")
    }
}
