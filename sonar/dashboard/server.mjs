#!/usr/bin/env node
/**
 * Portal local HealthFit × SonarQube
 * http://localhost:9040
 *
 * Proxies SonarQube API (default http://localhost:9000) and serves the UI.
 */
import http from "http";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(__dirname, "public");
const PORT = Number(process.env.SONAR_DASHBOARD_PORT || 9040);
const SONAR_URL = (process.env.SONAR_HOST_URL || "http://localhost:9000").replace(/\/$/, "");
const PROJECT_KEY = process.env.SONAR_PROJECT_KEY || "healthfit";
const AUTH =
  process.env.SONAR_TOKEN
    ? Buffer.from(`${process.env.SONAR_TOKEN}:`).toString("base64")
    : Buffer.from(
        `${process.env.SONAR_USER || "admin"}:${process.env.SONAR_PASSWORD || "admin"}`
      ).toString("base64");

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

function send(res, status, body, type = "text/plain; charset=utf-8") {
  res.writeHead(status, {
    "Content-Type": type,
    "Cache-Control": "no-store",
  });
  res.end(body);
}

function sonarFetch(apiPath) {
  return new Promise((resolve, reject) => {
    const url = new URL(apiPath, SONAR_URL);
    const req = http.request(
      url,
      {
        method: "GET",
        headers: {
          Authorization: `Basic ${AUTH}`,
          Accept: "application/json",
        },
        timeout: 15000,
      },
      (r) => {
        let buf = "";
        r.on("data", (c) => (buf += c));
        r.on("end", () => {
          resolve({ status: r.statusCode || 0, body: buf, contentType: r.headers["content-type"] });
        });
      }
    );
    req.on("error", reject);
    req.on("timeout", () => {
      req.destroy();
      reject(new Error("SonarQube timeout"));
    });
    req.end();
  });
}

async function handleApi(req, res, url) {
  if (url.pathname === "/api/health") {
    let sonar = { status: "DOWN", version: null };
    try {
      const r = await sonarFetch("/api/system/status");
      const j = JSON.parse(r.body);
      sonar = { status: j.status || "UNKNOWN", version: j.version || null };
    } catch (e) {
      sonar = { status: "DOWN", error: String(e.message || e) };
    }
    return send(
      res,
      200,
      JSON.stringify({
        ok: true,
        projectKey: PROJECT_KEY,
        sonarUrl: SONAR_URL,
        sonar,
        dashboard: `http://localhost:${PORT}`,
      }),
      "application/json; charset=utf-8"
    );
  }

  if (url.pathname === "/api/measures") {
    try {
      const metricKeys = [
        "alert_status",
        "bugs",
        "vulnerabilities",
        "security_hotspots",
        "code_smells",
        "coverage",
        "duplicated_lines_density",
        "ncloc",
        "sqale_rating",
        "reliability_rating",
        "security_rating",
        "security_review_rating",
      ].join(",");
      const r = await sonarFetch(
        `/api/measures/component?component=${encodeURIComponent(PROJECT_KEY)}&metricKeys=${metricKeys}`
      );
      return send(res, r.status, r.body, "application/json; charset=utf-8");
    } catch (e) {
      return send(
        res,
        502,
        JSON.stringify({ error: String(e.message || e) }),
        "application/json; charset=utf-8"
      );
    }
  }

  if (url.pathname === "/api/issues") {
    try {
      const severities = url.searchParams.get("severities") || "BLOCKER,CRITICAL,MAJOR";
      const types = url.searchParams.get("types") || "VULNERABILITY,BUG,CODE_SMELL,SECURITY_HOTSPOT";
      const r = await sonarFetch(
        `/api/issues/search?componentKeys=${encodeURIComponent(PROJECT_KEY)}&severities=${severities}&types=${types}&ps=50&s=SEVERITY`
      );
      return send(res, r.status, r.body, "application/json; charset=utf-8");
    } catch (e) {
      return send(
        res,
        502,
        JSON.stringify({ error: String(e.message || e) }),
        "application/json; charset=utf-8"
      );
    }
  }

  if (url.pathname === "/api/qualitygate") {
    try {
      const r = await sonarFetch(
        `/api/qualitygates/project_status?projectKey=${encodeURIComponent(PROJECT_KEY)}`
      );
      return send(res, r.status, r.body, "application/json; charset=utf-8");
    } catch (e) {
      return send(
        res,
        502,
        JSON.stringify({ error: String(e.message || e) }),
        "application/json; charset=utf-8"
      );
    }
  }

  return send(res, 404, JSON.stringify({ error: "Not found" }), "application/json; charset=utf-8");
}

function serveStatic(req, res, url) {
  let rel = url.pathname === "/" ? "/index.html" : url.pathname;
  rel = path.normalize(rel).replace(/^(\.\.[/\\])+/, "");
  const file = path.join(PUBLIC, rel);
  if (!file.startsWith(PUBLIC)) {
    return send(res, 403, "Forbidden");
  }
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    return send(res, 404, "Not found");
  }
  const ext = path.extname(file);
  send(res, 200, fs.readFileSync(file), MIME[ext] || "application/octet-stream");
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || "/", `http://localhost:${PORT}`);
    if (url.pathname.startsWith("/api/")) {
      await handleApi(req, res, url);
      return;
    }
    serveStatic(req, res, url);
  } catch (e) {
    send(res, 500, String(e.message || e));
  }
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`HealthFit Sonar portal → http://127.0.0.1:${PORT}`);
  console.log(`SonarQube API         → ${SONAR_URL}`);
  console.log(`Project key           → ${PROJECT_KEY}`);
});

process.on("uncaughtException", (err) => {
  console.error("uncaughtException", err);
});
process.on("unhandledRejection", (err) => {
  console.error("unhandledRejection", err);
});