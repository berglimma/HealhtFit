#!/usr/bin/env node
"use strict";

/**
 * Gera 40 vouchers de 30 dias por plano pago e grava no Firestore.
 *
 * Uso (na pasta functions, com ADC / firebase login):
 *   node scripts/seed-courtesy-vouchers.cjs --deploy   # via Cloud Function (firebase login)
 *
 * Idempotente: se o lote launch-v1-30d já existir, só reimprime os códigos.
 */

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const {initializeApp, applicationDefault, cert} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const PROJECT_ID = "healthfit-30d87";
const BATCH_ID = "launch-v2-40x-30d";
const DURATION_DAYS = 30;
const CODES_PER_PLAN = 40;
const COURTESY_SEED_KEY = "healthfit-courtesy-seed-v2-40x";
const FUNCTION_NAME = "seedCourtesyVouchers";
const FUNCTION_REGION = "southamerica-east1";
const ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

const PLANS = [
  {id: "basic", prefix: "BASIC", label: "Básico"},
  {id: "fit", prefix: "FIT", label: "Fit"},
  {id: "ai", prefix: "AI", label: "IA Plus"},
  {id: "complete", prefix: "COMPLETE", label: "Completo"},
];

function randomSuffix(length = 6) {
  const bytes = crypto.randomBytes(length);
  let out = "";
  for (let i = 0; i < length; i++) {
    out += ALPHABET[bytes[i] % ALPHABET.length];
  }
  return out;
}

function makeCode(prefix) {
  return `HF-${prefix}-${randomSuffix()}`;
}

function repoRoot() {
  return path.resolve(__dirname, "..", "..");
}

function writeLocalLists(grouped) {
  const dir = path.join(repoRoot(), "HealthFit", "AppStore");
  fs.mkdirSync(dir, {recursive: true});

  const lines = [
    "# Vouchers de cortesia HealthFit — 30 dias",
    "",
    "Uso interno. **Não publique** este arquivo (está no .gitignore).",
    "Cada código é de **uso único**. Resgate: Perfil → Meu plano → Tenho um código de cortesia.",
    "",
    `Lote: ${BATCH_ID}`,
    `Validade do brinde após o resgate: ${DURATION_DAYS} dias`,
    `Gerado em: ${new Date().toISOString()}`,
    "",
  ];

  const csv = ["plan,code,durationDays,batchId"];

  for (const plan of PLANS) {
    const codes = grouped[plan.id] || [];
    lines.push(`## ${plan.label} (${plan.id}) — ${codes.length} códigos`);
    lines.push("");
    for (const code of codes) {
      lines.push(`- \`${code}\``);
      csv.push(`${plan.id},${code},${DURATION_DAYS},${BATCH_ID}`);
    }
    lines.push("");
  }

  const mdPath = path.join(dir, "courtesy-vouchers.local.md");
  const csvPath = path.join(dir, "courtesy-vouchers.local.csv");
  fs.writeFileSync(mdPath, lines.join("\n"), "utf8");
  fs.writeFileSync(csvPath, csv.join("\n") + "\n", "utf8");
  return {mdPath, csvPath};
}

function generateNewGrouped() {
  const grouped = Object.fromEntries(PLANS.map((p) => [p.id, []]));
  const used = new Set();
  for (const plan of PLANS) {
    while (grouped[plan.id].length < CODES_PER_PLAN) {
      const code = makeCode(plan.prefix);
      if (used.has(code)) continue;
      used.add(code);
      grouped[plan.id].push(code);
    }
  }
  return grouped;
}

function docsFromGrouped(grouped) {
  const docs = [];
  for (const plan of PLANS) {
    for (const code of grouped[plan.id] || []) {
      docs.push({
        code,
        plan: plan.id,
        durationDays: DURATION_DAYS,
        batchId: BATCH_ID,
        redeemedBy: null,
        redeemedAt: null,
      });
    }
  }
  return docs;
}

function initializeFirebaseAdmin() {
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

const {execSync} = require("child_process");

async function deployViaCloudFunction(csvPath) {
  const vouchers = parseLocalCsv(csvPath);
  if (vouchers.length === 0) {
    throw new Error(`CSV vazio ou ausente: ${csvPath}`);
  }

  console.log(`==> Build + deploy ${FUNCTION_NAME} (${vouchers.length} vouchers)...`);
  execSync("npm run build", {stdio: "inherit", cwd: path.join(__dirname, "..")});
  try {
    execSync(
      `firebase deploy --only functions:${FUNCTION_NAME} --project ${PROJECT_ID} --non-interactive`,
      {stdio: "inherit", cwd: path.join(repoRoot())}
    );
  } catch (error) {
    // Deploy can succeed but exit 1 on artifact cleanup policy prompt in new regions.
    console.warn("Deploy command exited non-zero; continuing if function URL responds...");
  }

  const url = `https://${FUNCTION_REGION}-${PROJECT_ID}.cloudfunctions.net/${FUNCTION_NAME}`;
  console.log(`==> POST ${url}`);

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-healthfit-seed-key": COURTESY_SEED_KEY,
    },
    body: JSON.stringify({vouchers}),
  });

  const text = await response.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = {raw: text};
  }

  if (!response.ok) {
    throw new Error(`Seed HTTP ${response.status}: ${text}`);
  }

  console.log(`OK: ${JSON.stringify(body)}`);
  return body;
}

