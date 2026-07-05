# App Store Connect — HealthFit

Metadados em `metadata/pt-BR/` para copiar na ficha do app.

## Campos obrigatórios

| Campo | Arquivo / valor |
|-------|------------------|
| Nome | `name.txt` |
| Subtítulo | `subtitle.txt` |
| Descrição | `description.txt` |
| Palavras-chave | `keywords.txt` |
| URL de suporte | `support_url.txt` |
| URL de marketing (opcional) | `marketing_url.txt` |
| Política de privacidade | `privacy_url.txt` |

## Privacidade (questionário)

Marque conforme o app:

- **Dados de contato:** e-mail, nome (vinculados à conta)
- **Saúde e fitness:** treinos, sono, hidratação, HealthKit (com consentimento)
- **Fotos:** foto de perfil opcional
- **Identificadores:** ID de usuário Firebase
- **Sem rastreamento** entre apps de terceiros
- **Exclusão de conta:** disponível em Perfil → Excluir Conta

## Screenshots (capturar manualmente)

Use simulador ou dispositivo. Tamanhos mínimos para iPhone 6.7":

1. **Login** — tela inicial com logo e botões sociais
2. **Dashboard** — gráficos e resumo do dia
3. **Treino ativo** — exercício com GIF demonstrativo
4. **IAssistente** — chat com check-in ou dica de suplementação
5. **Plano alimentar** — cardápio semanal
6. **Perfil** — biotipo, objetivo e integrações

### Como capturar no simulador

```bash
# iPhone 16 Pro Max (6.7")
xcrun simctl boot "iPhone 16 Pro Max"
open -a Simulator
# No app: Cmd+S para salvar screenshot na área de trabalho
```

Organize em `AppStore/screenshots/pt-BR/iphone-6.7/` antes do upload.

## Criptografia

`ITSAppUsesNonExemptEncryption = false` já está no Info.plist (apenas HTTPS padrão).

## Checklist antes do envio

- [ ] Publicar `docs/legal/*.html` nas URLs de privacidade e termos
- [ ] Preencher App Privacy no App Store Connect
- [ ] Upload de screenshots 6.7" e 6.5"
- [ ] Ícone 1024×1024 (já no projeto)
- [ ] `GoogleService-Info.plist` no build de release
- [ ] Testar exclusão de conta em dispositivo real
