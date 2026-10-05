# HealthFit Android — roadmap (paridade fiel)

Stack: **Kotlin + Jetpack Compose** (phone) · **Wear OS** (Galaxy Watch) · **Firebase compartilhado** com iOS.  
Não usar Flutter/KMP como UI principal.

## Princípios

- Layout/cards fiéis via `:designsystem` (cores iOS `AppTheme`)
- Backend compartilhado **sem** publicar regras/Functions que quebrem o iOS
- Entrega por fases; cada fase só avança com checklist de paridade

## Fase 1 — Auth + Treinos + Health Connect + Billing _(scaffold atual)_

- [x] Multi-módulo Gradle (`app`, `wear`, `core`, `designsystem`)
- [x] Tema/cards alinhados ao iOS
- [x] Shell 5 abas (Início · Treinos · Nutrição · Dúvidas · Perfil)
- [x] Auth e-mail/senha (Firebase Auth — mesmo projeto)
- [x] Catálogo de treinos local
- [x] Health Connect gateway (permissions)
- [x] Play Billing gateway (SKUs placeholder)
- [x] Wear shell
- [ ] `google-services.json` real (Console, sem alterar rules)
- [ ] Login Google / fluxo completo de perfil
- [ ] Sessão de treino ativa + sync local

## Fase 2 — Nutrição + Coach

- Cardápio, lista, suplementos
- Coach links, agenda, chat (Firestore paths iOS)
- Validar schema antes de writes

## Fase 3 — IAssistente

- Chat + motores de engajamento (port gradual da lógica)

## Fase 4 — Pulse

- Feed/stories com mídia; Storage rules já aceitam video/image (iOS). Não alterar rules sem review.

## Fase 5 — Wear treino

- Health Services `ExerciseClient`
- Data Layer phone ↔ watch
- HR / kcal ao vivo

## Fase 6 — Surf / Kite / Spot Buddy

- GPS, saltos, presença Firestore (paths existentes)

## Fora de escopo / redesign

- Ícones alternativos iOS, MapKit Flyover, Live Activities, Sign in with Apple como IdP primário
