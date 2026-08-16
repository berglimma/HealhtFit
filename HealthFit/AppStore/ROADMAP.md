# Roadmap HealthFit

Visão: app completo de treino + nutrição + esportes avançados, com planos que desbloqueiam valor progressivamente.

---

## Agora — v1.0 (App Store launch)

**Objetivo:** aprovação e publicação mundial.

| Item | Status |
|------|--------|
| iOS + watchOS app | Pronto |
| Treinos / cardio / meditação | Pronto |
| Luta (hub + cronômetro + capas) | Pronto |
| Escalada (mapa, clima, motion, gear, IAssistente) | Pronto |
| Surf / Kite / Remo | Pronto |
| Nutrição + lista de compras | Pronto |
| IAssistente | Pronto |
| StoreKit 2 + paywall + Meu plano | Pronto |
| Exclusão de conta | Pronto |
| Privacy Manifest | Pronto |
| Metadados 4 idiomas | Pronto |
| Páginas legais públicas | Pronto no repo (`Docs/privacidade|termos|suporte` + template Pages em Docs/github); publicar/push para atualizar o GitHub Pages ao vivo |
| Screenshots App Store | Pendente (manual) |
| Product IDs na Connect | Pendente (conta Apple) |
| Feature gates ligados na UI | Soft launch: gates off; aviso Release removido |

### Planos (liberação progressiva)

| Plano | Libera |
|-------|--------|
| Gratuito | Dashboard, check-ins, treinos limitados |
| Básico | Treinos guiados + cardio clássico + Apple Watch |
| Fit | Modalidades avançadas (Surf/Kite/Remo/Escalada/Luta), treinos custom, cardápio + lista, IA 5 msgs/dia |
| IA Plus | IA ilimitada, análise de refeição por foto, diários/análises por modalidade, relatório mensal, evolução corporal/PDF |
| Completo | Tudo + prioridade |

---

## v1.1 — Monetização fechada (2–4 semanas pós-lançamento)

- Ligar `featureGatesEnabled` e aplicar `.requiresSubscription` nas telas (Nutrição, IA, Relatório, Luta/Escalada avançada, diários)
- Conta sandbox + Intro Offer 7 dias no Completo
- Soft paywall no onboarding (após 1º treino)
- Analytics de funil (Firebase): free → trial → paid

---

## v1.2 — Esportes & retenção

- Diário de luta (rounds, sparring, técnica)
- Melhorias Escalada (sync Watch auto-detect mais estável)
- Compartilhar resumo semanal (Stories / imagem)
- Widgets de streak e próximo treino

---

## v1.3 — Social leve & coach

- Convite personal trainer / nutricionista (já há campos de perfil) com relatório por e-mail
- Templates de fichas da comunidade (sem feed público)
- Idioma completo nos catálogos longos (hoje UI localizada; conteúdo longo ainda PT-first)

---

## v2.0 — Escala

- Plano anual Completo
- Backend de entitlements espelhado no Firestore (fase 4 de `subscriptions.md`)
- Programas de maratona/ultramaratona premium
- Android (avaliar) ou Web coach dashboard

---

## Fora de escopo curto prazo

- Marketplace de equipamentos
- Live streaming de aulas
- Diagnóstico médico / prescrição

---

## Métricas de sucesso (90 dias)

1. Aprovação App Store sem rejeição grave de privacidade/assinatura  
2. ≥ 30% dos usuários ativos semanais completam 1 treino  
3. Conversão free → pago ≥ 2–4%  
4. Crash-free sessions ≥ 99.5%
