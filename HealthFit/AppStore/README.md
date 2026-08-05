# App Store Connect — HealthFit

Metadados por idioma em `metadata/`:

| Locale | Pasta | Idioma |
|--------|-------|--------|
| Português (Brasil) | `pt-BR/` | padrão |
| English (U.S.) | `en-US/` | inglês |
| Español (España) | `es-ES/` | espanhol |
| Français (France) | `fr-FR/` | francês |

Copie cada pasta para a localização correspondente na ficha do app no App Store Connect.

## Campos por pasta

| Campo | Arquivo |
|-------|---------|
| Nome | `name.txt` |
| Subtítulo | `subtitle.txt` |
| Descrição | `description.txt` |
| Palavras-chave | `keywords.txt` |
| URL de suporte | `support_url.txt` |
| URL de marketing | `marketing_url.txt` |
| Política de privacidade | `privacy_url.txt` |
| Notas App Privacy | `privacy_notes.txt` |

## Localização no app (código)

- Catálogo: `HealthFit/Resources/Localizable.xcstrings` (`pt-BR`, `en`, `es`, `fr`)
- Permissões Info.plist: `pt-BR.lproj/`, `en.lproj/`, `es.lproj/`, `fr.lproj/`
- Helper: `Utilities/L10n.swift`

Idioma do dispositivo do usuário define a UI. Conteúdo longo (IAssistente, catálogos de treino/cardápio) ainda está majoritariamente em português e pode ser expandido no catálogo aos poucos.

## Screenshots

Organize em:

```
AppStore/screenshots/pt-BR/iphone-6.7/
AppStore/screenshots/en-US/iphone-6.7/
AppStore/screenshots/es-ES/iphone-6.7/
AppStore/screenshots/fr-FR/iphone-6.7/
```

## Checklist antes do envio mundial

- [ ] Preencher as 4 localizações no App Store Connect
- [ ] Upload de screenshots por idioma (ou reutilizar as mesmas se a UI estiver localizada)
- [ ] App Privacy + exclusão de conta
- [ ] Testar idioma do sistema em inglês/espanhol/francês no simulador
- [ ] `GoogleService-Info.plist` no build de release
- [ ] Assinaturas: ver [subscriptions.md](./subscriptions.md)
