# HealthFit — Checklist pós-lançamento (v1.0)

App Store: https://apps.apple.com/app/id6798621208  
Bundle: `luan.com.healthfit.app` · Versão **1.0.0 (4)**

## Imediato (primeiras 48h)

- [ ] Baixar o app da loja em um iPhone limpo (busca "HealthFit" ou link acima)
- [ ] Login com conta demo: `healthfit.appreview@gmail.com` (senha no App Store Connect)
- [ ] Testar compra sandbox: Perfil → Meu plano → assinar → Restaurar compras
- [ ] Testar código cortesia: Perfil → Meu plano → Tenho um código de cortesia
- [ ] Confirmar links na ficha (Privacidade, Suporte, Termos) abrem no Safari
- [ ] Apagar rascunho vazio em Connect → Revisão de apps (se ainda existir)

## Monitoramento

- [ ] App Store Connect → **Análise** (impressões, downloads, conversão)
- [ ] Firebase Console → Auth, Firestore, Crashlytics (se habilitado)
- [ ] E-mail `berg.limma@gmail.com` para respostas da Apple e suporte
- [ ] TestFlight: manter build de correção rápida se surgir bug crítico

## ASO e marketing (semana 1)

- [ ] Pedir 5–10 avaliações honestas (amigos, beta testers, personal)
- [ ] Compartilhar link da loja: https://apps.apple.com/app/id6798621208
- [ ] Redes: usar banners em `AppStore/marketing/{pt-BR,en-US,es-ES,fr-FR}/`
- [ ] Considerar **texto promocional** no Connect (atualizável sem nova versão)
- [ ] Expandir metadados **en-US / es-ES / fr-FR** (screenshots + descrição por idioma)

## Produto (próximas versões)

- [ ] Corrigir discrepância etária: app declara **16+**, loja mostra **13+** (revisar Age Rating)
- [ ] Preencher **Acessibilidade do app** no Connect (VoiceOver, contraste, etc.)
- [ ] Remover/restringir Cloud Functions internas (`seedCourtesyVouchers`, `ensureAppReviewDemoAccount`) se não forem mais necessárias
- [ ] Planejar **1.0.1** ou **1.1** com correções de feedback real de usuários

## Assinaturas e receita

- [ ] Connect → **Pagamentos e relatórios financeiros** (primeira venda pode levar dias)
- [ ] Verificar preços BR vs USD na ficha pública
- [ ] Opcional: oferta introdutória (7 dias grátis no Completo anual) em versão futura

## Suporte ao usuário

- [ ] Responder e-mails em `berg.limma@gmail.com` em até 2 dias úteis
- [ ] Documentar problemas frequentes em `Docs/suporte/index.html`
- [ ] Duo/chat: monitorar denúncias em `berg.limma@gmail.com`

## Quando lançar atualização

1. Corrigir no Xcode → bump **build** (e **versão** se mudança visível)
2. Archive → Upload → selecionar build na nova versão
3. Preencher **Novidades** (`metadata/*/whatsnew.txt`)
4. Atualizar `review_notes.txt` se fluxos mudarem
5. Enviar para revisão (updates costumam ser mais rápidos que 1.0)
