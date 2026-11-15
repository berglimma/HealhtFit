#!/usr/bin/env node
"use strict";

/**
 * Concede cortesia direto em courtesyGrants/{uid} (sem resgate no app).
 * O app lê o grant em qualquer build; só a UI de código é TestFlight/Debug.
 *
 * Uso (na pasta functions):
 *   node scripts/grant-courtesy-by-email.cjs \
 *     --emails a@x.com,b@y.com --plan complete --days 30
 *
 * Credencial: functions/serviceAccountKey.json ou GOOGLE_APPLICATION_CREDENTIALS / ADC.
 */

const fs = require("fs");
const path = require("path");

const PROJECT_ID = "healthfit-30d87";
const VALID_PLANS = new Set(["basic", "fit", "ai", "complete"]);

function argValue(flag, fallback = "") {
  const idx = process.argv.indexOf(flag);
  if (idx >= 0 && process.argv[idx + 1]) return process.argv[idx + 1];
  return fallback;
}

function initializeFirebaseAdmin() {
  const {initializeApp, applicationDefault, cert} = require("firebase-admin/app");
  const serviceAccountPath =
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.join(__dirname, "..", "serviceAccountKey.json");

  if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"));
    initializeApp({
      credential: cert(serviceAccount),
      projectId: PROJECT_ID,
    });
    console.log(`Firebase Admin: service account (${path.basename(serviceAccountPath)})`);
    return;
  }

  initializeApp({
    credential: applicationDefault(),
    projectId: PROJECT_ID,
  });
  console.log("Firebase Admin: Application Default Credentials");
}

async function main() {
  const emails = argValue("--emails")
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  const plan = argValue("--plan", "complete").toLowerCase();
  const durationDays = Number(argValue("--days", "30")) || 30;
  const code = argValue("--code", "ADMIN-DIRECT-COMPLETE-30D");

  if (emails.length === 0) {
    console.error("Informe --emails a@x.com,b@y.com");
    process.exit(1);
  }
  if (!VALID_PLANS.has(plan)) {
    console.error(`Plano inválido: ${plan}`);
    process.exit(1);
  }

  initializeFirebaseAdmin();
  const {getAuth} = require("firebase-admin/auth");
  const {getFirestore, Timestamp} = require("firebase-admin/firestore");
  const auth = getAuth();
  const db = getFirestore();
  const now = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(
    Date.now() + durationDays * 24 * 60 * 60 * 1000
  );

  const results = [];
  for (const email of emails) {
    try {
      const user = await auth.getUserByEmail(email);
      const grantRef = db.collection("courtesyGrants").doc(user.uid);
      const existing = await grantRef.get();
      await grantRef.set({
        plan,
        durationDays,
        code,
        redeemedAt: now,
        expiresAt,
      });
      results.push({
        email,
        uid: user.uid,
        ok: true,
        plan,
        durationDays,
        expiresAt: expiresAt.toDate().toISOString(),
        previousPlan: existing.exists ? existing.data()?.plan : null,
      });
    } catch (error) {
      const codeName = error && error.code;
      results.push({
        email,
        ok: false,
        error: codeName === "auth/user-not-found" ? "user-not-found" : String(error.message || error),
      });
    }
  }

  console.log(JSON.stringify({ok: results.every((r) => r.ok), results}, null, 2));
  if (!results.every((r) => r.ok)) process.exit(1);
}

main().catch((error) => {
  const message = String(error && error.message ? error.message : error);
  if (message.includes("default credentials") || message.includes("Could not load the default credentials")) {
    console.error("Falta credencial do Firebase Admin.");
    console.error("Baixe a service account e salve como functions/serviceAccountKey.json");
    console.error("  https://console.firebase.google.com/project/healthfit-30d87/settings/serviceaccounts/adminsdk");
  } else {
    console.error(error);
  }
  process.exit(1);
});
