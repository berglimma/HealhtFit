# Documentação HealthFit

Documentação oficial de produto e engenharia — alinhada ao código e ao Figma.

## Figma

**Arquivo do time:** [HealthFit — Telas e Documentação](https://www.figma.com/design/WPvjXR5t3EZbuO962iay3K)

| Página | Conteúdo |
|--------|----------|
| 01 | Cover, tokens reais do Asset Catalog, Auth, Onboarding |
| 02 | App: Dashboard (ícone sync), Treinos, Cardio, Meditação, Nutrição, IAssistente, Perfil |
| 03 | Watch, Vision AI, trio Verde/Amarelo/Vermelho, fluxos e Firebase |

## PDF profissional

**Arquivo:** [HealthFit_Documentacao_Completa.pdf](./HealthFit_Documentacao_Completa.pdf) (12 páginas A4)

Capítulos: sumário executivo, stack, arquitetura, catálogo de 26 telas, design system + ícone de saúde, treinos, nutrição, IAssistente rule-based, Firebase, notificações (água 2h), Watch/HealthKit, qualidade e Figma.

### Regenerar

```bash
python3 Docs/generate_professional_pdf.py
```

## Fatos críticos (código atual)

- Ícone de saúde: `DailyWellnessService.healthIconStatus` → Dashboard + Perfil + Home Screen
- Água: a cada **2h**, **08–20h**
- Abas: Início · Treinos · Nutrição · IAssistente · Perfil
- IAssistente: **regras locais** (sem LLM cloud)
- Nudges cardio/meditação: **48h**
