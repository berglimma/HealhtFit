#!/usr/bin/env node
/**
 * Cria ou atualiza a conta demo de App Review no Firebase Auth.
 * Uso: DEMO_REVIEW_PASSWORD='...' npm run ensure:demo-account
 */
const {execSync} = require("child_process");
const path = require("path");

const PROJECT_ID = "healthfit-30d87";
const FUNCTION_REGION = "southamerica-east1";
const FUNCTION_NAME = "ensureAppReviewDemoAccount";
const COURTESY_SEED_KEY = "healthfit-courtesy-seed-v2-40x";

function repoRoot() {
  return path.resolve(__dirname, "..", "..");
}

async function main() {
  const password = (process.env.DEMO_REVIEW_PASSWORD || "").trim();
  if (password.length < 8) {
    console.error("Defina DEMO_REVIEW_PASSWORD (mín. 8) no ambiente — não versionar no git.");
    process.exit(1);
  }

  console.log(`==> Build + deploy ${FUNCTION_NAME}...`);
  execSync("npm run build", {stdio: "inherit", cwd: path.join(__dirname, "..")});
  try {
    execSync(
      `firebase deploy --only functions:${FUNCTION_NAME} --project ${PROJECT_ID} --non-interactive`,
      {stdio: "inherit", cwd: repoRoot()}
    );
  } catch {
    console.warn("Deploy exited non-zero; continuing if function URL responds...");
  }

  const url = `https://${FUNCTION_REGION}-${PROJECT_ID}.cloudfunctions.net/${FUNCTION_NAME}`;
  console.log(`==> POST ${url}`);

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-healthfit-seed-key": COURTESY_SEED_KEY,
    },
    body: JSON.stringify({password}),
  });
  const text = await response.text();
  console.log(`Status: ${response.status}`);
  console.log(text);
  if (!response.ok) process.exit(1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
