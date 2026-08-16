#!/usr/bin/env python3
"""HealthFit — Guia do Usuário (PDF A4) para onboarding e suporte."""

from __future__ import annotations

from datetime import date
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    HRFlowable,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

ROOT = Path(__file__).resolve().parent
OUT_PDF = ROOT / "HealthFit_Guia_do_Usuario.pdf"
TODAY = date.today().strftime("%d/%m/%Y")
VERSION = "1.0"

C_GREEN = colors.Color(0.20, 0.85, 0.18)
C_BG = colors.Color(0.08, 0.10, 0.10)
C_INK = colors.Color(0.10, 0.14, 0.18)
C_MUTED = colors.Color(0.40, 0.46, 0.52)
C_LINE = colors.Color(0.86, 0.89, 0.92)
C_SOFT = colors.Color(0.96, 0.98, 0.97)


def styles():
    base = getSampleStyleSheet()
    return {
        "cover_badge": ParagraphStyle(
            "cover_badge", parent=base["Normal"], fontName="Helvetica-Bold",
            fontSize=9, textColor=C_GREEN, spaceAfter=12,
        ),
        "cover_title": ParagraphStyle(
            "cover_title", parent=base["Normal"], fontName="Helvetica-Bold",
            fontSize=34, textColor=colors.white, leading=40, spaceAfter=10,
        ),
        "cover_sub": ParagraphStyle(
            "cover_sub", parent=base["Normal"], fontName="Helvetica",
            fontSize=12.5, textColor=colors.Color(0.75, 0.82, 0.78), leading=17, spaceAfter=24,
        ),
        "cover_meta": ParagraphStyle(
            "cover_meta", parent=base["Normal"], fontName="Helvetica",
            fontSize=10, textColor=colors.Color(0.82, 0.88, 0.85), leading=15,
        ),
        "h1": ParagraphStyle(
            "h1", parent=base["Heading1"], fontName="Helvetica-Bold",
            fontSize=16, textColor=C_INK, spaceBefore=0, spaceAfter=8, leading=20,
        ),
        "h2": ParagraphStyle(
            "h2", parent=base["Heading2"], fontName="Helvetica-Bold",
            fontSize=11.5, textColor=colors.Color(0.12, 0.35, 0.22),
            spaceBefore=12, spaceAfter=5, leading=14,
        ),
        "body": ParagraphStyle(
            "body", parent=base["Normal"], fontName="Helvetica",
            fontSize=9.5, textColor=C_INK, leading=13.2, alignment=TA_JUSTIFY, spaceAfter=6,
        ),
        "bullet": ParagraphStyle(
            "bullet", parent=base["Normal"], fontName="Helvetica",
            fontSize=9.2, textColor=C_INK, leading=12.6,
        ),
        "step": ParagraphStyle(
            "step", parent=base["Normal"], fontName="Helvetica",
            fontSize=9.3, textColor=C_INK, leading=12.8, leftIndent=4,
        ),
        "callout": ParagraphStyle(
            "callout", parent=base["Normal"], fontName="Helvetica",
            fontSize=9, textColor=C_INK, leading=12.5,
        ),
        "toc": ParagraphStyle(
            "toc", parent=base["Normal"], fontName="Helvetica",
            fontSize=10, textColor=C_INK, leading=15, spaceAfter=2,
        ),
        "cell": ParagraphStyle(
            "cell", parent=base["Normal"], fontName="Helvetica",
            fontSize=8, textColor=C_INK, leading=10.5,
        ),
        "cell_b": ParagraphStyle(
            "cell_b", parent=base["Normal"], fontName="Helvetica-Bold",
            fontSize=8, textColor=C_INK, leading=10.5,
        ),
    }


S = styles()


def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(C_LINE)
    canvas.line(18 * mm, 14 * mm, A4[0] - 18 * mm, 14 * mm)
    canvas.setFont("Helvetica", 7.5)
    canvas.setFillColor(C_MUTED)
    canvas.drawString(18 * mm, 9 * mm, f"HealthFit · Guia do Usuário v{VERSION}")
    canvas.drawRightString(A4[0] - 18 * mm, 9 * mm, f"{TODAY}  ·  {doc.page}")
    canvas.restoreState()


def bullets(items):
    return ListFlowable(
        [ListItem(Paragraph(i, S["bullet"]), leftIndent=8, bulletColor=C_GREEN) for i in items],
        bulletType="bullet",
        start="•",
        leftIndent=12,
        spaceBefore=2,
        spaceAfter=8,
    )