async function main() {
  const localOnly = process.argv.includes("--local-only");
  const deploy = process.argv.includes("--deploy");
  const dir = path.join(repoRoot(), "HealthFit", "AppStore");
  const csvPath = path.join(dir, "courtesy-vouchers.local.csv");

  if (deploy) {
    await deployViaCloudFunction(csvPath);
    return;
  }

  if (localOnly) {
    if (fs.existsSync(csvPath) && parseLocalCsv(csvPath).length > 0) {
      console.log("CSV local já existe — não regenerar. Apague o arquivo para criar outro lote.");
      console.log(csvPath);
      return;
    }
    const grouped = generateNewGrouped();
    const paths = writeLocalLists(grouped);
    console.log(`Gerados ${CODES_PER_PLAN * PLANS.length} códigos locais (sem Firestore).`);
    console.log(paths.mdPath);
    console.log(paths.csvPath);
    return;
  }

  initializeFirebaseAdmin();
  const db = getFirestore();

  const existingSnap = await db
    .collection("courtesyVouchers")
    .where("batchId", "==", BATCH_ID)
    .get();

  const grouped = Object.fromEntries(PLANS.map((p) => [p.id, []]));

  if (!existingSnap.empty) {
    for (const doc of existingSnap.docs) {
      const plan = doc.data().plan;
      if (grouped[plan]) grouped[plan].push(doc.id);
    }
    for (const plan of PLANS) {
      grouped[plan.id].sort();
    }
    const paths = writeLocalLists(grouped);
    console.log(
      `Lote ${BATCH_ID} já existe (${existingSnap.size} códigos). Listas atualizadas.`
    );
    console.log(paths.mdPath);
    console.log(paths.csvPath);
    return;
  }

  if (fs.existsSync(csvPath)) {
    const parsed = parseLocalCsv(csvPath);
    if (parsed.length > 0) {
      await commitVouchers(db, parsed);
      const fromFile = Object.fromEntries(PLANS.map((p) => [p.id, []]));
      for (const item of parsed) {
        if (fromFile[item.plan]) fromFile[item.plan].push(item.code);
      }
      const paths = writeLocalLists(fromFile);
      console.log(`Enviados ${parsed.length} códigos do CSV local para o Firestore.`);
      console.log(paths.mdPath);
      return;
    }
  }

  const fresh = generateNewGrouped();
  const docs = docsFromGrouped(fresh);
  writeLocalLists(fresh);
  await commitVouchers(db, docs);
  console.log(`Gravados ${docs.length} vouchers no Firestore (${PROJECT_ID}).`);
}

function parseLocalCsv(csvPath) {
  const text = fs.readFileSync(csvPath, "utf8").trim();
  const lines = text.split(/\r?\n/).slice(1);
  const docs = [];
  for (const line of lines) {
    const [plan, code] = line.split(",");
    if (!plan || !code) continue;
    docs.push({
      code: code.trim(),
      plan: plan.trim(),
      durationDays: DURATION_DAYS,
      batchId: BATCH_ID,
      redeemedBy: null,
      redeemedAt: null,
    });
  }
  return docs;
}

async function commitVouchers(db, docs) {
  const batch = db.batch();
  const now = FieldValue.serverTimestamp();
  for (const item of docs) {
    const ref = db.collection("courtesyVouchers").doc(item.code);
    batch.set(ref, {
      ...item,
      createdAt: now,
    });
  }
  await batch.commit();
}

main().catch((error) => {
  const message = String(error && error.message ? error.message : error);
  if (message.includes("default credentials") || message.includes("Could not load the default credentials")) {
    console.error("Falta credencial do Firebase.");
    console.error("");
    console.error("Use o deploy via Firebase CLI (sem gcloud):");
    console.error("  cd functions && npm run seed:courtesy:deploy");
    console.error("");
    console.error("Ou baixe uma service account em:");
    console.error("  https://console.firebase.google.com/project/healthfit-30d87/settings/serviceaccounts/adminsdk");
    console.error("  Salve como functions/serviceAccountKey.json e rode npm run seed:courtesy");
  } else {
    console.error(error);
  }
  process.exit(1);
});
