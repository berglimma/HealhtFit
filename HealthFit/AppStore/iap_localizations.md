# IAP — localizações pt-BR + preços + notas de review

## Status (auditoria 24/08/2026)

| Produto | Preço BR | pt-BR | Screenshot review | Para revisão |
|---------|----------|-------|-------------------|--------------|
| Fit Anual | OK | OK | falta | falta |
| Completo Mensal | OK | falta | falta | falta |
| Completo Anual | OK | falta | falta | falta |
| IA Plus Mensal | OK | falta | falta | falta |
| IA Plus Anual | OK | falta | falta | falta |
| Fit Mensal | OK | falta | falta | falta |
| Básico Mensal | OK (R$ 9,90) | falta* | falta | falta |
| Básico Anual | OK | falta* | falta | falta |

\* Automação preencheu o modal, mas o Connect retornou **"Ocorreu um erro. Tente novamente mais tarde."** ao salvar — concluir manualmente no browser.

**Screenshot (todos):** `/Users/berglimma/Documents/HealhtFit/HealthFit/AppStore/screenshots/pt-BR/iphone-6.7/02_treinos.png`

**Ordem por IAP:** (1) pt-BR → (2) upload screenshot → (3) **Adicionar para revisão**  
**Depois dos 8:** grupo [22332052](https://appstoreconnect.apple.com/apps/6798621208/distribution/subscription-groups/22332052) → versão 1.0

---

Copie cada bloco em **App Store Connect → Assinaturas → [produto]**.

Links diretos (grupo `22332052`):

| Produto | Connect ID | URL |
|---------|------------|-----|
| Completo Anual | 6804728728 | `/subscriptions/6804728728` |
| Completo Mensal | 6804743936 | `/subscriptions/6804743936` |
| IA Plus Mensal | 6804745096 | `/subscriptions/6804745096` |
| IA Plus Anual | 6804745261 | `/subscriptions/6804745261` |
| Fit Mensal | 6804745416 | `/subscriptions/6804745416` |
| Fit Anual | 6804751627 | `/subscriptions/6804751627` |
| Básico Mensal | 6804752388 | `/subscriptions/6804752388` |
| Básico Anual | 6804752725 | `/subscriptions/6804752725` |

Base: `https://appstoreconnect.apple.com/apps/6798621208/distribution/subscriptions/{ID}`

Screenshot de review (todas): use `HealthFit/AppStore/screenshots/pt-BR/iphone-6.7/02_treinos.png` ou qualquer tela do paywall (Perfil → Meu plano).

---

## 1. Básico Mensal — `healthfit.plan.basic.monthly`

| Campo | Valor |
|-------|-------|
| Preço BR | R$ 9,90 |
| Nome pt-BR | Básico Mensal |
| Descrição pt-BR | Treine todo dia no iPhone e Apple Watch. Plano essencial com treinos completos e sincronização Watch. |
| Notas review | Assinatura Básico Mensal. Testar: Perfil → Meu plano → assinar / Restaurar compras. |

---

## 2. Básico Anual — `healthfit.plan.basic.yearly`

| Campo | Valor |
|-------|-------|
| Preço BR | R$ 94,90 |
| Nome pt-BR | Básico Anual |
| Descrição pt-BR | Treine todo dia no iPhone e Apple Watch. Assinatura anual com cerca de 20% de economia vs mensal. |
| Notas review | Assinatura Básico Anual. Testar: Perfil → Meu plano → alternar Anual → assinar / Restaurar compras. |

---

## 3. Fit Mensal — `healthfit.plan.fit.monthly`

| Campo | Valor |
|-------|-------|
| Preço BR | R$ 12,90 |
| Nome pt-BR | Fit Mensal |
| Descrição pt-BR | Treino + cardápio + foco em metas calóricas. Inclui tudo do Básico e modalidades avançadas. |
| Notas review | Assinatura Fit Mensal. Testar: Perfil → Meu plano → assinar / Restaurar compras. |

---

## 4. Fit Anual — `healthfit.plan.fit.yearly`

| Campo | Valor |
|-------|-------|
| Preço BR | R$ 123,90 |
| Nome pt-BR | Fit Anual |
| Descrição pt-BR | Treino + cardápio + metas calóricas. Assinatura anual com cerca de 20% de economia vs mensal. |
| Notas review | Assinatura Fit Anual. Testar: Perfil → Meu plano → alternar Anual → assinar / Restaurar compras. |

---

## 5. IA Plus Mensal — `healthfit.plan.ai.monthly`

| Campo | Valor |
|-------|-------|
| Preço BR | R$ 19,90 |
| Nome pt-BR | IA Plus Mensal |
| Descrição pt-BR | IA no dia a dia + análises de evolução. Inclui tudo do Fit e assistente ilimitado. |
| Notas review | Assinatura IA Plus Mensal. Testar: Perfil → Meu plano → assinar / Restaurar compras. |

---

## 6. IA Plus Anual — `healthfit.plan.ai.yearly`

| Campo | Valor |
|-------|-------|
| Preço BR | R$ 190,90 |
| Nome pt-BR | IA Plus Anual |
| Descrição pt-BR | IA no dia a dia + análises de evolução. Assinatura anual com cerca de 20% de economia vs mensal. |
| Notas review | Assinatura IA Plus Anual. Testar: Perfil → Meu plano → alternar Anual → assinar / Restaurar compras. |

---

## 7. Completo Mensal — `healthfit.plan.complete.monthly`

| Campo | Valor |
|-------|-------|
| Preço BR | R$ 24,90 |
| Nome pt-BR | Completo Mensal |
| Descrição pt-BR | Plano completo HealthFit, sem limites. Treino, nutrição, IA e Watch em um só plano. |
| Notas review | Assinatura Completo Mensal. Testar: Perfil → Meu plano → assinar / Restaurar compras. |

---

## 8. Completo Anual — `healthfit.plan.complete.yearly`

| Campo | Valor |
|-------|-------|
| Preço BR | R$ 239,90 |
| Nome pt-BR | Completo Anual |
| Descrição pt-BR | Plano completo HealthFit, sem limites. Assinatura anual com cerca de 20% de economia vs mensal. |
| Notas review | Assinatura Completo Anual. Testar: Perfil → Meu plano → alternar Anual → assinar / Restaurar compras. |

---

## Checklist por IAP

Para cada um dos 8 produtos:

1. **Adicionar preços** → Brasil → valor acima (tier mais próximo)
2. **Adicionar idioma** → Português (Brasil) → nome + descrição
3. **Captura de tela** (obrigatório) → upload manual
4. **Salvar** → **Adicionar para revisão** (cada IAP)
5. **Configurar disponibilidade** → todos os países (ou igual ao app)

Depois de completar os 8: na **versão 1.0** → **Adicionar para revisão**.
