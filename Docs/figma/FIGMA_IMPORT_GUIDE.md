# Guia de importação Figma — HealthFit

**Gerado em:** 24/07/2026  
**Versão do produto:** 1.0.0

> O MCP do Figma não estava autenticado neste ambiente. Este pacote entrega o inventário
> completo de frames, tokens e fluxos para você montar (ou sincronizar) o arquivo Figma
> em minutos.

## 1. Criar o arquivo

1. Abra o Figma → **New design file** → renomeie para `HealthFit — Product Screens`.
2. Crie as páginas listadas em `figma_design_tokens_and_screens.json` → `figmaPages`.
3. Em **Local variables**, crie a collection `HealthFit / Dark` com as cores do JSON.

## 2. Frames por tela

Para cada item em `screens[]`:

1. Crie um frame **iPhone 14/15 Pro (393×852)** (ou Watch quando `device` indicar).
2. Nomeie exatamente como `figmaFrame` (ex.: `Treinos / 01 Hub`).
3. Adicione uma anotação (sticky ou text) com:
   - Propósito
   - Arquivo SwiftUI
   - Ações principais
4. Use o HTML `HealthFit_Screen_Map_Figma.html` como referência visual lado a lado.

## 3. Prototype

Conecte os fluxos de `prototypeFlow` com setas de protótipo (On click / Navigate to).

## 4. Componentes mínimos sugeridos

- `Button/Primary` (AccentGreen)
- `Button/Secondary`
- `Card/Surface`
- `TabBar/5 items`
- `Chat/Bubble User` e `Chat/Bubble Assistant`
- `HealthIcon/Green|Yellow|Red`
- `List/Row Workout`

## 5. Entrega

Exporte:

- PDF do arquivo Figma (File → Export frames to PDF), **ou**
- Use o PDF gerado em `Docs/HealthFit_Documentacao_Completa.pdf` como documento mestre
  de produto/engenharia, e o Figma como source of truth visual.
