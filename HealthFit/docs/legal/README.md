# Hospedagem dos documentos legais

## URLs públicas (Firebase Hosting — use estas na App Store)

| Documento | URL |
|-----------|-----|
| Marketing | https://healthfit-30d87.web.app/ |
| Política de Privacidade | https://healthfit-30d87.web.app/privacidade/ |
| Termos de Uso | https://healthfit-30d87.web.app/termos/ |
| Suporte | https://healthfit-30d87.web.app/suporte/ |

Fontes HTML: pasta `Docs/` na raiz do repositório. Publicar com `firebase deploy --only hosting`.

O domínio `blswiftsolutions.com` ainda retorna 403; quando estiver online, atualize `AppLegalConfiguration.swift` e os arquivos em `AppStore/metadata/*/`.

## App Store Connect

Informe a URL da Política de Privacidade no campo **Privacy Policy URL**.
Support URL deve ser **https** (não use `mailto:`).