def steps(items):
    flow = []
    for i, text in enumerate(items, 1):
        flow.append(Paragraph(f"<b>{i}.</b>  {text}", S["step"]))
    flow.append(Spacer(1, 4))
    return flow


def callout(text: str):
    t = Table([[Paragraph(text, S["callout"])]], colWidths=[170 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), C_SOFT),
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
    cmds = [
        ("BACKGROUND", (0, 0), (-1, 0), colors.Color(0.93, 0.97, 0.94)),
        ("GRID", (0, 0), (-1, -1), 0.4, C_LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]
    for i in range(1, len(body) + 1):
        if i % 2 == 0:
            cmds.append(("BACKGROUND", (0, i), (-1, i), colors.Color(0.98, 0.99, 0.98)))
    t.setStyle(TableStyle(cmds))
    return t


def section(story, n: str, title: str):
    story.append(Paragraph(f"{n}. {title}", S["h1"]))
    story.append(HRFlowable(width="100%", thickness=1.6, color=C_GREEN, spaceAfter=8))


def build():
    story = []

    # Cover
    cover = Table([[
        Paragraph("GUIA DO USUÁRIO · COMO USAR O APP", S["cover_badge"]),
    ], [
        Paragraph("HealthFit", S["cover_title"]),
    ], [
        Paragraph(
            "Passo a passo das principais funções: treinos, nutrição com foto, "
            "IAssistente, Dupla/equipe, Apple Watch e planos.",
            S["cover_sub"],
        ),
    ], [
        Paragraph(
            f"<b>Versão do guia:</b> {VERSION}<br/>"
            f"<b>Atualizado em:</b> {TODAY}<br/>"
            f"<b>Plataformas:</b> iPhone (iOS 17+) · Apple Watch (watchOS 10+)<br/>"
            f"<b>Idade mínima:</b> 16 anos<br/>"
            f"<b>Idioma padrão:</b> Português (Brasil)",
            S["cover_meta"],
        ),
    ]], colWidths=[170 * mm])
    cover.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), C_BG),
        ("TOPPADDING", (0, 0), (-1, 0), 50),
        ("LEFTPADDING", (0, 0), (-1, -1), 22),
        ("RIGHTPADDING", (0, 0), (-1, -1), 22),
        ("BOTTOMPADDING", (0, -1), (-1, -1), 42),
        ("TOPPADDING", (0, 1), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -2), 6),
        ("ROUNDEDCORNERS", [8, 8, 8, 8]),
    ]))
    story.append(Spacer(1, 16 * mm))
    story.append(cover)
    story.append(PageBreak())

    # TOC
    section(story, "0", "Sumário")
    for line in [
        "1. Primeiros passos (conta e permissões)",
        "2. Navegação — as 5 abas",
        "3. Início (Dashboard, HealthKit, relatórios)",
        "4. Treinos (musculação, cardio, modalidades, luta, escalada)",
        "5. Nutrição (plano, cardápio, suplementos, foto com IA)",
        "6. IAssistente",
        "7. Dupla / equipe",
        "8. Perfil, planos e Apple Watch",
        "9. Notificações e dicas rápidas",
        "10. Planos e o que cada um libera",
    ]:
        story.append(Paragraph(line, S["toc"]))
    story.append(PageBreak())

    # 1
    section(story, "1", "Primeiros passos")
    story.append(Paragraph(
        "Baixe o HealthFit na App Store, abra o app e escolha criar conta ou entrar "
        "com e-mail, Google ou Apple. No cadastro informe nome, e-mail, senha forte, "
        "biotipo, objetivo e data de nascimento (mínimo 16 anos).",
        S["body"],
    ))
    story.append(Paragraph("Permissões recomendadas", S["h2"]))
    story.extend(steps([
        "Permitir <b>Saúde (HealthKit)</b> para passos, frequência cardíaca, calorias e sono.",
        "Permitir <b>Notificações</b> para lembretes de treino, água, refeições e Dupla.",
        "No treino ao ar livre, permitir <b>Localização</b> quando o app pedir (corrida/caminhada).",
        "Para análise de refeição, permitir <b>Câmera</b> ou acesso à Galeria.",
    ]))
    story.append(callout(
        "<b>Dica:</b> após o login, complete peso, altura e gênero no Perfil — "
        "o cardápio e as metas calóricas ficam mais precisos."
    ))
    story.append(Spacer(1, 6))

    # 2
    section(story, "2", "Navegação — as 5 abas")
    story.append(nice_table(
        ["Aba", "Para que serve"],
        [
            ["Início", "Resumo do dia, HealthKit, relatórios semanal/mensal"],
            ["Treinos", "Musculação, cardio, meditação, esportes e Dupla"],
            ["Nutrição", "Plano alimentar, cardápio, suplementos e foto da refeição"],
            ["IAssistente", "Chat de orientação local sobre treino, sono e recuperação"],
            ["Perfil", "Dados, fotos, planos, idioma, exclusão de conta"],
        ],
        [40 * mm, 130 * mm],
    ))

    # 3
    section(story, "3", "Início")
    story.append(Paragraph(
        "O Dashboard mostra o estado geral: atividade, check-ins e atalhos. "
        "Puxe para atualizar dados do HealthKit. Use os relatórios semanal e mensal "
        "para acompanhar evolução.",
        S["body"],
    ))
    story.append(Paragraph("Fluxo típico do dia", S["h2"]))
    story.extend(steps([
        "Abra o app e responda o check-in de sono, se aparecer.",
        "Confira o resumo no Início.",
        "Vá em Treinos ou Nutrição conforme a prioridade do dia.",
        "No fim da semana, abra o Relatório Semanal.",
    ]))

    # 4
    section(story, "4", "Treinos")
    story.append(Paragraph("Musculação", S["h2"]))
    story.extend(steps([
        "Aba <b>Treinos</b> → escolha o hub masculino ou feminino (ou treino em casa / mobilidade).",
        "Abra uma ficha recomendada ou crie a sua (plano Fit+).",
        "Toque em iniciar, registre séries/reps e use o timer de descanso.",
        "Finalize e salve o resumo — ele entra no histórico e nos relatórios.",
    ]))
    story.append(Paragraph("Cardio e modalidades", S["h2"]))
    story.append(Paragraph(
        "Em Cardio você encontra corrida, caminhada, bike, natação, esteira (sem GPS), "
        "surf, kite, remo, escalada e luta. Modalidades avançadas pedem plano Fit. "
        "Diários e análises profundas (evolução por grau, volume etc.) pedem plano IA Plus.",
        S["body"],
    ))
    story.append(bullets([
        "<b>Luta:</b> hub com cronômetro de combate e registro de sessão.",
        "<b>Escalada:</b> setup com clima/motion, mapa de áreas e diário de vias/equipamento.",
        "<b>Meditação:</b> escolha o tema, inicie a sessão e acompanhe no histórico.",
    ]))

    # 5
    section(story, "5", "Nutrição")
    story.append(Paragraph(
        "A aba Nutrição tem quatro modos: <b>Plano</b>, <b>Cardápio</b>, <b>Suplementos</b> e <b>Análise</b>. "
        "Cardápio e lista de compras liberam a partir do plano Fit. "
        "A análise por foto é recurso do plano <b>IA Plus</b>.",
        S["body"],
    ))
    story.append(Paragraph("Montar o cardápio", S["h2"]))
    story.extend(steps([
        "Ajuste biotipo, objetivo e preferências (ex.: lactose, doces).",
        "No modo Cardápio, selecione opções até o app estar pronto para gerar a semana.",
        "No modo Plano, veja as refeições do dia e troque opções quando quiser.",
        "Use o ícone do carrinho para abrir a lista de compras.",
    ]))
    story.append(Paragraph("Análise de refeição por foto (IA Plus)", S["h2"]))
    story.extend(steps([
        "Abra Nutrição → <b>Análise</b> (a foto aparece no topo da tela).",
        "Toque para tirar foto do prato ou do rótulo nutricional (ou escolha da galeria).",
        "Selecione o tipo de refeição (café, almoço, etc.).",
        "Revise macros estimados, ajuste a porção se necessário e salve.",
        "A foto é usada só na análise e depois descartada — ficam os macros.",
    ]))
    story.append(callout(
        "<b>Privacidade:</b> a análise prioriza leitura de tabela nutricional no rótulo; "
        "se não houver, estima pelo visual. Não há envio da imagem para treinar modelos externos no fluxo padrão do app."
    ))
    story.append(PageBreak())

    # 6
    section(story, "6", "IAssistente")
    story.append(Paragraph(
        "O IAssistente responde com regras locais no aparelho (não é um chat cloud genérico). "
        "Pergunte sobre treino, sono, recuperação, cardio e hábitos. "
        "Plano Fit: até 5 mensagens/dia. Planos IA Plus e Completo: ilimitado "
        "(quando os bloqueios por plano estiverem ativos).",
        S["body"],
    ))
    story.append(bullets([
        "Seja específico: “fiz peito ontem, o que treinar hoje?”",
        "Mencione restrições (lesão, tempo curto, só em casa).",
        "Use o assistente depois do treino para check-in e ajustes.",
    ]))

    # 7
    section(story, "7", "Dupla / equipe")
    story.append(Paragraph(
        "Crie ou entre em uma equipe na área de Dupla/equipe (Treinos). "
        "Convide por código/link, aceite o consentimento e converse no chat. "
        "Mensagens recentes ficam disponíveis por cerca de 12 horas no histórico ativo do chat. "
        "Não há compartilhamento de GPS ao vivo entre membros.",
        S["body"],
    ))
    story.extend(steps([
        "Crie a equipe e defina o nome.",
        "Envie o convite ao parceiro(a).",
        "Aceite o termo/consentimento da Dupla.",
        "Use o chat para combinar treinos; toque na notificação abre o chat direto.",
    ]))

    # 8
    section(story, "8", "Perfil, planos e Apple Watch")
    story.append(Paragraph("Perfil", S["h2"]))
    story.append(bullets([
        "Atualize peso, altura, idade, gênero e país.",
        "Adicione foto de perfil e fundo.",
        "Cadastre e-mail do nutricionista para enviar relatório.",
        "Em Meu plano: assinar, restaurar compras ou gerenciar assinatura.",
        "Exclusão de conta remove dados conforme os Termos.",
    ]))
    story.append(Paragraph("Apple Watch", S["h2"]))
    story.append(Paragraph(
        "Instale o app HealthFit no Watch. Com o iPhone próximo, a sessão de treino "
        "pode espelhar batimentos e calorias. Mantenha Bluetooth e Watch desbloqueados.",
        S["body"],
    ))

    # 9
    section(story, "9", "Notificações e dicas rápidas")
    story.append(bullets([
        "Água: lembretes periódicos ao longo do dia.",
        "Refeições e suplementos: conforme seu plano/preferências.",
        "Inatividade de treino/cardio/meditação: lembretes para retomar.",
        "Dupla: novas mensagens podem chegar como push (com FCM/APNs configurados).",
        "Live Activity: progresso do treino na tela de bloqueio (quando disponível).",
    ]))
    story.append(callout(
        "<b>Problemas comuns:</b> dados de saúde zerados → revise permissões do HealthKit. "
        "Watch sem métricas → abra o app no relógio e confira o pareamento. "
        "Foto não analisa → use boa iluminação ou foto nítida do rótulo."
    ))

    # 10
    section(story, "10", "Planos e liberação de funções")
    story.append(nice_table(
        ["Plano", "Libera"],
        [
            ["Gratuito", "Dashboard, check-ins, treinos limitados"],
            ["Básico", "Treinos guiados, cardio clássico, Apple Watch"],
            ["Fit", "Modalidades avançadas, treinos custom, cardápio + lista, IA 5 msgs/dia"],
            ["IA Plus", "IA ilimitada, foto de refeição, diários/análises, relatório mensal, evolução corporal"],
            ["Completo", "Tudo liberado + prioridade"],
        ],
        [32 * mm, 138 * mm],
    ))
    story.append(Paragraph(
        "Os bloqueios por plano podem estar desligados em soft launch (tudo liberado para testes). "
        "Quando ativos, telas premium mostram o paywall com upgrade sugerido. "
        "Sempre use Restaurar compras se reinstalar o app.",
        S["body"],
    ))
    story.append(Spacer(1, 10))
    story.append(Paragraph(
        "Suporte e legais: abra Perfil ou visite as páginas públicas de Privacidade, Termos e Suporte do HealthFit.",
        S["body"],
    ))

    doc = SimpleDocTemplate(
        str(OUT_PDF),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=16 * mm,
        bottomMargin=18 * mm,
        title="HealthFit — Guia do Usuário",
        author="HealthFit",
    )
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(f"Wrote {OUT_PDF}")


if __name__ == "__main__":
    build()
