# Checklist — publicar HealthFit na App Store

Versão alvo: **1.0.4 (Build 12)** · Bundle `luan.com.healthfit.app`

## URLs legais (já no app e metadados)

- Site: https://healthfit-30d87.web.app/
- Privacidade (copiar no Connect): https://healthfit-30d87.web.app/privacidade/
- Termos: https://healthfit-30d87.web.app/termos/
- Suporte: https://healthfit-30d87.web.app/suporte/

## Pronto no repositório

- [x] Versão Xcode **1.0.4 (12)**
- [x] `whatsnew.txt` (pt-BR / en-US / es-ES / fr-FR) com HealthFit Pulse
- [x] `review_notes.txt` atualizado (Pulse 18+, trial, conta demo)
- [ ] Commit + Archive + upload build **12** para App Store Connect

## Firebase (sem ligar Pulse na loja ainda)

- [ ] `firebase deploy --only firestore:rules,storage,hosting`
- [ ] Confirmar no Console: `appConfig/ios.pulseEnabled = false`
- [ ] Confirmar: `appConfig/ios.pulseCloudSyncEnabled = false`
- [ ] **Só na Review:** ligar `pulseEnabled=true` (e sync se necessário); após aprovação manter ou fazer rollout

## Você no App Store Connect

1. Abrir https://appstoreconnect.apple.com/apps/6798621208
2. Versão **1.0.4** → colar What’s New de `metadata/*/whatsnew.txt`
3. Colar Review Notes de `review_notes.txt`
4. Age Rating: app **16+**; UGC / Pulse **18+**
5. Privacy Nutrition Labels: fotos / conteúdo gerado pelo usuário
6. Questionário de User-Generated Content
7. Quando o build **12** processar → selecionar na versão
8. Antes de Submit: garantir `pulseEnabled=true` para a Apple ver o Pulse
9. **Add for Review** → **Submit for Review**

## Enviar

- [ ] Commit das alterações locais
- [ ] Archive 1.0.4 (12) Release
- [ ] Upload build 12
- [ ] Attach build 12
- [ ] Connect age/privacy/UGC
- [ ] Flag Pulse ON para review
- [ ] Submit for Review
