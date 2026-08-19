# Access Logs TTL + Duo FCM (HealthFit)

## 1. TTL nativo dos `accessLogs` (recomendado)

O app já grava `expiresAt` (+6 meses) em cada log. Ative o TTL do Firestore
para o campo ser apagado automaticamente pelo Google (sem custo de Function
por delete):

```bash
# Projeto Firebase / GCP
gcloud config set project SEU_PROJECT_ID

gcloud firestore fields ttls update expiresAt \
  --collection-group=accessLogs \
  --enable-ttl
```

Confirme no Console: Firestore → Data → TTL policies.

A Function `purgeExpiredAccessLogs` (agendada 1×/dia) é **backup** caso o TTL
demore a propagar ou docs antigos não tenham o campo corretamente.

## 2. Deploy das Cloud Functions

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions,firestore:rules
```

Região padrão: `southamerica-east1`.

### Functions exportadas

| Nome | Trigger | Função |
|------|---------|--------|
| `purgeExpiredAccessLogs` | Schedule diário | Apaga `accessLogs` com `expiresAt < now` |
| `onDuoChatMessageCreated` | `duoTeams/{id}/messages/{id}` create | Push FCM aos outros membros |

## 3. Duo + FCM (esqueleto)

1. No Firebase Console → Cloud Messaging, habilite APNs (chave .p8).
2. No Xcode: Signing & Capabilities → Push Notifications (já há
   `remote-notification` no Info.plist; entitlements `aps-environment`).
3. O iOS grava tokens em `users/{uid}/fcmTokens/{tokenId}`.
4. Ao enviar mensagem no chat Duo, a Function dispara o push.

Inbox Firestore (`duoNotifications`) permanece para app em foreground;
FCM cobre app em background / morto. A Function lê `text`/`senderName` no
documento (e faz fallback do JSON `payload`) e envia alerta APNs com
`apns-priority: 10` para chegar em segundos mesmo com o app fechado.
Para garantir menos de 15s após ociosidade longa, opcional: `minInstances: 1`
na Function (custo de instância quente).

## 4. Custos / escala

- TTL nativo: deletes gerenciados pelo Firestore (sem execução de Function).
- Purge Function: no máximo ~8k deletes/dia no backup.
- Duo FCM: 1 trigger por mensagem + N tokens (limitado a 8 tokens/usuário).
