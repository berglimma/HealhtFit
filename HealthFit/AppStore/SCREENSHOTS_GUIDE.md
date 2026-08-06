# Screenshots — guia para aprovação

A Apple exige screenshots reais do app. Pasta sugerida (ainda vazia):

```
AppStore/screenshots/
  pt-BR/iphone-6.7/
  en-US/iphone-6.7/
  es-ES/iphone-6.7/
  fr-FR/iphone-6.7/
```

## Tamanhos mínimos (2026)

Envie pelo menos:
1. **iPhone 6.7"** (ex.: iPhone 15 Pro Max) — obrigatório se for o size class principal
2. Opcional: iPhone 6.5" / 5.5"
3. Opcional: iPad 13" se o app for oferecido em iPad

No Xcode: Simulator → Device → iPhone 15 Pro Max → File → New Screen Recording / Cmd+S.

## 6 capturas recomendadas (ordem)

| # | Tela | Mensagem na moldura (opcional) |
|---|------|--------------------------------|
| 1 | Dashboard / Início | “Seu painel de evolução” |
| 2 | Lista de treinos (Cardio + Luta) | “Treinos e modalidades” |
| 3 | Treino ativo / GIF + Começar exercício | “Treino guiado” |
| 4 | Nutrição / cardápio | “Cardápio e metas” |
| 5 | IAssistente | “Orientação no dia a dia” |
| 6 | Apple Watch ou Corrida com mapa | “Watch + Health” |

## Regras Apple
- Sem frames enganosos de hardware obrigatórios; molduras são opcionais
- Texto na imagem deve bater com o idioma da localização
- Não prometer “nutricionista humano” ou “médico”
- Pode reutilizar o mesmo set de screenshots nos 4 idiomas se a UI estiver localizada

## Atalho
1. Rode o app no simulador `iPhone 15 Pro Max`
2. Navegue pelas 6 telas e salve PNGs
3. Arraste para App Store Connect → cada localização
