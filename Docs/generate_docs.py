#!/usr/bin/env python3
"""Gera documentação profissional HealthFit (HTML estilo Figma + PDF)."""

from __future__ import annotations

import json
import subprocess
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FIGMA_DIR = ROOT / "figma"
OUT_HTML = ROOT / "HealthFit_Documentacao_Completa.html"
OUT_PDF = ROOT / "HealthFit_Documentacao_Completa.pdf"
FIGMA_HTML = FIGMA_DIR / "HealthFit_Screen_Map_Figma.html"
FIGMA_JSON = FIGMA_DIR / "figma_design_tokens_and_screens.json"
FIGMA_MD = FIGMA_DIR / "FIGMA_IMPORT_GUIDE.md"

VERSION = "1.0.0"
TODAY = date.today().strftime("%d/%m/%Y")

SCREENS = [
    # id, area, title, file, purpose, actions, figma_frame
    ("auth-login", "Autenticação", "Login", "LoginView.swift",
     "Entrada do usuário não autenticado.",
     ["Entrar com e-mail/senha", "Google / Apple", "Esqueci minha senha", "Criar conta"],
     "Auth / 01 Login"),
    ("auth-register", "Autenticação", "Criar Conta", "RegisterView.swift",
     "Cadastro com perfil inicial (biotipo, objetivo, senha).",
     ["Validar senha", "Aceitar termos", "Registrar", "Social signup"],
     "Auth / 02 Criar Conta"),
    ("auth-forgot", "Autenticação", "Esqueci minha senha", "ForgotPasswordView.swift",
     "Recuperação de senha por e-mail.",
     ["Enviar link de redefinição"],
     "Auth / 03 Recuperar Senha"),
    ("welcome", "Onboarding", "Boas-vindas", "WelcomeMotivationView.swift",
     "Slides motivacionais pós-login / retorno após 24h.",
     ["Avançar slides", "Entrar no app"],
     "Onboarding / 01 Welcome"),
    ("sleep-checkin", "Onboarding", "Check-in diário (sono)", "DailyWellnessCheckInView.swift",
     "Registro de horas de sono ao abrir o app.",
     ["Ajustar horas", "Confirmar sono"],
     "Onboarding / 02 Check-in Sono"),
    ("tab-home", "Início", "Dashboard", "DashboardView.swift",
     "Visão geral: métricas HealthKit, treinos recentes, Watch.",
     ["Pull-to-refresh", "Abrir relatório semanal", "Ver desempenho"],
     "Início / 01 Dashboard"),
    ("tab-charts", "Início", "Desempenho Semanal", "HealthChartsView.swift",
     "Gráficos de treino, passos, calorias, FC e meditação.",
     ["Trocar métrica", "Interpretar tendência"],
     "Início / 02 Charts"),
    ("tab-weekly", "Início", "Relatório Semanal", "WeeklyReportView.swift",
     "Score semanal, destaques e sugestões de melhoria.",
     ["Comparar com semana anterior"],
     "Início / 03 Relatório Semanal"),
    ("workouts-hub", "Treinos", "Treinos (Hub)", "WorkoutListView.swift",
     "Hub Musculação / Cardio / Meditação.",
     ["Abrir gênero", "Abrir cardio", "Abrir meditação", "Criar ficha"],
     "Treinos / 01 Hub"),
    ("workouts-gender", "Treinos", "Hub Masculino / Feminino", "GenderWorkoutHubView.swift",
     "Fichas recomendadas e personalizadas por gênero.",
     ["Abrir ficha", "Criar personalizado"],
     "Treinos / 02 Gender Hub"),
    ("workouts-detail", "Treinos", "Detalhe da Ficha", "WorkoutDetailView.swift",
     "Lista de exercícios e início de sessão.",
     ["Iniciar treino", "Editar/Excluir", "Vision AI", "Pré-treino"],
     "Treinos / 03 Detalhe"),
    ("workouts-create", "Treinos", "Nova / Editar Ficha", "CreateWorkoutView.swift",
     "Montagem de ficha personalizada.",
     ["Escolher foco", "Adicionar exercícios", "Salvar"],
     "Treinos / 04 Criar Ficha"),
    ("workouts-active", "Treinos", "Treino Ativo", "ActiveWorkoutView.swift",
     "Sessão de musculação com descanso e Watch.",
     ["Concluir série", "Descanso", "Encerrar", "Encerrar cedo"],
     "Treinos / 05 Ativo"),
    ("workouts-summary", "Treinos", "Resumo do Treino", "WorkoutSummaryView.swift",
     "Relatório pós-sessão e envio ao personal.",
     ["Ver métricas", "Enviar e-mail"],
     "Treinos / 06 Resumo"),
    ("cardio-setup", "Cardio", "Configurar Cardio", "CardioSetupView.swift",
     "Intensidade, distância e meta calórica.",
     ["Escolher exercício", "Definir meta", "Iniciar"],
     "Cardio / 01 Setup"),
    ("cardio-active", "Cardio", "Cardio Ativo", "ActiveCardioView.swift",
     "Sessão ao vivo com progresso de kcal/distância.",
     ["Acompanhar progresso", "Encerrar"],
     "Cardio / 02 Ativo"),
    ("meditation-setup", "Meditação", "Configurar Meditação", "MeditationSetupView.swift",
     "Tópico e duração (5–20 min).",
     ["Escolher tópico", "Iniciar"],
     "Meditação / 01 Setup"),
    ("meditation-active", "Meditação", "Meditação Ativa", "ActiveMeditationView.swift",
     "Sessão guiada com prompts e countdown.",
     ["Seguir prompts", "Encerrar"],
     "Meditação / 02 Ativa"),
    ("nutrition", "Nutrição", "Nutrição", "MealPlanView.swift",
     "Plano alimentar semanal e menu personalizado.",
     ["Ajustar preferências", "Gerar plano", "Abrir compras"],
     "Nutrição / 01 Plano"),
    ("shopping", "Nutrição", "Lista de Compras", "ShoppingListView.swift",
     "Lista + catálogo + suplementos.",
     ["Marcar itens", "Adicionar item", "Relatório"],
     "Nutrição / 02 Compras"),
    ("assistant", "IAssistente", "Assistente", "HealthChatView.swift",
     "Coach por regras: dúvidas, check-ins, montar treino.",
     ["Enviar mensagem", "Sugestões", "Check-ins", "Montar treino"],
     "IAssistente / 01 Chat"),
    ("profile", "Perfil", "Perfil", "ProfileView.swift",
     "Dados, ícone de saúde, sono/água, medidas, integrações.",
     ["Editar perfil", "Registrar água/sono", "Medidas", "Logout/Excluir"],
     "Perfil / 01 Perfil"),
    ("profile-measures", "Perfil", "Comparativo de Medidas", "BodyMeasurementComparisonView.swift",
     "Deltas de medidas corporais (~30 dias).",
     ["Visualizar evolução"],
     "Perfil / 02 Comparativo"),
    ("profile-delete", "Perfil", "Excluir Conta", "DeleteAccountSheet.swift",
     "Exclusão permanente com reautenticação.",
     ["Confirmar exclusão"],
     "Perfil / 03 Excluir Conta"),
    ("vision", "Experimental", "Vision AI", "VisionWorkoutView.swift",
     "Treino assistido por câmera (experimental).",
     ["Iniciar câmera"],
     "Experimental / 01 Vision AI"),
    ("watch", "Apple Watch", "Watch Companion", "WatchContentView.swift",
     "Cronômetro e métricas sincronizadas com o iPhone.",
     ["Acompanhar sessão", "Encerrar"],
     "Watch / 01 Active"),
]


