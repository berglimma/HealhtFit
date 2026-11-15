#!/usr/bin/env node
"use strict";

/**
 * Concede cortesia Completo 90 dias somente para a allowlist especial.
 *
 * Uso (na pasta functions):
 *   node scripts/grant-special-courtesy-90d.cjs
 *
 * Credencial: functions/serviceAccountKey.json ou GOOGLE_APPLICATION_CREDENTIALS / ADC.
 */

const path = require("path");
const {spawnSync} = require("child_process");

const EMAILS = [
  "berg.limma@gmail.com",
  "cristianeribeiiro14@gmail.com",
];

const script = path.join(__dirname, "grant-courtesy-by-email.cjs");
const result = spawnSync(
  process.execPath,
  [
    script,
    "--emails",
    EMAILS.join(","),
    "--plan",
    "complete",
    "--days",
    "90",
    "--code",
    "ADMIN-SPECIAL-COMPLETE-90D",
  ],
  {stdio: "inherit", env: process.env}
);

process.exit(result.status == null ? 1 : result.status);
