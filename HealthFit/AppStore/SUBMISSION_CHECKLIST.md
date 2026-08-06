# Checklist — publicar HealthFit na App Store

Versão alvo: **1.0.0 (Build 1)** · Bundle `luan.com.healthfit.app`

## Bloqueadores críticos (fazer primeiro)

- [ ] **GitHub Pages ligado**  
  GitHub → repo `HealhtFit` → Settings → Pages → Source: Deploy from branch `main` → Folder `/docs` → Save  
  Validar no Safari:
  - https://berglimma.github.io/HealhtFit/privacidade/
  - https://berglimma.github.io/HealhtFit/termos/
  - https://berglimma.github.io/HealhtFit/suporte/
- [ ] **Paid Applications Agreement** + banking/tax no App Store Connect (Conta → Agreements)
- [ ] **Assinaturas criadas** no Connect com os Product IDs de `subscriptions.md`
- [ ] **Sign In with Apple** capability ativa no App ID `luan.com.healthfit.app` (e Watch se necessário)
- [ ] **HealthKit** capability nos targets iOS + Watch
- [ ] Screenshots iPhone 6.7" (ver `SCREENSHOTS_GUIDE.md`)

## Metadados (copiar de `metadata/`)

Para cada idioma (pt-BR, en-US, es-ES, fr-FR):

| Campo Connect | Arquivo |
|---------------|---------|
| Name | `name.txt` |
| Subtitle | `subtitle.txt` |
| Description | `description.txt` |
| Keywords | `keywords.txt` |
| Promotional Text | `promotional_text.txt` |
| What's New | `whatsnew.txt` |
| Support URL | `support_url.txt` (**https**, não mailto) |
| Marketing URL | `marketing_url.txt` |
| Privacy Policy URL | `privacy_url.txt` |

## App Privacy + Age Rating

- [ ] Preencher App Privacy com `APP_PRIVACY.md`
- [ ] Preencher Age Rating com `AGE_RATING.md`
- [ ] Export Compliance: **No** encryption exempt / `ITSAppUsesNonExemptEncryption = false` (já no Info.plist)
- [ ] Content Rights: You have rights to all content
- [ ] Advertising Identifier: **No** (se não usa IDFA)

## Build

```bash
# Archive no Xcode (recomendado):
# Product → Archive → Distribute App → App Store Connect → Upload

# Ou CLI (com certificados válidos):
xcodebuild -scheme HealthFit -destination 'generic/platform=iOS' \
  -archivePath build/HealthFit.xcarchive archive
```

- [ ] Upload do `.ipa` / archive via Organizer ou Transporter
- [ ] Selecionar o build na versão 1.0.0
- [ ] Colar `review_notes.txt` em App Review Information
- [ ] Contato de revisão: berg.limma@gmail.com + telefone
- [ ] Demo: criar conta no app OU Sign in with Apple (sem conta prévia é aceitável se o fluxo for aberto)

## Testes pré-envio (device físico)

- [ ] Login Apple / e-mail
- [ ] Iniciar Corrida sem freeze
- [ ] Iniciar Luta (cronômetro)
- [ ] Escalada setup abre
- [ ] Nutrição + lista de compras
- [ ] IAssistente responde
- [ ] Perfil → Meu plano → Restore
- [ ] Perfil → Excluir conta (fluxo completo em conta de teste)
- [ ] Watch: sessão espelhada (se possível)
- [ ] Links Privacidade/Termos abrem no Safari

## Enviar

- [ ] Add for Review → Submit
- [ ] Monitorar Resolution Center (resposta em ~24–48h típico)

## Se a Apple rejeitar (cenários comuns)

| Motivo | Correção |
|--------|----------|
| Privacy URL offline | Conferir GitHub Pages / trocar URL |
| Subscriptions incomplete | Completar metadata + screenshot do paywall + restore |
| Login required sem demo | Criar conta reviewer nas Review Notes |
| Health claims | Manter disclaimer; evitar “cura/diagnóstico” |
| Missing delete account | Já existe — mostrar caminho nas notes |
