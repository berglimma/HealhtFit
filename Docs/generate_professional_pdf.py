#!/usr/bin/env python3
"""HealthFit — documentação PDF profissional (A4) alinhada ao código atual."""

from __future__ import annotations

from datetime import date
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
    HRFlowable,
)

ROOT = Path(__file__).resolve().parent
OUT_PDF = ROOT / "HealthFit_Documentacao_Completa.pdf"
FIGMA_URL = "https://www.figma.com/design/WPvjXR5t3EZbuO962iay3K"
TODAY = date.today().strftime("%d/%m/%Y")
VERSION = "1.0.0"

# Cores reais do Asset Catalog
C_GREEN = colors.Color(0.20, 0.85, 0.18)
C_ORANGE = colors.Color(1.00, 0.55, 0.20)
C_BG = colors.Color(0.08, 0.10, 0.10)
C_CARD = colors.Color(0.14, 0.16, 0.18)
C_INK = colors.Color(0.10, 0.14, 0.18)
C_MUTED = colors.Color(0.40, 0.46, 0.52)
C_LINE = colors.Color(0.86, 0.89, 0.92)
C_SOFT = colors.Color(0.96, 0.98, 0.97)


def styles():
    base = getSampleStyleSheet()
    s = {
        "cover_badge": ParagraphStyle(
            "cover_badge", parent=base["Normal"], fontName="Helvetica-Bold",
            fontSize=9, textColor=C_GREEN, tracking=1, spaceAfter=12,
        ),
        "cover_title": ParagraphStyle(
            "cover_title", parent=base["Normal"], fontName="Helvetica-Bold",
            fontSize=36, textColor=colors.white, leading=42, spaceAfter=10,
        ),
        "cover_sub": ParagraphStyle(
            "cover_sub", parent=base["Normal"], fontName="Helvetica",
            fontSize=13, textColor=colors.Color(0.75, 0.82, 0.78), leading=18, spaceAfter=28,
        ),
        "cover_meta": ParagraphStyle(
            "cover_meta", parent=base["Normal"], fontName="Helvetica",
            fontSize=10, textColor=colors.Color(0.82, 0.88, 0.85), leading=15,
        ),
        "h1": ParagraphStyle(
            "h1", parent=base["Heading1"], fontName="Helvetica-Bold",
            fontSize=18, textColor=C_INK, spaceBefore=0, spaceAfter=10, leading=22,
        ),
        "h2": ParagraphStyle(
            "h2", parent=base["Heading2"], fontName="Helvetica-Bold",
            fontSize=12.5, textColor=colors.Color(0.12, 0.35, 0.22),
            spaceBefore=14, spaceAfter=6, leading=16,
        ),
        "body": ParagraphStyle(
            "body", parent=base["Normal"], fontName="Helvetica",
            fontSize=9.5, textColor=C_INK, leading=13.5, alignment=TA_JUSTIFY, spaceAfter=6,
        ),
        "bullet": ParagraphStyle(
            "bullet", parent=base["Normal"], fontName="Helvetica",
            fontSize=9.2, textColor=C_INK, leading=12.8, leftIndent=2,
        ),
        "small": ParagraphStyle(
            "small", parent=base["Normal"], fontName="Helvetica",
            fontSize=8, textColor=C_MUTED, leading=11,
        ),
        "cell": ParagraphStyle(
            "cell", parent=base["Normal"], fontName="Helvetica",
            fontSize=8, textColor=C_INK, leading=10.5,
        ),
        "cell_b": ParagraphStyle(
            "cell_b", parent=base["Normal"], fontName="Helvetica-Bold",
            fontSize=8, textColor=C_INK, leading=10.5,
        ),
        "footer": ParagraphStyle(
            "footer", parent=base["Normal"], fontName="Helvetica",
            fontSize=7.5, textColor=C_MUTED, alignment=TA_CENTER,
        ),
        "toc": ParagraphStyle(
            "toc", parent=base["Normal"], fontName="Helvetica",
            fontSize=10, textColor=C_INK, leading=16, spaceAfter=3,
        ),
        "callout": ParagraphStyle(
            "callout", parent=base["Normal"], fontName="Helvetica",
            fontSize=9, textColor=C_INK, leading=12.5,
        ),
        "mono": ParagraphStyle(
            "mono", parent=base["Code"], fontName="Courier",
            fontSize=7.5, textColor=colors.Color(0.85, 0.95, 0.88),
            leading=10.5, backColor=C_BG, leftIndent=0, rightIndent=0,
        ),
    }
    return s


