# Assinaturas HealthFit — checklist App Store Connect + app

Base de código pronta StoreKit 2. Product IDs:

## Mensal

| Plano | Product ID | Preço ref. BR |
|-------|------------|---------------|
| Básico | `healthfit.plan.basic.monthly` | R$ 9,90 |
| Fit | `healthfit.plan.fit.monthly` | R$ 12,90 |
| IA Plus | `healthfit.plan.ai.monthly` | R$ 19,90 |
| Completo | `healthfit.plan.complete.monthly` | R$ 24,90 |

## Anual (−20% vs 12× mensal)

| Plano | Product ID | Preço ref. BR | ≈ /mês |
|-------|------------|---------------|--------|
| Básico | `healthfit.plan.basic.yearly` | R$ 94,90 | R$ 7,91 |
| Fit | `healthfit.plan.fit.yearly` | R$ 123,90 | R$ 10,33 |
| IA Plus | `healthfit.plan.ai.yearly` | R$ 190,90 | R$ 15,91 |
| Completo | `healthfit.plan.complete.yearly` | R$ 239,90 | R$ 19,99 |

Grupo: **HealthFit Plans** (mensal e anual no **mesmo** grupo; mesmo `groupNumber`/nível por plano).

Arquivo local de teste: `HealthFit/Configuration/Products.storekit`

## App Store Connect

1. Conta com **Paid Applications Agreement** e banking/tax preenchidos.
2. App → **Subscriptions** → criar grupo **HealthFit Plans**.
3. Criar **8** assinaturas auto-renováveis (4 mensais + 4 anuais) com os **mesmos** Product IDs.
4. No nível do grupo, Básico mensal e Básico anual devem ficar no mesmo nível (e assim por diante).
5. Localização **pt-BR** (e en-US): nome, descrição — mencionar desconto anual.
6. Preço: escolher price tier mais próximo de cada valor em BRL.
7. Review screenshot + conta sandbox + notas: “Restaurar compras em Perfil → Meu plano”.
8. (Opcional) Intro offer 7 dias no Completo anual.

## Xcode / device

1. Scheme **HealthFit** → **Edit Scheme** → **Run** → **Options** → **StoreKit Configuration** → `Products.storekit`.
2. Rodar no Simulator ou device logado com **Sandbox Apple ID** (Settings → App Store → Sandbox).
3. Perfil → **Meu plano** → assinar / restaurar / gerenciar.
4. No paywall, alternar **Mensal / Anual** e validar o selo “Economize 20%”.
5. Em **DEBUG**, simular tier e alternar **feature gates** sem compra real.

## Código (já no projeto)

| Peça | Arquivo |
|------|---------|
| Planos + features + billing | `Models/SubscriptionModels.swift` |
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
- [x] Opção anual com preço claro e desconto  
- [ ] Não prometer “nutricionista humano” (copy já usa “orientação assistida”)