def esc(s: str) -> str:
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def phone_frame(screen: tuple) -> str:
    sid, area, title, file, purpose, actions, frame = screen
    chips = "".join(f'<li>{esc(a)}</li>' for a in actions)
    return f"""
    <article class="phone" id="{esc(sid)}" data-frame="{esc(frame)}">
      <header class="phone-status">
        <span>9:41</span><span class="dots">●●●</span>
      </header>
      <div class="phone-nav">{esc(title)}</div>
      <div class="phone-body">
        <p class="eyebrow">{esc(area)}</p>
        <h3>{esc(title)}</h3>
        <p class="purpose">{esc(purpose)}</p>
        <p class="file"><code>{esc(file)}</code></p>
        <p class="label">Ações principais</p>
        <ul>{chips}</ul>
        <p class="figma-tag">Figma: {esc(frame)}</p>
      </div>
      <footer class="phone-home"><span></span></footer>
    </article>
    """


def build_figma_html() -> str:
    frames = "\n".join(phone_frame(s) for s in SCREENS)
    areas = []
    seen = set()
    for s in SCREENS:
        if s[1] not in seen:
            seen.add(s[1])
            areas.append(s[1])
    nav = "".join(f'<a href="#{esc(a.lower().replace(" ", "-"))}">{esc(a)}</a>' for a in areas)

    # group by area
    groups = ""
    for area in areas:
        cards = "".join(phone_frame(s) for s in SCREENS if s[1] == area)
        aid = area.lower().replace(" ", "-")
        groups += f'<section class="board-section" id="{esc(aid)}"><h2>{esc(area)}</h2><div class="board">{cards}</div></section>'

    return f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>HealthFit — Mapa de Telas (estilo Figma)</title>
