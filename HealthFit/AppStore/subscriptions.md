# Assinaturas HealthFit — checklist App Store Connect + app

Base de código pronta StoreKit 2. Product IDs:

| Plano | Product ID | Preço ref. BR |
|-------|------------|---------------|
| Básico | `healthfit.plan.basic.monthly` | R$ 9,90 |
| Fit | `healthfit.plan.fit.monthly` | R$ 12,90 |
| IA Plus | `healthfit.plan.ai.monthly` | R$ 19,90 |
| Completo | `healthfit.plan.complete.monthly` | R$ 24,90 |

Grupo: **HealthFit Plans**

Arquivo local de teste: `HealthFit/Configuration/Products.storekit`

## App Store Connect

1. Conta com **Paid Applications Agreement** e banking/tax preenchidos.
2. App → **Subscriptions** → criar grupo **HealthFit Plans**.
3. Criar 4 assinaturas auto-renováveis mensais com os **mesmos** Product IDs da tabela.
4. Localização **pt-BR** (e en-US se quiser): nome, descrição.
5. Preço: escolher price tier mais próximo de cada valor em BRL.
6. Review screenshot + conta sandbox + notas: “Restaurar compras em Perfil → Meu plano”.
7. (Fase 2) Intro offer 7 dias no Completo e/ou planor anuais `…yearly`.

## Xcode / device

1. Scheme **HealthFit** → **Edit Scheme** → **Run** → **Options** → **StoreKit Configuration** → `Products.storekit`.
2. Rodar no Simulator ou device logado com **Sandbox Apple ID** (Settings → App Store → Sandbox).
3. Perfil → **Meu plano** → assinar / restaurar / gerenciar.
4. Em **DEBUG**, simular tier e alternar **feature gates** sem compra real.

## Código (já no projeto)

| Peça | Arquivo |
|------|---------|
| Planos + features | `Models/SubscriptionModels.swift` |
| StoreKit 2 | `Services/SubscriptionService.swift` |
| Paywall + Meu plano | `Views/Subscription/SubscriptionViews.swift` |
| Gates on/off | `SubscriptionConfiguration.featureGatesEnabled` |
| Features novas | `.advancedModalities` (Fit), `.advancedSportAnalytics` (IA+) |
| UI lock | `.requiresSubscription(.feature)` em `SubscriptionViews.swift` |

### Bloqueios na v1.0 (lançamento)

Para o **primeiro review**, mantenha a app usável sem assinatura (evita rejeição por “feature quebrada”).  
Ative os locks na **v1.1** (ver `ROADMAP.md`) após aprovação:

```swift
// Em uma tela:
.requiresSubscription(.mealPlan)
// ou
if subscriptions.canAccess(.aiChatUnlimited) { ... }
```

Locks recomendados v1.1: `.advancedModalities`, `.mealPlan`, `.aiChatUnlimited`, `.monthlyReport`, `.advancedSportAnalytics`.

## Firebase (fase 4 — ainda não implementado)

Após compra estável: gravar `plan` + `expiresAt` no user Firestore; sempre revalidar com `Transaction.currentEntitlements` no cold start.

## Regras Apple (checklist review)

- [x] Restaurar compras na UI  
- [x] Links de Termos e Privacidade no paywall  
- [x] Free mínimo (gates ainda off = tudo livre)  
- [x] Gerenciar assinatura (`manageSubscriptionsSheet`)  
- [ ] Não prometer “nutricionista humano” (copy já usa “orientação assistida”)
