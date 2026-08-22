# Documentação HealthFit

Documentação oficial de produto e engenharia — alinhada ao código, aos documentos legais e ao Figma.

**Versão de referência:** 1.0.x · **Atualização:** 21 de agosto de 2026  
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

## Guia do usuário + vídeos

- PDF passo a passo: [`HealthFit_Guia_do_Usuario.pdf`](./HealthFit_Guia_do_Usuario.pdf)
- Vídeos explicativos (slides MP4): [`videos/`](./videos/)
  - `01_visao_geral.mp4` · `02_treinos.mp4` · `03_nutricao.mp4`
  - `04_iassistente.mp4` · `05_dupla_equipe.mp4` · `06_planos.mp4`
- Roteiros para gravação real no iPhone: [`videos/ROTEIROS.md`](./videos/ROTEIROS.md)

### Regenerar

```bash
python3 Docs/generate_docs.py
# ou, se disponível:
python3 Docs/generate_professional_pdf.py

# Guia do usuário + vídeos (venv do Docs):
python3 -m venv .venv-docs
.venv-docs/bin/pip install reportlab pillow imageio imageio-ffmpeg numpy
.venv-docs/bin/python Docs/generate_user_guide_pdf.py
.venv-docs/bin/python Docs/generate_explainer_videos.py
```

## Apresentação comercial

- [`HealthFit_Apresentacao_Comercial.html`](./HealthFit_Apresentacao_Comercial.html) — slides **Banners** (pt-BR / EN / ES / FR) e **Mapa** (publicação mundial)
- [`HealthFit_Mapa_Publicacao.html`](./HealthFit_Mapa_Publicacao.html) — mapa e territórios App Store
- Deck App Store / vendas: [`../HealthFit/AppStore/presentation/HealthFit-Vendas.html`](../HealthFit/AppStore/presentation/HealthFit-Vendas.html)
- Banners localizados: [`../HealthFit/AppStore/marketing/`](../HealthFit/AppStore/marketing/) (`pt-BR`, `en-US`, `es-ES`, `fr-FR`)
- Mapa estático: [`../HealthFit/AppStore/marketing/HealthFit-mapa-publicacao.png`](../HealthFit/AppStore/marketing/HealthFit-mapa-publicacao.png)

## Legais (públicos)

| Documento | URL GitHub Pages | Fonte no app |
|-----------|------------------|--------------|
| Privacidade | https://berglimma.github.io/HealhtFit/privacidade/ | `Resources/Legal/privacy-policy.html` |
| Termos | https://berglimma.github.io/HealhtFit/termos/ | `Resources/Legal/terms-of-use.html` |
| Suporte | https://berglimma.github.io/HealhtFit/suporte/ | — |

Espelhos em `Docs/healthfit/` e URLs públicas em `Docs/privacidade|termos|suporte` (deploy via `Docs/github/pages.workflow.yml`).

## Fatos críticos (código atual)

- Idade mínima: **16 anos**
- Dupla/equipe: chat **12h**, badges de não lidas, sem GPS ao vivo; foto/bandeira nos membros
- Toque em notificação de mensagem → abre o chat
- Logs de acesso (Marco Civil): retenção **6 meses** (`accessLogs`)
- Água: a cada **2h**, **08–20h**
- Abas: Início · Treinos · Nutrição · IAssistente · Perfil
- IAssistente: **regras locais** (sem LLM cloud) + **dia de descanso**
- Nutrição: catálogo + **biblioteca de refeições do usuário** (sync Firestore)
- Outdoor: GPS de corrida/caminhada/bike reforçado; Surf/Kite com mapa
- Conta: **Firebase Auth** + sync de perfil/foto/treinos/wellness
- Nudges cardio/meditação: **48h**
- Relatório técnico: [`../HealthFit/Relatorio_HealthFit_Funcionalidades_e_CodeReview.docx`](../HealthFit/Relatorio_HealthFit_Funcionalidades_e_CodeReview.docx)
