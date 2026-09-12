# HealthFit Pulse — Production Go-Live Checklist

Pulse ships **OFF by default**. Git/App Store builds do not enable the feature until Firestore flags flip.

## Defaults (do not change until go-live)

| Flag | Firestore path | Production default |
|------|----------------|--------------------|
| UI | `appConfig/ios.pulseEnabled` | `false` |
| Cloud sync | `appConfig/ios.pulseCloudSyncEnabled` | `false` |

Release builds **ignore** Labs UserDefaults overrides (DEBUG only).

## Before first enable

### 1. Ship client
- [ ] Commit Pulse sources + rules + legal copy
- [ ] Archive **Release** (chat/video compile OFF)
- [ ] Confirm Dashboard Pulse card hidden with flags false
- [ ] TestFlight smoke with Labs OFF

### 2. Backend
```bash
firebase deploy --only firestore:rules,storage
firebase deploy --only hosting
```
- [ ] Rules include `pulsePosts`, `pulseStories`, `pulseProfiles`, `pulseFollows`, `pulseBlocks`, `pulseReports`, Storage `pulse/{uid}/`
- [ ] Hosting: `/privacidade/`, `/termos/`, `/suporte/` mention Pulse UGC 18+
- [ ] Support/moderator: `healthfit.appreview@gmail.com`

### 3. Account deletion
- [ ] Delete account removes Pulse Firestore + Storage + local store (already wired in `AuthService`)
- [ ] Pulse menu → Excluir conta HealthFit works end-to-end

### 4. App Store Connect (when enabling UI)
- [ ] Age Rating: app **16+**, Pulse UGC **18+** (fix store if still 13+)
- [ ] Privacy Nutrition Labels: UGC / photos
- [ ] User-Generated Content questionnaire
- [ ] Review notes: Pulse gated 18+, report/block/moderation email

### 5. Staged enable
1. Confirm both flags `false` in Console
2. Set `pulseEnabled: true` (UI only) → smoke photo post, story, Deezer, share Instagram (music on card), follow, report
3. Set `pulseCloudSyncEnabled: true` → verify cross-device pull
4. Moderator opens Moderation queue with support account

## Smoke tests

- [ ] Publish photo + music → feed autoplay near card
- [ ] Share to Instagram → card shows music sticker + caption has ♪ + link
- [ ] Workout summary → Compartilhar no Pulse (card + foto/vídeo)
- [ ] Report / hide / block
- [ ] Delete account wipes Pulse cloud data
- [ ] Under-18 sees age gate

## Out of scope for v1 Release

- Native Instagram music sticker (Meta App ID / Stories API)
- In-app video posts (DEBUG only)
- Community chat (DEBUG only)
- Automated CSAM scanner (manual moderation)

## Rollback

Set both Firestore flags to `false`. No app update required to hide Pulse UI and stop cloud writes from clients that check the flags.
