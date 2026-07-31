import SwiftUI

/// Seletor de idioma reutilizável (login compacto + perfil em lista).
struct LanguagePickerControl: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    var style: Style = .compactMenu

    enum Style {
        /// Chip visível no login.
        case compactMenu
        /// Linha de Picker no perfil.
        case listRow
    }

    var body: some View {
        switch style {
        case .compactMenu:
            compactMenu
        case .listRow:
            listRow
        }
    }

    private var compactMenu: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    languageStore.language = language
                } label: {
                    HStack {
                        Text(language.menuLabel)
                        if languageStore.language == language {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(languageStore.language.flag)
                    .font(.body)
                Text(languageStore.language.nativeName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(AppTheme.accent.opacity(0.35), lineWidth: 1)
            )
            .accessibilityLabel(L10n.Settings.language)
            .accessibilityValue(languageStore.language.nativeName)
        }
    }

    private var listRow: some View {
        Picker(selection: $languageStore.language) {
            ForEach(AppLanguage.allCases) { language in
                Text(language.menuLabel).tag(language)
            }
        } label: {
            Label(L10n.Settings.language, systemImage: "globe")
        }
        .accessibilityLabel(L10n.Settings.language)
    }
}
