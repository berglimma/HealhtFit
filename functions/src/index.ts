import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onCall, HttpsError, onRequest} from "firebase-functions/v2/https";
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
  payload?: unknown;
};

function firstNonEmpty(...values: Array<string | undefined>): string {
  for (const value of values) {
    const trimmed = value?.trim() ?? "";
    if (trimmed) return trimmed;
  }
  return "";
}

/** O iOS grava o corpo em `payload` (JSON); campos top-level são o caminho rápido. */
function fieldsFromPayload(payload: unknown): DuoMessage {
  if (typeof payload !== "string" || !payload.trim()) return {};
  try {
    const parsed = JSON.parse(payload) as Record<string, unknown>;
    return {
      senderUid: typeof parsed.senderUid === "string" ? parsed.senderUid : undefined,
      senderName:
        typeof parsed.senderName === "string" ? parsed.senderName : undefined,
      text: typeof parsed.text === "string" ? parsed.text : undefined,
      kind: typeof parsed.kind === "string" ? parsed.kind : undefined,
    };
  } catch {
    return {};
  }
}

/**
 * Push FCM aos demais membros ao criar mensagem no chat.
 * Coexiste com inbox local (`duoNotifications`) no app.
 * Instância mínima evita cold start > 15s; APNs priority 10 entrega alerta imediato.
 */
export const onDuoChatMessageCreated = onDocumentCreated(
  {
    document: "duoTeams/{teamId}/messages/{messageId}",
    timeoutSeconds: 30,
    memory: "256MiB",
    concurrency: 20,
  },
  async (event) => {
    const data = event.data?.data() as DuoMessage | undefined;
    if (!data) return;

    const nested = fieldsFromPayload(data.payload);
    const kind = firstNonEmpty(data.kind, nested.kind) || "text";
    if (kind === "system") return;

    const teamId = event.params.teamId;
    const senderUid = firstNonEmpty(data.senderUid, nested.senderUid);
    const senderName =
      firstNonEmpty(data.senderName, nested.senderName) || "Alguém";
    const rawText = firstNonEmpty(data.text, nested.text);
    if (!rawText) {
      logger.info("onDuoChatMessageCreated: empty text, skip", {teamId});
      return;
    }

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
    const chatType =
      kind === "scheduleProposal" ? "duoChatSchedule" : "duoChatMessage";

    const tokenSnaps = await Promise.all(
      recipients.map((uid) =>
        db.collection("users").doc(uid).collection("fcmTokens").limit(8).get()
      )
    );
    const tokens: string[] = [];
    for (const tokenSnap of tokenSnaps) {
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
        type: chatType,
        teamId,
        teamName,
        kind: chatType,
        category: "DUO_TEAM",
      },
      android: {priority: "high"},
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: {title, body},
            sound: "default",
            badge: 1,
            category: "DUO_TEAM",
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

const COURTESY_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const COURTESY_PLAN_RANK: Record<string, number> = {
  basic: 1,
  fit: 2,
  ai: 3,
  complete: 4,
};
const COURTESY_PLAN_LABEL: Record<string, string> = {
  basic: "Básico",
  fit: "Fit",
  ai: "IA Plus",
  complete: "Completo",
};

function normalizeCourtesyCode(raw: string): string {
  return raw
    .trim()
    .toUpperCase()
    .replace(/[–—]/g, "-")
    .replace(/[^A-Z0-9-]/g, "");
}

function isValidCourtesyCode(code: string): boolean {
  const match = /^HF-(BASIC|FIT|AI|COMPLETE)-([A-Z2-9]{6})$/.exec(code);
  if (!match) return false;
  return [...match[2]].every((ch) => COURTESY_ALPHABET.includes(ch));
}

/**
 * Resgata um voucher de cortesia (30 dias) para o usuário autenticado.
 * Códigos são de uso único; o brinde fica em courtesyGrants/{uid}.
 */
export const redeemCourtesyVoucher = onCall(
  {
    cors: true,
    invoker: "public",
    timeoutSeconds: 15,
    memory: "256MiB",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "Entre na sua conta para resgatar o código."
      );
    }

    const code = normalizeCourtesyCode(String(request.data?.code ?? ""));
    if (!isValidCourtesyCode(code)) {
      throw new HttpsError(
        "invalid-argument",
        "Código inválido. Confira e tente de novo."
      );
    }

    const voucherRef = db.collection("courtesyVouchers").doc(code);
    const grantRef = db.collection("courtesyGrants").doc(uid);

    const result = await db.runTransaction(async (tx) => {
      const voucherSnap = await tx.get(voucherRef);
      if (!voucherSnap.exists) {
        throw new HttpsError("not-found", "Código inválido ou inexistente.");
      }

      const voucher = voucherSnap.data() ?? {};
      const redeemedBy = voucher.redeemedBy as string | undefined;
      if (redeemedBy) {
        if (redeemedBy === uid) {
          throw new HttpsError(
            "failed-precondition",
            "Você já resgatou este código."
          );
        }
        throw new HttpsError(
          "failed-precondition",
          "Este código já foi usado."
        );
      }

      const plan = String(voucher.plan ?? "");
      const planRank = COURTESY_PLAN_RANK[plan] ?? 0;
      if (planRank < 1) {
        throw new HttpsError("internal", "Plano do voucher inválido.");
      }

      const durationDays = Number(voucher.durationDays) || 30;
      const grantSnap = await tx.get(grantRef);
      if (grantSnap.exists) {
        const existing = grantSnap.data() ?? {};
        const existingExpires = existing.expiresAt as Timestamp | undefined;
        const stillActive =
          existingExpires != null && existingExpires.toMillis() > Date.now();
        const existingRank = COURTESY_PLAN_RANK[String(existing.plan)] ?? 0;
        if (stillActive && existingRank > planRank) {
          const label =
            COURTESY_PLAN_LABEL[String(existing.plan)] ?? String(existing.plan);
          throw new HttpsError(
            "failed-precondition",
            `Você já tem cortesia do plano ${label} ativa.`
          );
        }
      }

      const now = Timestamp.now();
      const expiresAt = Timestamp.fromMillis(
        Date.now() + durationDays * 24 * 60 * 60 * 1000
      );

      tx.update(voucherRef, {
        redeemedBy: uid,
        redeemedAt: now,
      });
      tx.set(grantRef, {
        plan,
        durationDays,
        code,
        redeemedAt: now,
        expiresAt,
      });

      return {
        plan,
        durationDays,
        expiresAtMs: expiresAt.toMillis(),
      };
    });

    logger.info("redeemCourtesyVoucher", {uid, code, plan: result.plan});
    return result;
  }
);

