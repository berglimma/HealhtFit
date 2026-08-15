import {initializeApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";
import {setGlobalOptions} from "firebase-functions/v2";

initializeApp();
setGlobalOptions({region: "southamerica-east1", maxInstances: 10});

const db = getFirestore();

/**
 * Backup de limpeza para accessLogs (Marco Civil — retenção 6 meses).
 *
 * Preferência: ative também o TTL nativo do Firestore em `expiresAt`
 * (ver Docs/firebase/ACCESS_LOGS_TTL_AND_DUO_FCM.md). Esta função
 * apaga em lotes o que ainda estiver vencido.
 */
export const purgeExpiredAccessLogs = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "America/Sao_Paulo",
  },
  async () => {
    const now = Timestamp.now();
    let totalDeleted = 0;

    // Até 20 páginas × 400 docs = 8k deletes/dia — suficiente como backup do TTL.
    for (let page = 0; page < 20; page++) {
      const snap = await db
        .collection("accessLogs")
        .where("expiresAt", "<", now)
        .limit(400)
        .get();

      if (snap.empty) break;

      const batch = db.batch();
      for (const doc of snap.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
      totalDeleted += snap.size;

      if (snap.size < 400) break;
    }

    logger.info("purgeExpiredAccessLogs done", {totalDeleted});
  },
);

type DuoMessage = {
  senderUid?: string;
  senderName?: string;
  text?: string;
  kind?: string;
};

/**
 * Esqueleto Duo + FCM: ao criar mensagem no chat, envia push aos demais membros.
 * Coexiste com inbox local (`duoNotifications`) no app.
 */
export const onDuoChatMessageCreated = onDocumentCreated(
  "duoTeams/{teamId}/messages/{messageId}",
  async (event) => {
    const data = event.data?.data() as DuoMessage | undefined;
    if (!data) return;

    const kind = data.kind ?? "text";
    if (kind === "system") return;

    const teamId = event.params.teamId;
    const senderUid = data.senderUid ?? "";
    const senderName = (data.senderName ?? "Alguém").trim() || "Alguém";
    const rawText = (data.text ?? "").trim();
    if (!rawText) return;

    const teamSnap = await db.collection("duoTeams").doc(teamId).get();
    if (!teamSnap.exists) return;

    const team = teamSnap.data() ?? {};
    const teamName = (team.name as string | undefined) ?? "Equipe";
    const memberUids = (team.memberUids as string[] | undefined) ?? [];
    const recipients = memberUids.filter((uid) => uid && uid !== senderUid);
    if (recipients.length === 0) return;

    const preview =
      rawText.length > 120 ? `${rawText.slice(0, 117)}…` : rawText;
    const title =
      kind === "scheduleProposal"
        ? `Proposta de treino · ${teamName}`
        : `Nova mensagem · ${teamName}`;
    const body = `${senderName}: ${preview}`;

    const tokens: string[] = [];
    for (const uid of recipients) {
      const tokenSnap = await db
        .collection("users")
        .doc(uid)
        .collection("fcmTokens")
        .limit(8)
        .get();
      for (const doc of tokenSnap.docs) {
        const token = doc.data().token as string | undefined;
        if (token && token.length > 20) tokens.push(token);
      }
    }

    const uniqueTokens = Array.from(new Set(tokens));
    if (uniqueTokens.length === 0) {
      logger.info("onDuoChatMessageCreated: no FCM tokens", {teamId, recipients});
      return;
    }

    const response = await getMessaging().sendEachForMulticast({
      tokens: uniqueTokens,
      notification: {title, body},
      data: {
        type: kind === "scheduleProposal" ? "duoChatSchedule" : "duoChatMessage",
        teamId,
        teamName,
        kind: "DUO_TEAM",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    // Remove tokens inválidos sob o próprio usuário (best-effort).
    for (let i = 0; i < response.responses.length; i++) {
      const res = response.responses[i];
      if (res.success) continue;
      const code = res.error?.code ?? "";
      if (
        !code.includes("registration-token-not-registered") &&
        !code.includes("invalid-registration-token")
      ) {
        continue;
      }
      const badToken = uniqueTokens[i];
      for (const uid of recipients) {
        const hit = await db
          .collection("users")
          .doc(uid)
          .collection("fcmTokens")
          .where("token", "==", badToken)
          .limit(3)
          .get();
        const batch = db.batch();
        hit.docs.forEach((d) => batch.delete(d.ref));
        if (!hit.empty) await batch.commit();
      }
    }

    logger.info("onDuoChatMessageCreated push", {
      teamId,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  },
);