S = styles()


def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(C_LINE)
    canvas.setLineWidth(0.5)
    y = 12 * mm
    canvas.line(18 * mm, y + 5, A4[0] - 18 * mm, y + 5)
    canvas.setFont("Helvetica", 7.5)
    canvas.setFillColor(C_MUTED)
    canvas.drawString(18 * mm, y, f"HealthFit v{VERSION} · BERG / LUAN")
    canvas.drawRightString(A4[0] - 18 * mm, y, f"{TODAY}  ·  {doc.page}")
    canvas.restoreState()


def cover_page(story):
    # Simulated dark cover via full-width table
    data = [[
        Paragraph("DOCUMENTAÇÃO OFICIAL DE PRODUTO &amp; ENGENHARIA", S["cover_badge"]),
    ], [
        Paragraph("HealthFit", S["cover_title"]),
    ], [
        Paragraph(
            "Personal Trainer Inteligente — documentação de excelência das telas, "
            "arquitetura, Firebase, notificações, IAssistente e sincronização do ícone de saúde.",
            S["cover_sub"],
        ),
    ], [
        Paragraph(
            f"<b>Versão:</b> {VERSION}<br/>"
            f"<b>Data de referência:</b> {TODAY}<br/>"
            f"<b>Desenvolvimento:</b> BERG / LUAN<br/>"
            f"<b>Plataformas:</b> iOS 17+ · watchOS 10+<br/>"
            f"<b>Bundle ID:</b> luan.com.healthfit.app<br/>"
            f"<b>Figma:</b> {FIGMA_URL}",
            S["cover_meta"],
        ),
    ]]
    t = Table(data, colWidths=[170 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), C_BG),
        ("TOPPADDING", (0, 0), (-1, 0), 55),
        ("LEFTPADDING", (0, 0), (-1, -1), 22),
        ("RIGHTPADDING", (0, 0), (-1, -1), 22),
        ("BOTTOMPADDING", (0, -1), (-1, -1), 45),
        ("TOPPADDING", (0, 1), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -2), 6),
        ("ROUNDEDCORNERS", [8, 8, 8, 8]),
    ]))
    story.append(Spacer(1, 18 * mm))
    story.append(t)
    story.append(PageBreak())


def section_title(story, n: str, title: str):
    story.append(Paragraph(f"{n}. {title}", S["h1"]))
    story.append(HRFlowable(width="100%", thickness=1.6, color=C_GREEN, spaceAfter=8))


def bullets(items):
    return ListFlowable(
        [ListItem(Paragraph(i, S["bullet"]), leftIndent=8, bulletColor=C_GREEN) for i in items],
        bulletType="bullet",
        start="•",
        leftIndent=12,
        spaceBefore=2,
        spaceAfter=8,
    )


def callout(text: str):
    t = Table([[Paragraph(text, S["callout"])]], colWidths=[170 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), C_SOFT),
        ("BOX", (0, 0), (-1, -1), 0, C_SOFT),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("LINEBEFORE", (0, 0), (0, -1), 3.5, C_GREEN),
    ]))
    return t