/** Uso interno: popular courtesyVouchers via `npm run seed:courtesy -- --deploy`. */
const COURTESY_SEED_KEY = "healthfit-courtesy-seed-v2-40x";

export const seedCourtesyVouchers = onRequest(
  {
    region: "southamerica-east1",
    timeoutSeconds: 120,
    memory: "256MiB",
    invoker: "public",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({error: "Use POST"});
      return;
    }
    if (req.get("x-healthfit-seed-key") !== COURTESY_SEED_KEY) {
      res.status(403).json({error: "Forbidden"});
      return;
    }

    const vouchers = req.body?.vouchers as Array<{
      code: string;
      plan: string;
      durationDays: number;
      batchId: string;
    }> | undefined;

    if (!Array.isArray(vouchers) || vouchers.length === 0) {
      res.status(400).json({error: "Missing vouchers array"});
      return;
    }

    const batchId = String(vouchers[0]?.batchId ?? "");
    const existing = await db
      .collection("courtesyVouchers")
      .where("batchId", "==", batchId)
      .limit(1)
      .get();

    if (!existing.empty) {
      res.status(409).json({
        error: "Batch already exists",
        batchId,
        count: existing.size,
      });
      return;
    }

    const now = Timestamp.now();
    let written = 0;
    for (let i = 0; i < vouchers.length; i += 400) {
      const slice = vouchers.slice(i, i + 400);
      const batch = db.batch();
      for (const item of slice) {
        const ref = db.collection("courtesyVouchers").doc(item.code);
        batch.set(ref, {
          code: item.code,
          plan: item.plan,
          durationDays: item.durationDays,
          batchId: item.batchId,
          redeemedBy: null,
          redeemedAt: null,
          createdAt: now,
        });
      }
      await batch.commit();
      written += slice.length;
    }

    logger.info("seedCourtesyVouchers", {batchId, written});
    res.json({ok: true, batchId, written});
  }
);

const DEMO_REVIEW_EMAIL = "healthfit.appreview@gmail.com";
const DEMO_REVIEW_PASSWORD = "HealthFitReview2026!";

/** Uso interno: garantir conta demo para App Review (`npm run ensure:demo-account`). */
export const ensureAppReviewDemoAccount = onRequest(
  {
    region: "southamerica-east1",
    timeoutSeconds: 30,
    memory: "256MiB",
    invoker: "public",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({error: "Use POST"});
      return;
    }
    if (req.get("x-healthfit-seed-key") !== COURTESY_SEED_KEY) {
      res.status(403).json({error: "Forbidden"});
      return;
    }

    const auth = getAuth();

    try {
      const existing = await auth.getUserByEmail(DEMO_REVIEW_EMAIL);
      await auth.updateUser(existing.uid, {
        password: DEMO_REVIEW_PASSWORD,
        emailVerified: true,
        displayName: "App Review",
        disabled: false,
      });
      logger.info("ensureAppReviewDemoAccount", {uid: existing.uid, created: false});
      res.json({ok: true, created: false, uid: existing.uid, email: DEMO_REVIEW_EMAIL});
      return;
    } catch (error: unknown) {
      const code = (error as {code?: string})?.code;
      if (code !== "auth/user-not-found") {
        logger.error("ensureAppReviewDemoAccount lookup", error);
        res.status(500).json({error: "Failed to check demo user"});
        return;
      }
    }

    try {
      const user = await auth.createUser({
        email: DEMO_REVIEW_EMAIL,
        password: DEMO_REVIEW_PASSWORD,
        emailVerified: true,
        displayName: "App Review",
      });
      logger.info("ensureAppReviewDemoAccount", {uid: user.uid, created: true});
      res.json({ok: true, created: true, uid: user.uid, email: DEMO_REVIEW_EMAIL});
    } catch (error) {
      logger.error("ensureAppReviewDemoAccount create", error);
      res.status(500).json({error: "Failed to create demo user"});
    }
  }
);
