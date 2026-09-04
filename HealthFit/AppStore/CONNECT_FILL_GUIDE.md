# Preencher App Store Connect + Developer Portal (passo a passo)

Use este guia com a conta Apple Developer do HealthFit.
Bundle: `luan.com.healthfit.app` · Versão `1.0.2` / Build `6`

URLs legais (16+, renderizam HTML corretamente):

- Site / marketing: https://healthfit-30d87.web.app/
- Privacidade: https://healthfit-30d87.web.app/privacidade/
- Termos: https://healthfit-30d87.web.app/termos/
- Suporte: https://healthfit-30d87.web.app/suporte/

> Não use jsDelivr para HTML — o CDN envia `text/plain` e o Safari mostra o código-fonte.
> Hospedagem: Firebase Hosting (`firebase deploy --only hosting`).
> Após alterar a política: `firebase deploy --only hosting` e validar a URL no Safari.

---

## 1) Paid Apps Agreement + banking (obrigatório para assinaturas)

1. Abra [App Store Connect → Agreements, Tax, and Banking](https://appstoreconnect.apple.com/agreements)
2. Aceite **Paid Applications Agreement**
3. Preencha **Banking** e **Tax** (Brasil / sua entidade)
4. Aguarde status **Active**

Sem isso, as assinaturas não ficam disponíveis para venda.

---

## 2) Capabilities no Developer Portal

1. Abra [Certificates, Identifiers & Profiles → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Selecione `luan.com.healthfit.app` e ative:
   - **Sign In with Apple**
   - **HealthKit**
   - **Push Notifications**
   - **Associated Domains** (só se usar)
3. Selecione o Watch App ID `luan.com.healthfit.app.watchkitapp`:
   - **HealthKit**
4. Regenere / baixe o provisioning profile se o Xcode pedir

No Xcode (Signing & Capabilities) confira que os targets iOS/Watch mostram as mesmas capabilities.

---

## 3) Assinaturas (8 Product IDs)

1. App Store Connect → seu app → **Subscriptions**
2. Crie o grupo **HealthFit Plans**
3. Crie 8 auto-renewable subscriptions com IDs **exatos**:

| Nível no grupo | Mensal | Anual | Preço ref. BR |
|----------------|--------|-------|---------------|
| 1 Básico | `healthfit.plan.basic.monthly` | `healthfit.plan.basic.yearly` | 9,90 / 94,90 |
| 2 Fit | `healthfit.plan.fit.monthly` | `healthfit.plan.fit.yearly` | 12,90 / 123,90 |
| 3 IA Plus | `healthfit.plan.ai.monthly` | `healthfit.plan.ai.yearly` | 19,90 / 190,90 |
| 4 Completo | `healthfit.plan.complete.monthly` | `healthfit.plan.complete.yearly` | 24,90 / 239,90 |

4. Localização pt-BR + en-US: nome curto + descrição (mencionar desconto anual)
5. Após criar o grupo, copie o **Subscription Group ID** e substitua no código:
   - `SubscriptionModels.swift` → `subscriptionGroupIDPlaceholder`

Detalhes: `subscriptions.md`

---

## 4) App Privacy (questionário)

App Store Connect → App Privacy → **Edit**

Marque conforme `APP_PRIVACY.md`:

- Email, Name → App Functionality, linked, **not tracking**
- Health + Fitness → App Functionality, linked, **not tracking**
- Photos / Other User Content → App Functionality
- User ID → App Functionality
- Crash Data + Product Interaction (Analytics/Crashlytics) → Analytics / App Functionality, **not tracking**
- Precise Location (treino outdoor + Kite Spot Buddy opt-in) → App Functionality, **not tracking**
  - Ver seção Location em `APP_PRIVACY.md`

Privacy Policy URL:
`https://healthfit-30d87.web.app/privacidade/`

---

## 5) Age Rating

Use `AGE_RATING.md`:

- Quase tudo **None**
- Medical/Treatment Information → **Infrequent/Mild**
- Declare UGC/chat privado da Dupla (sem feed público)
- Controles: denunciar mensagem/conversa + sair do grupo + idade mínima 16+

---

## 6) Screenshots

PNGs 6.7" (1290×2796) prontos em:

`HealthFit/AppStore/screenshots/{pt-BR,en-US,es-ES,fr-FR}/iphone-6.7/`

1. Connect → versão 1.0.0 → Previews and Screenshots → iPhone 6.7"
2. Arraste as 6 imagens de cada idioma (ou reutilize pt-BR)
3. Ideal: substituir por capturas reais do Simulator antes do review final

Gerar de novo:

```bash
.venv-docs/bin/python HealthFit/AppStore/scripts/generate_appstore_screenshots.py
```

---

## 7) Metadados da ficha

Copie de `metadata/` (já dentro dos limites):

- Name = `HealthFit`
- Subtitle / Keywords / Description / What’s New
- Support / Marketing / Privacy = URLs jsDelivr acima

Cole também `review_notes.txt` em App Review Information.

---

## 8) Build → TestFlight → Submit

1. Xcode → Archive (Release) com `GoogleService-Info.plist` real
2. Distribute → App Store Connect
3. Selecione o build na versão 1.0.0
4. Add for Review → Submit

Checklist vivo: `SUBMISSION_CHECKLIST.md`
