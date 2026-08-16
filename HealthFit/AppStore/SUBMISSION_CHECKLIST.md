# Checklist — publicar HealthFit na App Store

Versão alvo: **1.0.0 (Build 1)** · Bundle `luan.com.healthfit.app`

## Corrigido no repositório (código / docs)

- [x] Metadados name/subtitle/keywords dentro dos limites (4 idiomas)
- [x] `aps-environment` = **production** no entitlement Release
- [x] Aviso de “bloqueios desativados” só em DEBUG
- [x] AGE_RATING atualizado (chat Dupla = UGC privado + denúncia)
- [x] Review notes com IDs yearly + fluxo Dupla/denúncia
- [x] Páginas legais espelhadas em `Docs/privacidade|termos|suporte` (16+)
- [x] Workflow GitHub Pages (`Docs/github/pages.workflow.yml`)
- [x] Denunciar mensagem/conversa no chat Dupla

## Ainda depende de você (Connect / Apple / captura)

> Passo a passo detalhado: [`CONNECT_FILL_GUIDE.md`](./CONNECT_FILL_GUIDE.md)

> Privacidade 16+ estável: `https://cdn.jsdelivr.net/gh/berglimma/HealhtFit@main/Docs/privacidade/index.html`

- [ ] **Push do workflow / Pages ligado** e validar no Safari:
    - https://berglimma.github.io/HealhtFit/privacidade/ → deve dizer **16 anos**
    - https://berglimma.github.io/HealhtFit/termos/
    - https://berglimma.github.io/HealhtFit/suporte/
- [ ] **Paid Applications Agreement** + banking/tax no App Store Connect
- [ ] **Assinaturas criadas** (8 Product IDs de `subscriptions.md`)
- [ ] **Sign In with Apple** + **HealthKit** no App ID (Developer Portal)
- [x] **Screenshots** iPhone 6.7" gerados em `AppStore/screenshots/` (substituir por capturas reais se possível)
- [ ] Preencher **App Privacy** (`APP_PRIVACY.md`) e **Age Rating** (`AGE_RATING.md`)
- [ ] Archive com `GoogleService-Info.plist` real → TestFlight → Submit
- [ ] Colar `review_notes.txt` em App Review Information

## Metadados (copiar de `metadata/`)

Para cada idioma (pt-BR, en-US, es-ES, fr-FR):

| Campo Connect | Arquivo |
|---------------|---------|
| Name | `name.txt` (**HealthFit**) |
| Subtitle | `subtitle.txt` |
| Description | `description.txt` |
| Keywords | `keywords.txt` |
| Promotional Text | `promotional_text.txt` |
| What's New | `whatsnew.txt` |
| Support URL | `support_url.txt` |
| Marketing URL | `marketing_url.txt` |
| Privacy Policy URL | `privacy_url.txt` |

## Build

```bash
# Xcode: Product → Archive → Distribute App → App Store Connect
```

- [ ] Upload do archive
- [ ] Selecionar build 1.0.0 (1)
- [ ] Contato: berg.limma@gmail.com + telefone
- [ ] Demo: criar conta no app (idade 16+)

## Testes pré-envio (device físico)

- [ ] Login Apple / e-mail
- [ ] Corrida / Luta / Escalada
- [ ] Nutrição + lista + Análise (foto)
- [ ] IAssistente
- [ ] Dupla: chat + denunciar mensagem + sair do grupo
- [ ] Meu plano → Restore
- [ ] Excluir conta (conta de teste)
- [ ] Links Privacidade/Termos abrem (após Pages atualizado)

## Enviar

- [ ] Add for Review → Submit
