/**
 * Popula userDirectory a partir de users/{uid} para a busca de treino em grupo.
 *
 * Uso:
 *   node scripts/backfill-user-directory.mjs
 *
 * Requer firebase login válido (usa o refresh token do firebase-tools).
 */
import fs from "fs";
import https from "https";
import os from "os";

const PROJECT = "healthfit-30d87";
const CLIENT_ID =
  "563584335869-fgrhgmd47bqnek113k5u0ujjluhyo3vp.apps.googleusercontent.com";
const CLIENT_SECRET = "FAKESECRET_u3v4w5x6y7z8a9b0c1d2";

function request(method, url, headers = {}, body = null) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const payload = body == null ? null : typeof body === "string" ? body : JSON.stringify(body);
    const req = https.request(
      {
        hostname: u.hostname,
        path: u.pathname + u.search,
        method,
        headers: {
          ...headers,
          ...(payload
            ? {
                "Content-Type":
                  headers["Content-Type"] || "application/json",
                "Content-Length": Buffer.byteLength(payload),
              }
            : {}),
        },
      },
      (res) => {
        let buf = "";
        res.on("data", (c) => (buf += c));
        res.on("end", () => {
          let json = null;
          try {
            json = JSON.parse(buf);
          } catch {
            /* ignore */
          }
          resolve({ status: res.statusCode, json, raw: buf });
        });
      }
    );
    req.on("error", reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function searchable(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .trim()
    .toLowerCase();
}

function field(fields, key) {
  const f = fields?.[key];
  if (!f) return "";
  if (f.stringValue != null) return f.stringValue;
  return "";
}

async function main() {
  const cfgPath = os.homedir() + "/.config/configstore/firebase-tools.json";
  const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
  const refresh = cfg.tokens?.refresh_token;
  if (!refresh) {
    console.error("Sem refresh_token. Rode: firebase login --reauth");
    process.exit(1);
  }

  let access = cfg.tokens?.access_token;
  const expiresAt = Number(cfg.tokens?.expires_at || 0);
  if (!access || Date.now() > expiresAt - 60_000) {
    const tokenRes = await request(
      "POST",
      "https://oauth2.googleapis.com/token",
      { "Content-Type": "application/x-www-form-urlencoded" },
      new URLSearchParams({
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        refresh_token: refresh,
        grant_type: "refresh_token",
      }).toString()
    );
    access = tokenRes.json?.access_token;
    if (!access) {
      console.error(
        "Falha ao renovar token. Rode: firebase login --reauth\n",
        tokenRes.status,
        tokenRes.json
      );
      process.exit(1);
    }
  }

  const base = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
  const auth = { Authorization: `Bearer ${access}` };

  const usersRes = await request("GET", `${base}/users?pageSize=200`, auth);
  if (usersRes.status !== 200) {
    console.error("Erro ao listar users:", usersRes.status, usersRes.raw.slice(0, 400));
    process.exit(1);
  }

  const docs = usersRes.json?.documents || [];
  console.log(`users encontrados: ${docs.length}`);

  let written = 0;
  for (const doc of docs) {
    const uid = doc.name.split("/").pop();
    const fields = doc.fields || {};
    const name = field(fields, "name");
    const displayName = field(fields, "displayName");
    const email = field(fields, "email").toLowerCase();
    const countryCode = field(fields, "countryCode");
    const photoURL = field(fields, "photoURL");

    if (!name && !displayName && !email) {
      console.log(` skip ${uid} (sem nome/email)`);
      continue;
    }

    const body = {
      fields: {
        uid: { stringValue: uid },
        name: { stringValue: name },
        displayName: { stringValue: displayName },
        email: { stringValue: email },
        nameLower: { stringValue: searchable(name) },
        displayNameLower: { stringValue: searchable(displayName) },
        emailLower: { stringValue: searchable(email) },
        countryCode: { stringValue: countryCode || "" },
        updatedAt: { timestampValue: new Date().toISOString() },
      },
    };
    if (photoURL) {
      body.fields.photoURL = { stringValue: photoURL };
    }

    const patch = await request(
      "PATCH",
      `${base}/userDirectory/${uid}?updateMask.fieldPaths=uid&updateMask.fieldPaths=name&updateMask.fieldPaths=displayName&updateMask.fieldPaths=email&updateMask.fieldPaths=nameLower&updateMask.fieldPaths=displayNameLower&updateMask.fieldPaths=emailLower&updateMask.fieldPaths=countryCode&updateMask.fieldPaths=updatedAt${photoURL ? "&updateMask.fieldPaths=photoURL" : ""}`,
      auth,
      body
    );
    if (patch.status >= 200 && patch.status < 300) {
      written += 1;
      console.log(` ok ${uid} → ${displayName || name || email}`);
    } else {
      console.log(` fail ${uid}:`, patch.status, patch.raw.slice(0, 200));
    }
  }

  const dirRes = await request("GET", `${base}/userDirectory?pageSize=200`, auth);
  const dirCount = (dirRes.json?.documents || []).length;
  console.log(`\nPronto. Escritos: ${written}. userDirectory agora tem ${dirCount} doc(s).`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