def nice_table(headers, rows, widths):
    head = [Paragraph(f"<b>{h}</b>", S["cell_b"]) for h in headers]
    body = [[Paragraph(str(c), S["cell"]) for c in r] for r in rows]
    t = Table([head] + body, colWidths=widths, repeatRows=1)
    style_cmds = [
        ("BACKGROUND", (0, 0), (-1, 0), colors.Color(0.93, 0.97, 0.94)),
        ("TEXTCOLOR", (0, 0), (-1, 0), C_INK),
        ("GRID", (0, 0), (-1, -1), 0.4, C_LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]
    for i in range(1, len(body) + 1):
        if i % 2 == 0:
            style_cmds.append(("BACKGROUND", (0, i), (-1, i), colors.Color(0.98, 0.99, 0.98)))
    t.setStyle(TableStyle(style_cmds))
    return t


SCREENS = [
    ("Autenticação", "Login", "LoginView.swift", "Entrada do usuário não autenticado", "E-mail/senha, Google, Apple, recuperar senha"),
    ("Autenticação", "Criar Conta", "RegisterView.swift", "Cadastro com biotipo, objetivo e senha forte", "Validar senha, termos, registrar"),
    ("Autenticação", "Esqueci minha senha", "ForgotPasswordView.swift", "Recuperação por e-mail", "Enviar link"),
    ("Onboarding", "Boas-vindas", "WelcomeMotivationView.swift", "Slides motivacionais pós-login / retorno", "Avançar e entrar no app"),
    ("Onboarding", "Check-in diário (sono)", "DailyWellnessCheckInView.swift", "Registro de sono ao abrir", "Ajustar horas e confirmar"),
    ("Início", "Dashboard", "DashboardView.swift", "Visão geral + ícone de saúde sincronizado", "Refresh HealthKit, relatório, Watch"),
    ("Início", "Desempenho Semanal", "HealthChartsView.swift", "Gráficos de treino/passos/calorias/FC/meditação", "Trocar métrica"),
    ("Início", "Relatório Semanal", "WeeklyReportView.swift", "Score, destaques e sugestões", "Comparar semanas"),
    ("Treinos", "Treinos (Hub)", "WorkoutListView.swift", "Hub Musculação / Cardio / Meditação", "Abrir seção ou criar ficha"),
    ("Treinos", "Hub Masculino / Feminino", "GenderWorkoutHubView.swift", "Recomendados e personalizados", "Abrir / criar ficha"),
    ("Treinos", "Detalhe da Ficha", "WorkoutDetailView.swift", "Exercícios e início de sessão", "Iniciar, editar, Vision AI, pré-treino"),
    ("Treinos", "Nova / Editar Ficha", "CreateWorkoutView.swift", "Montagem de ficha", "Foco, exercícios, salvar"),
    ("Treinos", "Treino Ativo", "ActiveWorkoutView.swift", "Sessão com descanso e Watch", "Séries, descanso, encerrar"),
    ("Treinos", "Resumo do Treino", "WorkoutSummaryView.swift", "Relatório pós-sessão", "Métricas, e-mail ao personal"),
    ("Cardio", "Configurar Cardio", "CardioSetupView.swift", "Intensidade, distância, kcal", "Configurar e iniciar"),
    ("Cardio", "Cardio Ativo", "ActiveCardioView.swift", "Sessão ao vivo", "Progresso e encerrar"),
    ("Meditação", "Configurar Meditação", "MeditationSetupView.swift", "Tópico e duração 5–20 min", "Escolher e iniciar"),
    ("Meditação", "Meditação Ativa", "ActiveMeditationView.swift", "Sessão guiada", "Prompts e encerrar"),
    ("Nutrição", "Nutrição", "MealPlanView.swift", "Plano semanal personalizado", "Preferências, gerar, compras"),
    ("Nutrição", "Lista de Compras", "ShoppingListView.swift", "Lista + catálogo + suplementos", "Marcar, adicionar, relatório"),
    ("IAssistente", "Assistente", "HealthChatView.swift", "Coach por regras + check-ins + nudges 48h", "Chat, sugestões, montar treino"),
    ("Perfil", "Perfil", "ProfileView.swift", "Dados, ícone de saúde, sono/água, medidas", "Editar, wellness, logout"),
    ("Perfil", "Comparativo de Medidas", "BodyMeasurementComparisonView.swift", "Deltas ~30 dias", "Ver evolução"),
    ("Perfil", "Excluir Conta", "DeleteAccountSheet.swift", "Exclusão permanente", "Reauth e confirmar"),
    ("Experimental", "Vision AI", "VisionWorkoutView.swift", "Treino assistido por câmera", "Iniciar câmera"),
    ("Apple Watch", "Watch Companion", "WatchContentView.swift", "Cronômetro e métricas sincronizadas", "Acompanhar / Encerrar"),
]


def build():
    story = []
    cover_page(story)

    # TOC
    section_title(story, "0", "Índice")
    toc = [
        "1. Sumário executivo",
        "2. Identificação do produto e stack",
        "3. Arquitetura e navegação",
        "4. Catálogo de telas (26)",
        "5. Design system e ícone de saúde",
        "6. Treinos, cardio e meditação",
        "7. Nutrição e hábitos diários",
        "8. IAssistente (rule-based)",
        "9. Firebase e sincronização cloud",
        "10. Notificações e engajamento",
        "11. Apple Watch, HealthKit e privacidade",
        "12. Qualidade, Figma e apêndices",
    ]
    for line in toc:
        story.append(Paragraph(line, S["toc"]))
    story.append(PageBreak())

    # 1
    section_title(story, "1", "Sumário executivo")
    story.append(Paragraph(
        "O HealthFit é um aplicativo nativo Apple (SwiftUI) que concentra musculação, cardio, "
        "meditação, nutrição personalizada, hábitos de sono/hidratação e um coach conversacional "
        "local (IAssistente). A experiência cobre iPhone/iPad e companion Apple Watch, com "
        "sincronização seletiva via Firebase.",
        S["body"],
    ))
    story.append(bullets([
        "Cinco abas: <b>Início</b>, <b>Treinos</b>, <b>Nutrição</b>, <b>IAssistente</b>, <b>Perfil</b>.",
        "Autenticação Firebase: e-mail/senha, Google e Sign in with Apple.",
        "Ícone de saúde único: Dashboard + Perfil + Home Screen sincronizados por <font face='Courier' size='8'>DailyWellnessService.healthIconStatus</font>.",
        "Cloud: Firestore (perfil, treinos, wellness) e Storage (vídeos de exercícios).",
        "IAssistente <b>baseado em regras locais</b> — sem LLM em nuvem.",
        "Engajamento: água a cada <b>2h (08–20)</b>; nudges de cardio/meditação em <b>48h</b>.",
    ]))
    story.append(callout(
        "<b>Fonte de verdade visual:</b> arquivo Figma "
        f"<font color='#1a7a45'>{FIGMA_URL}</font> — alinhado aos tokens reais do Asset Catalog e às 26 telas do produto."
    ))
    story.append(PageBreak())

    # 2
    section_title(story, "2", "Identificação do produto e stack")
    story.append(Paragraph("2.1 Identificação", S["h2"]))
    story.append(nice_table(
        ["Campo", "Valor"],
        [
            ["Produto", "HealthFit — Personal Trainer Inteligente"],
            ["Versão", VERSION],
            ["Desenvolvimento", "BERG / LUAN"],
            ["iOS Bundle", "luan.com.healthfit.app"],
            ["watchOS Bundle", "luan.com.healthfit.app.watchkitapp"],
            ["Mínimos", "iOS 17.0 · watchOS 10.0"],
            ["Idioma UI", "Português (pt-BR)"],
        ],
        [45 * mm, 125 * mm],
    ))
    story.append(Paragraph("2.2 Stack tecnológica", S["h2"]))
    story.append(nice_table(
        ["Camada", "Tecnologia"],
        [
            ["UI", "SwiftUI, Charts, tema escuro (AppTheme)"],
            ["Arquitetura", "ObservableObject + EnvironmentObject"],
            ["Auth", "Firebase Auth, Google Sign-In, Sign in with Apple"],
            ["Backend", "Cloud Firestore + Firebase Storage"],
            ["Saúde", "HealthKit (leitura/escrita)"],
            ["Wearable", "watchOS + WatchConnectivity"],
            ["Notificações", "UserNotifications + BGTaskScheduler"],
            ["Experimental", "AVFoundation / Vision AI"],
            ["Testes", "HealthFitTests · HealthFitUITests"],
        ],
        [40 * mm, 130 * mm],
    ))
    story.append(PageBreak())

    # 3
    section_title(story, "3", "Arquitetura e navegação")
    story.append(Paragraph(
        "O ponto de entrada <font face='Courier' size='8'>HealthFitApp</font> injeta os serviços "
        "globais e apresenta <font face='Courier' size='8'>RootView</font>, que decide entre "
        "restauração de sessão, autenticação, boas-vindas e a tab bar principal.",
        S["body"],
    ))
    story.append(Paragraph("3.1 Fluxo raiz", S["h2"]))
    flow = """HealthFitApp
 └─ RootView
     ├─ Restauração de sessão
     ├─ LoginView (!autenticado)
     │    ├─ RegisterView
     │    └─ ForgotPasswordView
     ├─ WelcomeMotivationView
     └─ MainTabView
          ├─ Início → Dashboard → Charts / Relatório
          ├─ Treinos → Hub → Ativo → Resumo
          ├─ Nutrição → Plano → Lista de Compras
          ├─ IAssistente → Chat / Check-ins / Nudges
          └─ Perfil → Medidas / Excluir Conta"""
    pre = Table([[Paragraph(flow.replace("\n", "<br/>").replace(" ", "&nbsp;"), ParagraphStyle(
        "pre", fontName="Courier", fontSize=7.4, textColor=colors.Color(0.85, 0.95, 0.88), leading=10
    ))]], colWidths=[170 * mm])
    pre.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), C_BG),
        ("LEFTPADDING", (0, 0), (-1, -1), 12),
        ("RIGHTPADDING", (0, 0), (-1, -1), 12),
        ("TOPPADDING", (0, 0), (-1, -1), 10),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
        ("ROUNDEDCORNERS", [6, 6, 6, 6]),
    ]))
    story.append(pre)
    story.append(Paragraph("3.2 Bootstrap pós-login", S["h2"]))
    story.append(bullets([
        "Configuração de wellness + sync Firebase.",
        "Autorização HealthKit e carga de métricas.",
        "Carga/geração do plano alimentar.",
        "Histórico de treinos na nuvem (últimas sessões).",
        "Catálogo de vídeos/GIFs de exercícios.",
        "Agendamento de notificações recorrentes.",
        "Sincronização do ícone de saúde (app ↔ perfil ↔ dashboard).",
    ]))
    story.append(PageBreak())

    # 4 Screens
    section_title(story, "4", "Catálogo de telas (26)")
    story.append(Paragraph(
        "Inventário oficial alinhado ao código SwiftUI e ao arquivo Figma do time. "
        "Device de referência: iPhone 15 Pro (393×852).",
        S["body"],
    ))
    rows = []
    for i, (area, title, file, purpose, actions) in enumerate(SCREENS, 1):
        rows.append([
            f"{i:02d}",
            area,
            title,
            file,
            purpose,
            actions,
        ])
    story.append(nice_table(
        ["#", "Área", "Tela", "Arquivo", "Propósito", "Ações"],
        rows,
        [10 * mm, 24 * mm, 28 * mm, 32 * mm, 38 * mm, 38 * mm],
    ))
    story.append(PageBreak())

    # 5 Design + health icon
    section_title(story, "5", "Design system e ícone de saúde")
    story.append(Paragraph("5.1 Tokens (Asset Catalog)", S["h2"]))
    story.append(nice_table(
        ["Token", "RGB (sRGB)", "Uso"],
        [
            ["AccentGreen", "0.20 / 0.85 / 0.18", "CTA, sucesso, ícone saudável"],
            ["AccentOrange", "1.00 / 0.55 / 0.20", "Destaque secundário / gradiente"],
            ["Background", "0.08 / 0.10 / 0.10", "Fundo das telas"],
            ["CardBackground", "0.14 / 0.16 / 0.18", "Cards e seções"],
            ["cornerRadius", "16 pt", "AppTheme.cornerRadius"],
            ["padding", "20 pt", "AppTheme.padding"],
        ],
        [40 * mm, 45 * mm, 85 * mm],
    ))
    story.append(Paragraph("5.2 Ícone de saúde — fonte única de verdade", S["h2"]))
    story.append(callout(
        "<b>Crítico:</b> o coração do Dashboard e do Perfil, bem como os ícones alternativos "
        "da Home Screen, usam <font face='Courier' size='8'>DailyWellnessService.healthIconStatus</font>. "
        "Não confundir com a lógica antiga exclusiva de inatividade de abertura do app."
    ))
    story.append(Spacer(1, 4))
    story.append(nice_table(
        ["Status", "Condição", "Superfícies"],
        [
            ["Verde", "Sono e água registrados hoje", "Dashboard · Perfil · AppIcon/Pulse"],
            ["Amarelo", "Falta sono e/ou água hoje (&lt;24h)", "Dashboard · Perfil · AppIconYellow*"],
            ["Vermelho", "≥24h sem atualizar água/sono", "Dashboard · Perfil · AppIconRed* + push"],
        ],
        [28 * mm, 72 * mm, 70 * mm],
    ))
    story.append(Paragraph(
        "Camada distinta: após 48h sem abrir o app em background, pode aparecer ícone "
        "<b>quebrado</b> (AppIconBroken*) — isso não substitui o status verde/amarelo/vermelho de saúde.",
        S["body"],
    ))
    story.append(PageBreak())

    # 6 Workouts
    section_title(story, "6", "Treinos, cardio e meditação")
    story.append(bullets([
        "Hub Treinos: musculação (fichas por gênero + personalizadas), cardio e meditação.",
        "Sessão ativa com descanso entre séries, sync Watch e resumo com e-mail ao personal.",
        "Cardio: intensidade, distância (ex. 5–25 km) e meta calórica.",
        "Meditação: tópicos guiados e duração de 5–20 minutos.",
        "Conclusão grava timestamps usados pelos nudges de 48h.",
        "Demos: GIFs locais + catálogo remoto Firestore/Storage.",
        "Vision AI: modo experimental de câmera — fora do fluxo core.",
    ]))

    # 7 Nutrition
    story.append(Paragraph("7. Nutrição e hábitos diários", S["h1"]))
    story.append(HRFlowable(width="100%", thickness=1.6, color=C_GREEN, spaceAfter=8))
    story.append(bullets([
        "Plano alimentar gerado a partir do perfil (antropometria, objetivo, preferências).",
        "Lista de compras com catálogo e suplementação guiada.",
        "Check-in de sono ao abrir; hidratação no Perfil alimenta o ícone de saúde.",
        "Wellness no Firestore: users/{uid}/dailyWellness e wellnessMeta/state.",
        "Plano/compras preferencialmente locais; medidas e perfil sincronizam na nuvem.",
    ]))
    story.append(PageBreak())

    # 8 Assistant
    section_title(story, "8", "IAssistente (rule-based)")
    story.append(Paragraph(
        "Implementado por HealthAssistantService / HealthAssistantEngine com matching de "
        "intenções e respostas determinísticas. Não há chamada a modelo LLM remoto.",
        S["body"],
    ))
    story.append(bullets([
        "Tópicos: dieta, IMC, biotipos, sono, treino, macros, suplementos, segurança.",
        "Check-ins guiados (pós-treino, manhã ~09h, noite ~21h).",
        "Fluxo “Montar treino” via AssistantWorkoutBuilder.",
        "Nudges 48h: AssistantCardioMeditationNudgeEngine (cardio, meditação ou ambos).",
        "Disclaimer de saúde obrigatório — não substitui profissional.",
        "Sugestões pré-definidas (suggestedQuestions) para UX offline-friendly.",
    ]))

    # 9 Firebase
    story.append(Paragraph("9. Firebase e sincronização cloud", S["h1"]))
    story.append(HRFlowable(width="100%", thickness=1.6, color=C_GREEN, spaceAfter=8))
    story.append(nice_table(
        ["Recurso", "Caminho / produto", "Comportamento"],
        [
            ["Auth", "Firebase Auth", "E-mail, Google, Apple"],
            ["Perfil", "users/{uid}", "Sync em updateProfile"],
            ["Treinos", "users/{uid}/workoutSessions", "Histórico recente"],
            ["Wellness", "dailyWellness + wellnessMeta", "Merge local/remoto"],
            ["Vídeos", "Firestore + Storage", "Catálogo de demos"],
            ["Exclusão", "Todos acima", "Wipe remoto + purge local"],
        ],
        [28 * mm, 55 * mm, 87 * mm],
    ))
    story.append(Paragraph(
        "Locais (não Firestore): fichas custom, plano/compras, chat, foto de perfil, prefs de descanso.",
        S["small"],
    ))
    story.append(PageBreak())

    # 10 Notifications
    section_title(story, "10", "Notificações e engajamento")
    story.append(nice_table(
        ["Tipo", "Quando", "Detalhe"],
        [
            ["Hidratação", "A cada 2h", "08, 10, 12, 14, 16, 18, 20h"],
            ["Motivação diária", "~08:00", "Mensagens rotativas"],
            ["Check-in manhã", "09:00", "IAssistente"],
            ["Check-in noite", "21:00", "IAssistente"],
            ["Pós-treino", "~90 min", "Recuperação / feeling"],
            ["Cardio 48h", "Após 48h", "Push + chat nudge"],
            ["Meditação 48h", "Após 48h", "Push + chat nudge"],
            ["Ícone amarelo/vermelho", "Mudança de status", "Emoji + CTA Perfil"],
            ["Inatividade app 48h", "Sem abrir o app", "Alerta + ícone quebrado"],
            ["Descanso", "Fim do timer", "Entre séries"],
        ],
        [40 * mm, 35 * mm, 95 * mm],
    ))

    # 11 Watch / privacy
    story.append(Paragraph("11. Apple Watch, HealthKit e privacidade", S["h1"]))
    story.append(HRFlowable(width="100%", thickness=1.6, color=C_GREEN, spaceAfter=8))
    story.append(bullets([
        "Watch recebe início/progresso/fim de musculação, cardio e meditação.",
        "HealthKit: passos, energia, FC, massa e treinos — leitura/escrita quando autorizado.",
        "Termos e Privacidade embutidos; suporte via e-mail da empresa.",
        "Exclusão de conta com reautenticação e limpeza remota/local.",
        "IAssistente com disclaimer legal (não diagnóstico).",
    ]))
    story.append(PageBreak())

    # 12 Quality + Figma
    section_title(story, "12", "Qualidade, Figma e apêndices")
    story.append(Paragraph("12.1 Qualidade", S["h2"]))
    story.append(bullets([
        "Testes unitários: PasswordPolicy, WaterReminder 2h, nudge engines, check-ins, cardio, catálogos.",
        "UITests no target HealthFitUITests.",
        "Build verificado via xcodebuild no simulador iOS.",
    ]))
    story.append(Paragraph("12.2 Figma", S["h2"]))
    story.append(Paragraph(
        f"Arquivo oficial: <font color='#1a7a45'><u>{FIGMA_URL}</u></font><br/>"
        "Páginas (limite Starter = 3): Cover/Auth/Onboarding · App principal · Watch/Flows/Health Icon.",
        S["body"],
    ))
    story.append(Paragraph("12.3 Regeneração", S["h2"]))
    story.append(Paragraph(
        "<font face='Courier' size='8'>python3 Docs/generate_professional_pdf.py</font>",
        S["body"],
    ))
    story.append(Spacer(1, 16))
    story.append(callout(
        f"<b>HealthFit v{VERSION}</b> — BERG / LUAN — {TODAY}<br/>"
        "Documento gerado a partir do código-fonte e do inventário de telas sincronizado com o Figma."
    ))

    doc = SimpleDocTemplate(
        str(OUT_PDF),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=16 * mm,
        bottomMargin=18 * mm,
        title=f"HealthFit — Documentação Oficial v{VERSION}",
        author="BERG / LUAN",
        subject="Documentação de produto e engenharia HealthFit",
    )
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(f"PDF: {OUT_PDF} ({OUT_PDF.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    build()
