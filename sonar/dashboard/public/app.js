const $ = (id) => document.getElementById(id);

const METRIC_META = [
  { key: "vulnerabilities", label: "Vulnerabilidades", badAbove: 0 },
  { key: "bugs", label: "Bugs", badAbove: 0 },
  { key: "security_hotspots", label: "Security hotspots", warnAbove: 0 },
  { key: "code_smells", label: "Code smells", warnAbove: 50 },
  { key: "ncloc", label: "Linhas (ncloc)" },
  { key: "duplicated_lines_density", label: "Duplicação %", warnAbove: 3, suffix: "%" },
  { key: "coverage", label: "Cobertura %", suffix: "%" },
  { key: "security_rating", label: "Security rating", rating: true },
  { key: "reliability_rating", label: "Reliability rating", rating: true },
  { key: "sqale_rating", label: "Maintainability", rating: true },
];

function ratingLetter(v) {
  const map = { "1.0": "A", "2.0": "B", "3.0": "C", "4.0": "D", "5.0": "E" };
  return map[String(v)] || v || "—";
}

function toneFor(meta, value) {
  if (value == null || value === "") return "";
  const n = Number(value);
  if (meta.rating) {
    if (n <= 1) return "ok";
    if (n <= 2) return "warn";
    return "bad";
  }
  if (meta.badAbove != null && n > meta.badAbove) return "bad";
  if (meta.warnAbove != null && n > meta.warnAbove) return "warn";
  if (meta.badAbove === 0 && n === 0) return "ok";
  return "";
}

function measureMap(payload) {
  const out = {};
  const measures = payload?.component?.measures || [];
  for (const m of measures) out[m.metric] = m.value;
  return out;
}

async function loadHealth() {
  const r = await fetch("/api/health");
  const j = await r.json();
  const st = j.sonar?.status || "DOWN";
  const el = $("sonarStatus");
  el.textContent = st;
  el.className = "big " + (st === "UP" ? "ok" : "bad");
  $("sonarMeta").textContent = j.sonar?.version
    ? `v${j.sonar.version} · ${j.sonarUrl}`
    : j.sonar?.error || j.sonarUrl;
  $("projectKey").textContent = j.projectKey || "healthfit";
  $("openSonar").href = j.sonarUrl || "http://localhost:9000";
}

async function loadGate() {
  const r = await fetch("/api/qualitygate");
  if (!r.ok) {
    $("gateStatus").textContent = "Sem análise";
    $("gateStatus").className = "big warn";
    $("gateMeta").textContent = "Rode ./sonar/scripts/scan.sh após o Sonar subir.";
    return;
  }
  const j = await r.json();
  const status = j.projectStatus?.status || "NONE";
  const el = $("gateStatus");
  el.textContent = status;
  el.className = "big " + (status === "OK" ? "ok" : status === "ERROR" ? "bad" : "warn");
  const failed = (j.projectStatus?.conditions || []).filter((c) => c.status === "ERROR");
  $("gateMeta").textContent = failed.length
    ? `${failed.length} condição(ões) falharam`
    : "Quality Gate avaliado";
}

async function loadMeasures() {
  const r = await fetch("/api/measures");
  const host = $("metrics");
  if (!r.ok) {
    host.innerHTML = `<article class="card metric"><p class="value warn">—</p><p class="label">Sem medidas ainda. Execute o scanner.</p></article>`;
    return;
  }
  const map = measureMap(await r.json());
  host.innerHTML = METRIC_META.map((meta) => {
    const raw = map[meta.key];
    const display = meta.rating ? ratingLetter(raw) : raw == null ? "—" : `${raw}${meta.suffix || ""}`;
    const tone = toneFor(meta, raw);
    return `<article class="card metric"><p class="value ${tone}">${display}</p><p class="label">${meta.label}</p></article>`;
  }).join("");
}

async function loadIssues() {
  const body = $("issuesBody");
  const r = await fetch("/api/issues");
  if (!r.ok) {
    body.innerHTML = `<tr><td colspan="4" class="muted">Sem issues ou projeto ainda não analisado.</td></tr>`;
    return;
  }
  const j = await r.json();
  const issues = j.issues || [];
  if (!issues.length) {
    body.innerHTML = `<tr><td colspan="4" class="muted">Nenhum issue prioritário — ótimo sinal.</td></tr>`;
    return;
  }
  body.innerHTML = issues
    .map((issue) => {
      const file = (issue.component || "").split(":").pop() || "—";
      return `<tr>
        <td><span class="sev ${issue.severity}">${issue.severity}</span></td>
        <td>${issue.type}</td>
        <td>${escapeHtml(issue.message || "")}</td>
        <td class="file">${escapeHtml(file)}${issue.line ? `:${issue.line}` : ""}</td>
      </tr>`;
    })
    .join("");
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

async function refresh() {
  $("refreshBtn").disabled = true;
  try {
    await loadHealth();
    await Promise.all([loadGate(), loadMeasures(), loadIssues()]);
  } catch (e) {
    console.error(e);
  } finally {
    $("refreshBtn").disabled = false;
  }
}

$("refreshBtn").addEventListener("click", refresh);
refresh();
setInterval(refresh, 30000);
