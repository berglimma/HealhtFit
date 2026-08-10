# Documentação HealthFit

Documentação oficial de produto e engenharia — alinhada ao código, aos documentos legais e ao Figma.

**Versão de referência:** 1.0.x · **Atualização:** 10 de agosto de 2026  
**Desenvolvimento:** Berg Limma e Luan Chiminelli

## Figma

**Arquivo do time:** [HealthFit — Telas e Documentação](https://www.figma.com/design/WPvjXR5t3EZbuO962iay3K)

| Página (canvas · máx. 3 no Starter) | Conteúdo |
|--------|----------|
| 01 | Cover, tokens, Auth (idade 16+), Onboarding |
| 02 | App + **Dupla / equipe** (hub, chat AccentGreen/cinza, convites) · Treinos · Nutrição · Perfil |
| 03 | Watch, Vision AI, ícone de saúde, Firebase |

Inventário de frames: [`figma/figma_design_tokens_and_screens.json`](./figma/figma_design_tokens_and_screens.json)  
Mapa visual HTML: [`figma/HealthFit_Screen_Map_Figma.html`](./figma/HealthFit_Screen_Map_Figma.html)  
Guia de importação: [`figma/FIGMA_IMPORT_GUIDE.md`](./figma/FIGMA_IMPORT_GUIDE.md)

## Documentação completa

- HTML: [`HealthFit_Documentacao_Completa.html`](./HealthFit_Documentacao_Completa.html)
- PDF: [`HealthFit_Documentacao_Completa.pdf`](./HealthFit_Documentacao_Completa.pdf)

Capítulos: sumário executivo, stack, arquitetura, catálogo de telas (incluindo Dupla/equipe), design system, Firebase, notificações, Watch/HealthKit, privacidade (16+, Marco Civil 6 meses) e Figma.

### Regenerar

```bash
python3 Docs/generate_docs.py
# ou, se disponível:
python3 Docs/generate_professional_pdf.py
```

## Apresentação comercial

- [`HealthFit_Apresentacao_Comercial.html`](./HealthFit_Apresentacao_Comercial.html)
- Deck App Store / vendas: [`../HealthFit/AppStore/presentation/HealthFit-Vendas.html`](../HealthFit/AppStore/presentation/HealthFit-Vendas.html)

## Legais (públicos)

| Documento | URL GitHub Pages | Fonte no app |
|-----------|------------------|--------------|
| Privacidade | https://berglimma.github.io/HealhtFit/privacidade/ | `Resources/Legal/privacy-policy.html` |
| Termos | https://berglimma.github.io/HealhtFit/termos/ | `Resources/Legal/terms-of-use.html` |
| Suporte | https://berglimma.github.io/HealhtFit/suporte/ | — |

Espelhos em `Docs/healthfit/` para deploy Pages (`/docs`).

## Fatos críticos (código atual)

- Idade mínima: **16 anos**
- Dupla/equipe: chat **12h**, sem GPS ao vivo; foto/bandeira nos membros
- Toque em notificação de mensagem → abre o chat
- Logs de acesso (Marco Civil): retenção **6 meses** (`accessLogs`)
- Água: a cada **2h**, **08–20h**
- Abas: Início · Treinos · Nutrição · IAssistente · Perfil
- IAssistente: **regras locais** (sem LLM cloud)
- Nudges cardio/meditação: **48h**