<style>
  :root {{
    --bg: #0b0f14;
    --panel: #121821;
    --card: #1a2330;
    --accent: #2ecc71;
    --orange: #f39c12;
    --text: #f4f7fb;
    --muted: #9aa8b8;
    --line: #2a3648;
    --phone: #0e141c;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; font-family: "SF Pro Display", "Inter", -apple-system, BlinkMacSystemFont, sans-serif;
    background: radial-gradient(1200px 600px at 10% -10%, #163024 0%, transparent 50%),
                radial-gradient(900px 500px at 100% 0%, #2a1c0a 0%, transparent 45%),
                var(--bg);
    color: var(--text);
  }}
  .topbar {{
    position: sticky; top: 0; z-index: 20;
    display: flex; gap: 16px; align-items: center; justify-content: space-between;
    padding: 14px 24px; background: rgba(11,15,20,.88); backdrop-filter: blur(12px);
    border-bottom: 1px solid var(--line);
  }}
  .brand {{ display: flex; gap: 12px; align-items: center; }}
  .logo {{
    width: 36px; height: 36px; border-radius: 10px;
    background: linear-gradient(135deg, var(--accent), var(--orange));
  }}
  .brand h1 {{ margin: 0; font-size: 16px; }}
  .brand p {{ margin: 0; color: var(--muted); font-size: 12px; }}
  .topnav {{ display: flex; flex-wrap: wrap; gap: 8px; }}
  .topnav a {{
    color: var(--muted); text-decoration: none; font-size: 12px;
    padding: 6px 10px; border: 1px solid var(--line); border-radius: 999px;
  }}
  .topnav a:hover {{ color: var(--text); border-color: var(--accent); }}
  .hero {{
    padding: 40px 24px 20px; max-width: 1200px; margin: 0 auto;
  }}
  .hero h2 {{ margin: 0 0 8px; font-size: 34px; letter-spacing: -0.03em; }}
  .hero p {{ color: var(--muted); max-width: 720px; line-height: 1.55; }}
  .tokens {{
    display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
    gap: 10px; margin-top: 22px;
  }}
  .token {{
    background: var(--panel); border: 1px solid var(--line); border-radius: 12px; padding: 12px;
  }}
  .swatch {{ height: 28px; border-radius: 8px; margin-bottom: 8px; }}
  .token code {{ font-size: 11px; color: var(--muted); }}
  .flow {{
    margin: 16px 24px 32px; padding: 18px; border-radius: 16px;
    background: var(--panel); border: 1px solid var(--line); max-width: 1200px;
  }}
  .flow pre {{
    margin: 0; white-space: pre-wrap; color: #cfead9; font-size: 12px; line-height: 1.45;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  }}
  .board-section {{ padding: 8px 24px 40px; }}
  .board-section h2 {{
    font-size: 20px; margin: 0 0 16px; padding-bottom: 8px;
    border-bottom: 1px solid var(--line); color: var(--accent);
  }}
  .board {{
    display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: 20px;
  }}
  .phone {{
    background: var(--phone); border: 1px solid #314156; border-radius: 28px;
    overflow: hidden; box-shadow: 0 18px 40px rgba(0,0,0,.35);
    min-height: 420px; display: flex; flex-direction: column;
  }}
  .phone-status, .phone-nav, .phone-home {{
    padding: 10px 16px; background: #0a1018;
  }}
  .phone-status {{
    display: flex; justify-content: space-between; font-size: 11px; color: var(--muted);
  }}
  .phone-nav {{
    text-align: center; font-weight: 650; font-size: 14px;
    border-top: 1px solid #1d2838; border-bottom: 1px solid #1d2838;
  }}
  .phone-body {{ padding: 16px; flex: 1; }}
  .eyebrow {{
    margin: 0 0 6px; text-transform: uppercase; letter-spacing: .08em;
    font-size: 10px; color: var(--orange);
  }}
  .phone-body h3 {{ margin: 0 0 8px; font-size: 18px; }}
  .purpose {{ color: var(--muted); font-size: 13px; line-height: 1.45; margin: 0 0 10px; }}
  .file code {{
    font-size: 11px; color: #8fd6a8; background: #132018; padding: 2px 6px; border-radius: 6px;
  }}
  .label {{ margin: 14px 0 6px; font-size: 11px; color: var(--muted); text-transform: uppercase; }}
  .phone-body ul {{ margin: 0; padding-left: 16px; color: var(--text); font-size: 12.5px; }}
  .phone-body li {{ margin: 4px 0; }}
  .figma-tag {{
    margin-top: 14px; font-size: 11px; color: #7eb6ff;
    border: 1px dashed #335a86; border-radius: 8px; padding: 8px;
  }}
  .phone-home {{ display: flex; justify-content: center; }}
  .phone-home span {{
    width: 96px; height: 4px; border-radius: 999px; background: #3a4a5f;
  }}
  footer.doc-foot {{
    padding: 28px 24px 48px; color: var(--muted); font-size: 12px; text-align: center;
  }}
  @media print {{
    .topbar {{ position: static; }}
    .phone {{ break-inside: avoid; }}
  }}
</style>
</head>
<body>
  <div class="topbar">
    <div class="brand">
      <div class="logo"></div>
      <div>
        <h1>HealthFit — Screen Map</h1>
        <p>Documentação visual estilo Figma · v{VERSION} · {TODAY}</p>
      </div>
    </div>
    <nav class="topnav">{nav}</nav>
  </div>

  <section class="hero">
    <h2>Mapa de telas do produto</h2>
    <p>
      Catálogo visual das telas do HealthFit (iOS + watchOS), organizado por área de produto.
      Cada card representa um frame Figma sugerido (<code>Área / NN Nome</code>), com propósito,
      arquivo SwiftUI e ações principais. Tokens de design alinhados ao <code>AppTheme</code>.
    </p>
    <div class="tokens">
      <div class="token"><div class="swatch" style="background:#2ecc71"></div><strong>AccentGreen</strong><br/><code>#2ECC71</code></div>
      <div class="token"><div class="swatch" style="background:#f39c12"></div><strong>AccentOrange</strong><br/><code>#F39C12</code></div>
      <div class="token"><div class="swatch" style="background:#0b0f14"></div><strong>Background</strong><br/><code>#0B0F14</code></div>
      <div class="token"><div class="swatch" style="background:#1a2330"></div><strong>CardBackground</strong><br/><code>#1A2330</code></div>
      <div class="token"><div class="swatch" style="background:#ffffff"></div><strong>Text Primary</strong><br/><code>#FFFFFF</code></div>
      <div class="token"><div class="swatch" style="background:#9aa8b8"></div><strong>Text Secondary</strong><br/><code>65% white</code></div>
    </div>
  </section>

  <section class="flow">
    <h3 style="margin:0 0 10px;font-size:14px;color:var(--accent)">Fluxo de navegação (Figma → FigJam / Prototype)</h3>
    <pre>Login → (Register | Forgot Password)
  → WelcomeMotivationView
  → Check-in Sono (se necessário)
  → MainTabView
       ├─ Início → Dashboard → Charts / Relatório Semanal
       ├─ Treinos → Hub → (Musculação | Cardio | Meditação)
       │              → Detalhe → Ativo → Resumo
       ├─ Nutrição → Plano → Lista de Compras
       ├─ IAssistente → Chat / Check-ins / Montar treino
       └─ Perfil → Medidas / Excluir Conta
Apple Watch ← WatchConnectivity ← Sessão ativa no iPhone</pre>
  </section>

  {groups}

  <footer class="doc-foot">
    HealthFit · BERG / LUAN · Documento gerado automaticamente em {TODAY}<br/>
    Use este mapa como referência para criar frames no Figma com a nomenclatura indicada em cada card.
  </footer>
</body>
</html>
"""


def build_full_html() -> str:
    screen_rows = "".join(
        f"""<tr>
          <td>{esc(s[1])}</td>
          <td><strong>{esc(s[2])}</strong><br/><span class="muted">{esc(s[6])}</span></td>
          <td><code>{esc(s[3])}</code></td>
          <td>{esc(s[4])}</td>
          <td>{''.join(f'<div>• {esc(a)}</div>' for a in s[5])}</td>
        </tr>"""
        for s in SCREENS
    )

    return f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8"/>
<title>HealthFit — Documentação Técnica e de Produto</title>
<style>
  @page {{ size: A4; margin: 18mm 16mm; }}
  :root {{
    --accent: #1f8f55;
    --ink: #15202b;
    --muted: #5b6b7c;
    --line: #d7dee7;
    --bg: #f7f9fc;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
    color: var(--ink); line-height: 1.45; margin: 0; background: white;
  }}
  .cover {{
    min-height: 95vh; display: flex; flex-direction: column; justify-content: center;
    padding: 40px; background: linear-gradient(160deg, #0d1b14, #163024 45%, #1a2330);
    color: white; page-break-after: always;
  }}
  .cover .badge {{
    display: inline-block; padding: 6px 12px; border-radius: 999px;
    background: rgba(46,204,113,.18); border: 1px solid rgba(46,204,113,.45);
    font-size: 12px; letter-spacing: .04em; text-transform: uppercase;
  }}
  .cover h1 {{ font-size: 46px; margin: 18px 0 8px; letter-spacing: -0.03em; }}
  .cover .subtitle {{ font-size: 18px; opacity: .88; max-width: 560px; }}
  .cover .meta {{ margin-top: 40px; font-size: 13px; opacity: .8; }}
  .cover .meta div {{ margin: 4px 0; }}
  h1.chapter {{
    font-size: 24px; color: var(--accent); border-bottom: 2px solid var(--accent);
    padding-bottom: 8px; margin-top: 0; page-break-before: always;
  }}
  h1.chapter.first {{ page-break-before: avoid; }}
  h2 {{ font-size: 16px; margin-top: 22px; color: #1d2a38; }}
  h3 {{ font-size: 13.5px; margin-top: 16px; color: #243447; }}
  p, li {{ font-size: 11.5px; }}
  .muted {{ color: var(--muted); font-size: 10.5px; }}
  .toc a {{ color: var(--ink); text-decoration: none; }}
  .toc li {{ margin: 6px 0; }}
  table {{
    width: 100%; border-collapse: collapse; margin: 10px 0 18px; font-size: 10.5px;
  }}
  th, td {{
    border: 1px solid var(--line); padding: 7px 8px; vertical-align: top; text-align: left;
  }}
  th {{ background: var(--bg); color: #314354; }}
  code {{
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 10px; background: #eef3f8; padding: 1px 4px; border-radius: 3px;
  }}
  pre {{
    background: #0f1720; color: #d7 inde; color: #d7ece0; padding: 12px; border-radius: 8px;
    font-size: 10px; overflow: hidden; white-space: pre-wrap;
  }}
  .callout {{
    background: #eefaf3; border-left: 4px solid var(--accent); padding: 10px 12px;
    margin: 12px 0; font-size: 11px;
  }}
  .grid-2 {{ display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }}
  .card {{
    border: 1px solid var(--line); border-radius: 10px; padding: 12px; background: var(--bg);
  }}
  .card h3 {{ margin-top: 0; }}
  footer.page-foot {{
    margin-top: 28px; padding-top: 10px; border-top: 1px solid var(--line);
    font-size: 10px; color: var(--muted); display: flex; justify-content: space-between;
  }}
</style>
</head>
<body>

<section class="cover">
  <div class="badge">Documentação Oficial de Produto & Engenharia</div>
  <h1>HealthFit</h1>
  <p class="subtitle">Personal Trainer Inteligente — documentação robusta de telas, arquitetura, integrações, notificações e mapa Figma do produto.</p>
  <div class="meta">
    <div><strong>Versão do produto:</strong> {VERSION}</div>
    <div><strong>Data:</strong> {TODAY}</div>
    <div><strong>Desenvolvimento:</strong> BERG / LUAN</div>
    <div><strong>Desenvolvimento:</strong> BERG / LUAN</div>
    <div><strong>Plataformas:</strong> iOS 17+ · watchOS 10+</div>
    <div><strong>Bundle ID:</strong> luan.com.healthfit.app</div>
  </div>
</section>

<section>
  <h1 class="chapter first">1. Sumário executivo</h1>
  <p>
    O HealthFit é um aplicativo nativo Apple (SwiftUI) que concentra musculação, cardio, meditação,
    nutrição personalizada, IAssistente, métricas do Apple Health, sincronização com Apple Watch,
    ícone dinâmico de saúde e sincronização seletiva com Firebase Cloud Firestore.
  </p>
  <div class="grid-2">
    <div class="card">
      <h3>Proposta de valor</h3>
      <ul>
        <li>Treinos guiados (força, cardio, meditação)</li>
        <li>Plano alimentar + lista de compras</li>
        <li>Coach conversacional (IAssistente)</li>
        <li>Hábitos diários: sono, água, energéticos, pré-treino</li>
        <li>Feedback visual via ícone de saúde (app + perfil)</li>
      </ul>
    </div>
    <div class="card">
      <h3>Público e idioma</h3>
      <ul>
        <li>Atletas e iniciantes em fitness</li>
        <li>Interface 100% em português (pt-BR)</li>
        <li>Opcional: personal trainer por e-mail</li>
        <li>Conta Firebase (e-mail, Google ou Apple)</li>
      </ul>
    </div>
  </div>
  <div class="callout">
    <strong>Escopo desta documentação:</strong> inventário completo de telas (com nomenclatura Figma),
    fluxos de navegação, serviços, modelos de dados, cloud sync, notificações, Watch e stack técnica.
    O mapa visual detalhado está em <code>Docs/figma/HealthFit_Screen_Map_Figma.html</code>.
  </div>
</section>

<section>
  <h1 class="chapter">2. Índice</h1>
  <ol class="toc">
    <li><a href="#s3">Visão do produto e stack</a></li>
    <li><a href="#s4">Arquitetura e navegação</a></li>
    <li><a href="#s5">Catálogo de telas (detalhado)</a></li>
    <li><a href="#s6">Design system & guia Figma</a></li>
    <li><a href="#s7">Serviços e domínio</a></li>
    <li><a href="#s8">Modelos de dados</a></li>
    <li><a href="#s9">Firebase / Cloud</a></li>
    <li><a href="#s10">Notificações</a></li>
    <li><a href="#s11">Apple Watch & HealthKit</a></li>
    <li><a href="#s12">Segurança, privacidade e exclusão</a></li>
    <li><a href="#s13">Testes e qualidade</a></li>
    <li><a href="#s14">Apêndices</a></li>
  </ol>
</section>

<section id="s3">
  <h1 class="chapter">3. Visão do produto e stack</h1>
  <h2>3.1 Stack tecnológica</h2>
  <table>
    <tr><th>Camada</th><th>Tecnologia</th></tr>
    <tr><td>UI</td><td>SwiftUI, Charts, tema escuro (<code>AppTheme</code>)</td></tr>
    <tr><td>Arquitetura</td><td>ObservableObject + EnvironmentObject (serviços)</td></tr>
    <tr><td>Auth</td><td>Firebase Auth, Google Sign-In, Sign in with Apple</td></tr>
    <tr><td>Backend</td><td>Firestore + Firebase Storage</td></tr>
    <tr><td>Saúde</td><td>HealthKit (leitura/escrita)</td></tr>
    <tr><td>Wearable</td><td>watchOS + WatchConnectivity</td></tr>
    <tr><td>Notificações</td><td>UserNotifications + BGTaskScheduler</td></tr>
    <tr><td>Câmera</td><td>AVFoundation / Vision AI (experimental)</td></tr>
    <tr><td>Testes</td><td>HealthFitTests / HealthFitUITests</td></tr>
  </table>
  <h2>3.2 Targets</h2>
  <table>
    <tr><th>Target</th><th>Mínimo</th><th>Bundle</th></tr>
    <tr><td>HealthFit (iPhone/iPad)</td><td>iOS 17.0</td><td><code>luan.com.healthfit.app</code></td></tr>
    <tr><td>HealthFitWatch</td><td>watchOS 10.0</td><td><code>luan.com.healthfit.app.watchkitapp</code></td></tr>
  </table>
</section>

<section id="s4">
  <h1 class="chapter">4. Arquitetura e navegação</h1>
  <h2>4.1 Fluxo raiz</h2>
  <pre>HealthFitApp
 └─ RootView
     ├─ Restauração de sessão
     ├─ LoginView (!autenticado)
     ├─ WelcomeMotivationView
     └─ MainTabView
          ├─ Início (Dashboard)
          ├─ Treinos
          ├─ Nutrição
          ├─ IAssistente
          └─ Perfil</pre>
  <h2>4.2 Bootstrap pós-login</h2>
  <ul>
    <li>Configuração de wellness + sync Firebase</li>
    <li>Autorização HealthKit</li>
    <li>Carga/geração do plano alimentar</li>
    <li>Histórico de treinos na nuvem</li>
    <li>Catálogo de vídeos/GIFs de exercícios</li>
    <li>Agendamento de notificações recorrentes</li>
    <li>Sincronização do ícone de saúde (app ↔ perfil)</li>
  </ul>
</section>

<section id="s5">
  <h1 class="chapter">5. Catálogo de telas (detalhado)</h1>
  <p>Cada tela possui um frame Figma sugerido. Use a coluna “Frame Figma” como nome do frame no arquivo de design.</p>
  <table>
    <tr>
      <th>Área</th><th>Tela / Frame Figma</th><th>Arquivo</th><th>Propósito</th><th>Ações</th>
    </tr>
    {screen_rows}
  </table>
</section>

<section id="s6">
  <h1 class="chapter">6. Design system & guia Figma</h1>
  <h2>6.1 Tokens (AppTheme)</h2>
  <table>
    <tr><th>Token</th><th>Uso</th><th>Referência</th></tr>
    <tr><td>AccentGreen</td><td>CTA, sucesso, ícone saudável</td><td>Asset AccentGreen</td></tr>
    <tr><td>AccentOrange</td><td>Destaque secundário / gradiente</td><td>Asset AccentOrange</td></tr>
    <tr><td>Background</td><td>Fundo das telas</td><td>Asset Background</td></tr>
    <tr><td>CardBackground</td><td>Cards e seções</td><td>Asset CardBackground</td></tr>
    <tr><td>cornerRadius</td><td>16pt</td><td><code>AppTheme.cornerRadius</code></td></tr>
    <tr><td>padding</td><td>20pt</td><td><code>AppTheme.padding</code></td></tr>
  </table>
  <h2>6.2 Estrutura sugerida no Figma</h2>
  <pre>HealthFit Design System
 ├─ 00 Cover
 ├─ 01 Foundations (colors, type, radius, icons)
 ├─ 02 Components (buttons, cards, chat bubbles, tab bar)
 ├─ 03 Auth
 ├─ 04 Onboarding
 ├─ 05 Início
 ├─ 06 Treinos / Cardio / Meditação
 ├─ 07 Nutrição
 ├─ 08 IAssistente
 ├─ 09 Perfil
 ├─ 10 Watch
 └─ 11 Flows (FigJam / prototype links)</pre>
  <div class="callout">
    Artefatos prontos neste repositório:<br/>
    • <code>Docs/figma/HealthFit_Screen_Map_Figma.html</code> — mapa visual de telas<br/>
    • <code>Docs/figma/figma_design_tokens_and_screens.json</code> — tokens + inventário importável<br/>
    • <code>Docs/figma/FIGMA_IMPORT_GUIDE.md</code> — passo a passo para montar o arquivo Figma
  </div>
  <h2>6.3 Ícone de saúde (app + perfil)</h2>
  <table>
    <tr><th>Status</th><th>Condição</th><th>UI Perfil</th><th>Ícone na Home Screen</th></tr>
    <tr><td>Verde</td><td>Sono e água registrados no dia</td><td>Glow verde</td><td>AppIcon / Pulse</td></tr>
    <tr><td>Amarelo</td><td>Falta sono e/ou água no dia (&lt;24h)</td><td>Glow amarelo</td><td>AppIconYellow*</td></tr>
    <tr><td>Vermelho</td><td>≥24h sem atualizar água/sono</td><td>Glow vermelho</td><td>AppIconRed*</td></tr>
  </table>
</section>

<section id="s7">
  <h1 class="chapter">7. Serviços e domínio</h1>
  <table>
    <tr><th>Serviço</th><th>Responsabilidade</th></tr>
    <tr><td>AuthService</td><td>Login, registro, social, perfil, exclusão de conta</td></tr>
    <tr><td>DailyWellnessService</td><td>Sono, água, energéticos, pré-treino, ícone de saúde, cloud</td></tr>
    <tr><td>WorkoutStore</td><td>Fichas, sessão ativa, histórico, cardio/meditação, cloud</td></tr>
    <tr><td>MealPlanService</td><td>Plano semanal, calorias, lista de compras</td></tr>
    <tr><td>HealthAssistantService</td><td>Chat, check-ins, montar treino, nudges</td></tr>
    <tr><td>NotificationService</td><td>Água 2h, motivação, check-ins, inatividade, ícone saúde</td></tr>
    <tr><td>HealthKitManager</td><td>Leitura/escrita de métricas e treinos</td></tr>
    <tr><td>WatchConnectivityManager</td><td>Bridge iPhone ↔ Watch</td></tr>
    <tr><td>AppIconInactivityService</td><td>Ícone alternativo sincronizado com wellness</td></tr>
    <tr><td>*FirestoreService</td><td>Profile, workouts, wellness, exercise videos</td></tr>
  </table>
</section>

<section id="s8">
  <h1 class="chapter">8. Modelos de dados</h1>
  <h2>8.1 Usuário</h2>
  <p><code>UserProfile</code>: identidade, biotipo, objetivo, gênero, antropometria, medidas corporais, personal trainer, datas.</p>
  <h2>8.2 Treinos</h2>
  <p><code>WorkoutSheet</code>, <code>Exercise</code>, <code>WorkoutSession</code>, registros por exercício, campos de cardio/meditação, pré-treino, encerramento antecipado.</p>
  <h2>8.3 Nutrição</h2>
  <p><code>DailyMealPlan</code>, refeições por tipo, preferências (doces/lactose), <code>ShoppingItem</code>, suplementação.</p>
  <h2>8.4 Wellness</h2>
  <p><code>DailyWellnessEntry</code> (dayKey, sleepHours, waterIntakeMl, energyDrinksCount, preWorkoutCount).</p>
</section>

<section id="s9">
  <h1 class="chapter">9. Firebase / Cloud</h1>
  <table>
    <tr><th>Recurso</th><th>Caminho</th><th>Comportamento</th></tr>
    <tr><td>Auth</td><td>Firebase Auth</td><td>E-mail, Google, Apple</td></tr>
    <tr><td>Perfil</td><td><code>users/{{uid}}</code></td><td>Sync em updateProfile</td></tr>
    <tr><td>Treinos</td><td><code>users/{{uid}}/workoutSessions</code></td><td>Últimas 10 sessões</td></tr>
    <tr><td>Wellness</td><td><code>users/{{uid}}/dailyWellness</code> + <code>wellnessMeta</code></td><td>Merge local/remoto</td></tr>
    <tr><td>Vídeos</td><td>Firestore + Storage</td><td>Catálogo remoto de demos</td></tr>
    <tr><td>Exclusão</td><td>Todos acima</td><td>Wipe remoto + purge local</td></tr>
  </table>
  <p class="muted">Locais (não Firestore): fichas custom, plano alimentar/compras, chat, foto de perfil, preferências de descanso.</p>
</section>

<section id="s10">
  <h1 class="chapter">10. Notificações</h1>
  <table>
    <tr><th>Tipo</th><th>Quando</th></tr>
    <tr><td>Hidratação</td><td>A cada 2h (08–20h)</td></tr>
    <tr><td>Motivação diária</td><td>~08:00</td></tr>
    <tr><td>Check-in manhã / noite</td><td>09:00 / 21:00</td></tr>
    <tr><td>Pós-treino</td><td>~90 min após sessão</td></tr>
    <tr><td>Inatividade treino/cardio/meditação</td><td>48h</td></tr>
    <tr><td>Ícone de saúde amarelo/vermelho</td><td>Mudança de status</td></tr>
    <tr><td>Descanso encerrado</td><td>Fim do timer entre séries</td></tr>
  </table>
</section>

<section id="s11">
  <h1 class="chapter">11. Apple Watch & HealthKit</h1>
  <h2>11.1 Watch</h2>
  <p>Companion recebe início/progresso/fim de musculação, cardio e meditação; exibe cronômetro, BPM, calorias e permite encerrar.</p>
  <h2>11.2 HealthKit</h2>
  <p>Leitura de passos, energia ativa, frequência cardíaca, massa corporal e treinos; escrita de sessões e energia quando autorizado.</p>
</section>

<section id="s12">
  <h1 class="chapter">12. Segurança, privacidade e exclusão</h1>
  <ul>
    <li>Autenticação Firebase com providers sociais e e-mail</li>
    <li>Política de senha forte no registro</li>
    <li>Documentos legais (Termos e Privacidade) embutidos</li>
    <li>Exclusão de conta com reautenticação e limpeza remota/local</li>
    <li>IAssistente com disclaimer de saúde (não substitui profissional)</li>
  </ul>
</section>

<section id="s13">
  <h1 class="chapter">13. Testes e qualidade</h1>
  <p>Cobertura unitária inclui (entre outros): PasswordPolicy, NotificationService (água 2h), Assistant engines,
  WeeklyProgressAnalyzer, check-ins, cardio config, catálogos de exercício.</p>
</section>

<section id="s14">
  <h1 class="chapter">14. Apêndices</h1>
  <h2>A. Como regenerar esta documentação</h2>
  <pre>python3 Docs/generate_docs.py</pre>
  <h2>B. Contato</h2>
  <p>BERG / LUAN — HealthFit v{VERSION}</p>
  <footer class="page-foot">
    <span>HealthFit — Documentação profissional</span>
    <span>Gerado em {TODAY}</span>
  </footer>
</section>

</body>
</html>
"""


def build_figma_json() -> dict:
    return {
        "product": "HealthFit",
        "version": VERSION,
        "generatedAt": TODAY,
        "company": "BERG / LUAN",
        "designTokens": {
            "colors": {
                "AccentGreen": "#2ECC71",
                "AccentOrange": "#F39C12",
                "Background": "#0B0F14",
                "CardBackground": "#1A2330",
                "TextPrimary": "#FFFFFF",
                "TextSecondary": "rgba(255,255,255,0.65)",
            },
            "radius": {"card": 16},
            "spacing": {"page": 20},
            "typography": {
                "title": "SF Pro Display / Semibold",
                "body": "SF Pro Text / Regular",
            },
            "mode": "dark",
        },
        "figmaPages": [
            "00 Cover",
            "01 Foundations",
            "02 Components",
            "03 Auth",
            "04 Onboarding",
            "05 Início",
            "06 Treinos",
            "07 Nutrição",
            "08 IAssistente",
            "09 Perfil",
            "10 Watch",
            "11 Flows",
        ],
        "screens": [
            {
                "id": s[0],
                "area": s[1],
                "title": s[2],
                "swiftFile": s[3],
                "purpose": s[4],
                "actions": s[5],
                "figmaFrame": s[6],
                "device": "iPhone 15 Pro / 393×852" if s[0] != "watch" else "Apple Watch Ultra",
            }
            for s in SCREENS
        ],
        "prototypeFlow": [
            "Login → Register",
            "Login → ForgotPassword",
            "Login → Welcome → MainTab",
            "MainTab/Treinos → Detail → Active → Summary",
            "MainTab/Nutrição → ShoppingList",
            "MainTab/IAssistente → Check-ins",
            "MainTab/Perfil → Measurements / DeleteAccount",
        ],
    }


def build_figma_guide() -> str:
    return f"""# Guia de importação Figma — HealthFit

**Gerado em:** {TODAY}  
**Versão do produto:** {VERSION}

> O MCP do Figma não estava autenticado neste ambiente. Este pacote entrega o inventário
> completo de frames, tokens e fluxos para você montar (ou sincronizar) o arquivo Figma
> em minutos.

## 1. Criar o arquivo

1. Abra o Figma → **New design file** → renomeie para `HealthFit — Product Screens`.
2. Crie as páginas listadas em `figma_design_tokens_and_screens.json` → `figmaPages`.
3. Em **Local variables**, crie a collection `HealthFit / Dark` com as cores do JSON.

## 2. Frames por tela

Para cada item em `screens[]`:

1. Crie um frame **iPhone 14/15 Pro (393×852)** (ou Watch quando `device` indicar).
2. Nomeie exatamente como `figmaFrame` (ex.: `Treinos / 01 Hub`).
3. Adicione uma anotação (sticky ou text) com:
   - Propósito
   - Arquivo SwiftUI
   - Ações principais
4. Use o HTML `HealthFit_Screen_Map_Figma.html` como referência visual lado a lado.

## 3. Prototype

Conecte os fluxos de `prototypeFlow` com setas de protótipo (On click / Navigate to).

## 4. Componentes mínimos sugeridos

- `Button/Primary` (AccentGreen)
- `Button/Secondary`
- `Card/Surface`
- `TabBar/5 items`
- `Chat/Bubble User` e `Chat/Bubble Assistant`
- `HealthIcon/Green|Yellow|Red`
- `List/Row Workout`

## 5. Entrega

Exporte:

- PDF do arquivo Figma (File → Export frames to PDF), **ou**
- Use o PDF gerado em `Docs/HealthFit_Documentacao_Completa.pdf` como documento mestre
  de produto/engenharia, e o Figma como source of truth visual.
"""


def html_to_pdf(html_path: Path, pdf_path: Path) -> None:
    chrome = Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    if not chrome.exists():
        raise RuntimeError("Google Chrome não encontrado para gerar PDF")

    cmd = [
        str(chrome),
        "--headless=new",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path}",
        html_path.as_uri(),
    ]
    subprocess.run(cmd, check=True, capture_output=True, text=True)


def main() -> None:
    FIGMA_DIR.mkdir(parents=True, exist_ok=True)

    figma_html = build_figma_html()
    FIGMA_HTML.write_text(figma_html, encoding="utf-8")

    full_html = build_full_html()
    # fix accidental typo in pre style if any
    full_html = full_html.replace("color: #d7 inde; color: #d7ece0;", "color: #d7ece0;")
    OUT_HTML.write_text(full_html, encoding="utf-8")

    FIGMA_JSON.write_text(
        json.dumps(build_figma_json(), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    FIGMA_MD.write_text(build_figma_guide(), encoding="utf-8")

    html_to_pdf(OUT_HTML, OUT_PDF)
    # also PDF of figma screen map
    figma_pdf = FIGMA_DIR / "HealthFit_Screen_Map_Figma.pdf"
    html_to_pdf(FIGMA_HTML, figma_pdf)

    print("OK")
    print(f"- {OUT_HTML}")
    print(f"- {OUT_PDF}")
    print(f"- {FIGMA_HTML}")
    print(f"- {figma_pdf}")
    print(f"- {FIGMA_JSON}")
    print(f"- {FIGMA_MD}")


if __name__ == "__main__":
    main()
