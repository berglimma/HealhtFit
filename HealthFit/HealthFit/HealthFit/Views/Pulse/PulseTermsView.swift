import SwiftUI

struct PulseTermsView: View {
    var onAccept: () -> Void
    var onCancel: () -> Void

    @State private var confirmedAge = false
    @State private var hasScrolledNearEnd = false

    private var paragraphs: [String] {
        PulseExperimental.termsBody
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            Text(PulseExperimental.featureName)
                                .font(.title2.bold())
                                .foregroundStyle(AppTheme.textPrimary)

                            Text(PulseExperimental.tagline)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)

                            Text("Documento completo abaixo. Role até o final para aceitar. Ao continuar, você declara ter 18 anos ou mais.")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)

                            Text("Versão \(PulseExperimental.termsVersion)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.85))

                            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                                Text(paragraph)
                                    .font(isSectionHeader(paragraph) ? .footnote.weight(.bold) : .footnote)
                                    .foregroundStyle(
                                        isSectionHeader(paragraph)
                                            ? AppTheme.textPrimary
                                            : AppTheme.textSecondary
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("terms-end")
                                .onAppear { hasScrolledNearEnd = true }
                        }
                        .padding(20)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if !hasScrolledNearEnd {
                            Button {
                                withAnimation {
                                    proxy.scrollTo("terms-end", anchor: .bottom)
                                }
                            } label: {
                                Text("Ir ao final do texto")
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .tint(AppTheme.accent)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(AppTheme.background.opacity(0.92))
                        }
                    }
                }

                VStack(spacing: 12) {
                    Toggle(isOn: $confirmedAge) {
                        Text("Declaro que tenho 18 anos ou mais e li integralmente estes Termos")
                            .font(.subheadline)
                    }
                    .tint(AppTheme.accent)

                    Button("Li e aceito") {
                        onAccept()
                    }
                    .buttonStyle(PrimaryButtonStyle(isEnabled: canAccept))
                    .disabled(!canAccept)

                    if !hasScrolledNearEnd {
                        Text("Role o documento até o final para liberar o aceite.")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("Agora não", role: .cancel, action: onCancel)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(20)
                .background(AppTheme.cardBackground)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Termos do Pulse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", action: onCancel)
                }
            }
        }
    }

    private var canAccept: Bool {
        confirmedAge && hasScrolledNearEnd
    }

    private func isSectionHeader(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("——") { return true }
        if trimmed.hasPrefix("TERMOS DE USO") { return true }
        if trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil,
           trimmed.count < 80,
           trimmed == trimmed.uppercased() || trimmed.contains("————") {
            return true
        }
        return false
    }
}
