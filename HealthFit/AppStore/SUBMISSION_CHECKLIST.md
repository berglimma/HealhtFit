# Checklist — publicar HealthFit na App Store

Versão alvo: **1.0.2 (Build 6)** · Bundle `luan.com.healthfit.app`

## URLs legais (já no app e metadados)

- Site: https://healthfit-30d87.web.app/
- Privacidade (copiar no Connect): https://healthfit-30d87.web.app/privacidade/
- Termos: https://healthfit-30d87.web.app/termos/
- Suporte: https://healthfit-30d87.web.app/suporte/

## Pronto no repositório

- [x] Política de privacidade com Kite Spot Buddy (§4.1) + localização / consentimento LGPD
- [x] `APP_PRIVACY.md` com Precise Location (App Functionality, sem tracking)
- [x] `privacy_notes.txt` (pt-BR, en-US, es-ES, fr-FR)
- [x] `whatsnew.txt` + `review_notes.txt` para 1.0.2 (6)
- [x] Versão Xcode **1.0.2 (6)**
- [x] Textos de permissão de localização mencionam Spot Buddy
- [x] Firestore rules `kiteSpotPresence`
- [x] Feature Spot Buddy (iPhone + Watch)

## Você no App Store Connect (antes de Submit)

> Guia detalhado: [`CONNECT_FILL_GUIDE.md`](./CONNECT_FILL_GUIDE.md)

1. **App Information → Privacy Policy URL** = `https://healthfit-30d87.web.app/privacidade/`
2. **App Privacy → Edit** conforme `APP_PRIVACY.md` — declarar **Precise Location** (App Functionality, linked, not tracking)
3. Nova versão **1.0.2** → colar `whatsnew` do idioma
4. **Support URL** / Marketing URL dos arquivos `metadata/*/support_url.txt` e `marketing_url.txt`
5. Colar `review_notes.txt` em App Review Information
6. Conta demo: `healthfit.appreview@gmail.com` (senha só no App Store Connect Review Information)
7. Xcode: **Product → Archive** → upload build **6** → selecionar no Connect → **Add for Review**

## Testes rápidos pré-envio

- [ ] Links Privacidade/Termos/Suporte abrem no Safari (HTML, não código-fonte)
- [ ] Kitesurf → Spot Buddy on → Abrir mapa + página Watch
- [ ] Duo chat sem mapa em tempo real (inalterado)
- [ ] Excluir conta (conta de teste)
- [ ] Restore compras (Sandbox)

## Enviar

- [ ] Archive 1.0.2 (6)
- [ ] Attach build
- [ ] Submit for Review
