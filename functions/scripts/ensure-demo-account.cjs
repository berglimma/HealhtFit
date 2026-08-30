#!/usr/bin/env node
/**
 * Cria ou atualiza a conta demo de App Review no Firebase Auth.
 * Uso: npm run ensure:demo-account
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
    headers: {"x-healthfit-seed-key": COURTESY_SEED_KEY},
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
