# Checklist — publicar HealthFit na App Store

Versão alvo: **1.0.14 (Build 27)** · Bundle `luan.com.healthfit.app`

## URLs legais

- Site: https://healthfit-30d87.web.app/
- Privacidade: https://healthfit-30d87.web.app/privacidade/
- Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- Termos HealthFit: https://healthfit-30d87.web.app/termos/
- Suporte: https://healthfit-30d87.web.app/suporte/

## Status Connect (2026-09-28)

- **1.0.13 (26)** — **Pronto para distribuição** (aprovado; lançamento automático).
- **1.0.14 (27)** — preparada no Xcode + metadados; criar versão na Connect e enviar build.

## Build 27 (código pronto)

- [x] Versão Xcode **1.0.14 (27)**
- [x] Removida API privada de ícone (`setAlternateIconName` público)
- [x] Watch `NSMotionUsageDescription`
- [x] iPhone `healthkit.background-delivery`
- [x] Now Playing no Watch + cronômetro wall-clock + Flyover→Pulse + resume mais rápido
- [x] `whatsnew.txt` (pt-BR/en-US/es-ES/fr-FR) + `review_notes.txt` atualizados
- [ ] Archive + upload build **27** (Xcode Organizer → Distribute App)
- [ ] Criar versão **1.0.14** na Connect → anexar build 27 → preencher “O que há de novo” → Enviar para revisão

## App Store Connect

1. https://appstoreconnect.apple.com/apps/6798621208
2. Distribuição → Adicionar app para iOS → versão `1.0.14`
3. Compilação → selecionar **27**
4. Colar What’s New de `AppStore/metadata/*/whatsnew.txt`
5. Notas de revisão: `AppStore/review_notes.txt`
6. Conta demo já preenchida: `healthfit.appreview@gmail.com` / `HealthFitReview2026!`
7. Enviar para revisão

## Bloqueio local desta máquina

- Sem certificado **Apple Distribution** no keychain (só Development).
- Archive App Store precisa ser feito no Xcode logado na conta Apple Developer (Signing Automatic cria o cert na 1ª distribuição).
