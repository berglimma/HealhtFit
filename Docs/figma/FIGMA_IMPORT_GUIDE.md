# Guia de importação Figma — HealthFit

**Atualizado em:** 10/08/2026  
**Versão do produto:** 1.0.x  
**Arquivo do time:** https://www.figma.com/design/WPvjXR5t3EZbuO962iay3K

## 1. Páginas (plano Starter: máximo 3 páginas)

| # | Página no arquivo | Conteúdo |
|---|-------------------|----------|
| 01 | Cover · Foundations · Auth · Onboarding | Tokens, login, cadastro 16+, boas-vindas |
| 02 | App · Treinos · Dupla · Nutrição · Perfil | Fluxo principal + frames **Dupla / equipe** |
| 03 | Watch · Flows · Health Icon Sync | Watch, Vision, ícone de saúde |

> Não criar página 04 no arquivo do time enquanto o plano for Starter (limite de 3 páginas). O inventário JSON pode listar “página 04” como seção lógica; no canvas os frames Duo ficam na página 02.

## 2. Frames Dupla / equipe (página 02 no canvas)

| Frame | Arquivo SwiftUI |
|-------|-----------------|
| Duo / 01 Hub | `DuoTeamHubView.swift` |
| Duo / 02 Detalhe | `DuoTeamHubView.swift` (detail) |
| Duo / 03 Convite | `DuoTeamInviteView.swift` |
| Duo / 04 Chat | `DuoTeamChatView.swift` — bolhas **AccentGreen** (enviadas) e **cinza claro** (recebidas) |
| Duo / 05 Ranking | `DuoTeamReportView.swift` |

Frames já publicados no arquivo: **Duo / 01 Hub**, **Duo / 04 Chat** (AccentGreen + cinza; TTL 12h; 16+; Marco Civil).

## 3. Tokens

Collection sugerida `HealthFit / Dark`:

- AccentGreen · AccentOrange · Background · CardBackground  
- TextPrimary · TextSecondary  
- cornerRadius 16 · page padding 20  
- Tipografia: SF Pro Display / SF Pro Text  

Fonte canônica: `figma_design_tokens_and_screens.json`.

## 4. Prototype

Conecte os fluxos de `prototypeFlow`, em especial:

`MainTab/Treinos → Duo Hub → Detalhe → Chat`  
`Notificação duoChatMessage → Duo Chat`

## 5. Componentes mínimos

- `Button/Primary` (AccentGreen)
- `Card/Surface`
- `TabBar/5 items`
- `Chat/Bubble User` (verde) e `Chat/Bubble Peer` (cinza claro)
- `Chat/Bubble System` (centralizado)
- `Duo/MemberAvatar` (foto + bandeira)
- `HealthIcon/Green|Yellow|Red`

## 6. Referências

- Mapa HTML: `HealthFit_Screen_Map_Figma.html`
- Inventário JSON: `figma_design_tokens_and_screens.json`
- Documentação: `../HealthFit_Documentacao_Completa.html`
