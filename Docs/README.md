# Documentação HealthFit

Pacote profissional de documentação de produto e engenharia.

## Entregáveis

| Arquivo | Descrição |
|---------|-----------|
| [HealthFit_Documentacao_Completa.pdf](./HealthFit_Documentacao_Completa.pdf) | **PDF mestre** — visão de produto, telas, arquitetura, Firebase, notificações, Watch |
| [HealthFit_Documentacao_Completa.html](./HealthFit_Documentacao_Completa.html) | Versão HTML do PDF (editável / reimprimível) |
| [figma/HealthFit_Screen_Map_Figma.pdf](./figma/HealthFit_Screen_Map_Figma.pdf) | Mapa visual de telas (estilo Figma) em PDF |
| [figma/HealthFit_Screen_Map_Figma.html](./figma/HealthFit_Screen_Map_Figma.html) | Board interativo de frames por área |
| [figma/figma_design_tokens_and_screens.json](./figma/figma_design_tokens_and_screens.json) | Tokens + inventário de frames para importar no Figma |
| [figma/FIGMA_IMPORT_GUIDE.md](./figma/FIGMA_IMPORT_GUIDE.md) | Passo a passo para montar o arquivo Figma |

## Regenerar

```bash
python3 Docs/generate_docs.py
```

Requisitos: Python 3 e Google Chrome (para `--print-to-pdf`).

## Figma

O MCP do Figma pode não estar autenticado no ambiente do agente. Os artefatos em `Docs/figma/` permitem criar o arquivo Figma com nomenclatura de frames alinhada ao código (`Área / NN Nome`).
