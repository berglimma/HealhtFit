# HealthFit Pulse — Production Go-Live Checklist

Pulse em produção fica **OFF** até `appConfig/ios.pulseEnabled` ser `true`.  
Deploy de rules/storage/hosting **não liga** o recurso para o app da loja.

## Defaults (produção até go-live / review)

| Flag | Firestore path | Valor seguro agora |
|------|----------------|--------------------|
| UI | `appConfig/ios.pulseEnabled` | `false` (ligar só na App Review / go-live) |
| Cloud sync | `appConfig/ios.pulseCloudSyncEnabled` | `false` |

Release builds **ignoram** Labs (DEBUG only).

## Deploy seguro (não altera flags)

```bash
firebase deploy --only firestore:rules,storage
firebase deploy --only hosting
```

Depois, no Console, **confirme** que `pulseEnabled` e `pulseCloudSyncEnabled` continuam `false`.

## Before first enable

### 1. Ship client
- [x] Fontes Pulse + entitlement (trial 15 dias → Básico)
- [ ] Commit + Archive **Release** 1.0.5 (13)
- [ ] TestFlight smoke com flags `false` (card oculto) e com `true` (fluxo completo)

### 2. Backend
- [ ] Rules incluem `pulsePosts`, `pulseStories`, `pulseProfiles`, `pulseFollows`, `pulseBlocks`, `pulseReports`, Storage `pulse/{uid}/`
- [x] Hosting: `/privacidade/`, `/termos/`, `/suporte/` mencionam Pulse UGC 18+
- [x] Support/moderator: `healthfit.appreview@gmail.com`

### 3. Account deletion
- [ ] Delete account remove Pulse Firestore + Storage + local store
- [ ] Pulse menu → Excluir conta HealthFit

### 4. App Store Connect
- [ ] Age Rating: app **16+**, Pulse UGC **18+**
- [ ] Privacy Nutrition Labels: UGC / photos
- [ ] User-Generated Content questionnaire
- [ ] Review notes: Pulse 18+, report/block, trial local (não é intro offer Apple)

### 5. Staged enable
1. Confirmar ambos `false` após o deploy
2. Na Review / go-live: `pulseEnabled: true` → smoke
3. `pulseCloudSyncEnabled: true` → sync multi-device
4. Moderação com conta suporte

## Smoke tests

- [ ] Publish photo + music → feed
- [ ] Workout summary → Compartilhar no Pulse
- [ ] Report / hide / block
- [ ] Delete account wipes Pulse cloud data
- [ ] Under-18 sees age gate

## Rollback

Set both Firestore flags to `false`. No app update required to hide Pulse UI.
