#!/usr/bin/env python3
"""Gera vídeos curtos explicativos (slides MP4) + roteiros em Markdown."""

from __future__ import annotations

from pathlib import Path

import imageio.v2 as imageio
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
OUT_DIR = ROOT / "videos"
W, H = 1280, 720
FPS = 30
BG = (14, 22, 20)
CARD = (28, 36, 34)
GREEN = (51, 217, 46)
WHITE = (245, 250, 247)
MUTED = (170, 186, 178)
ACCENT_SOFT = (30, 60, 45)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def wrap(draw: ImageDraw.ImageDraw, text: str, fnt, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = f"{current} {word}".strip()
        if draw.textlength(trial, font=fnt) <= max_width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines or [""]


def make_slide(title: str, subtitle: str, bullets: list[str], badge: str) -> Image.Image:
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)

    # left accent bar
    draw.rectangle([0, 0, 18, H], fill=GREEN)

    # header badge
    f_badge = font(22, bold=True)
    draw.rounded_rectangle([48, 40, 420, 88], radius=20, fill=ACCENT_SOFT, outline=GREEN, width=2)
    draw.text((68, 52), badge, font=f_badge, fill=GREEN)

    f_title = font(54, bold=True)
    f_sub = font(28)
    f_bullet = font(30)
    f_brand = font(20, bold=True)

    draw.text((48, 120), title, font=f_title, fill=WHITE)
    sub_lines = wrap(draw, subtitle, f_sub, W - 120)
    y = 200
    for line in sub_lines:
        draw.text((48, y), line, font=f_sub, fill=MUTED)
        y += 36

    # bullets card
    card_top = max(y + 24, 300)
    draw.rounded_rectangle([48, card_top, W - 48, H - 70], radius=24, fill=CARD)
    by = card_top + 36
    for item in bullets:
        for line in wrap(draw, f"•  {item}", f_bullet, W - 160):
            draw.text((80, by), line, font=f_bullet, fill=WHITE)
            by += 42
        by += 8

    draw.text((48, H - 48), "HealthFit · Como usar", font=f_brand, fill=MUTED)
    draw.text((W - 220, H - 48), "iPhone · Watch", font=f_brand, fill=MUTED)
    return img


def fade_frames(a: Image.Image, b: Image.Image, frames: int) -> list[np.ndarray]:
    out = []
    arr_a = np.asarray(a).astype(np.float32)
    arr_b = np.asarray(b).astype(np.float32)
    for i in range(frames):
        t = (i + 1) / (frames + 1)
        mixed = (arr_a * (1 - t) + arr_b * t).astype(np.uint8)
        out.append(mixed)
    return out


def hold(img: Image.Image, seconds: float) -> list[np.ndarray]:
    arr = np.asarray(img)
    return [arr for _ in range(int(seconds * FPS))]


VIDEOS = [
    {
        "file": "01_visao_geral.mp4",
        "title_pt": "Visão geral do HealthFit",
        "slides": [
            ("HealthFit", "Seu personal trainer no iPhone e Apple Watch", [
                "Cinco abas: Início, Treinos, Nutrição, IAssistente, Perfil",
                "Idade mínima: 16 anos",
                "Conta com e-mail, Google ou Apple",
            ], "EP 01 · VISÃO GERAL"),
            ("Comece em 1 minuto", "Permissões que fazem diferença", [
                "HealthKit para passos, FC e sono",
                "Notificações para água, treino e Dupla",
                "Complete peso/altura no Perfil",
            ], "EP 01 · VISÃO GERAL"),
            ("Fluxo do dia", "Rotina sugerida", [
                "Check-in de sono ao abrir",
                "Treino ou cardio na aba Treinos",
                "Nutrição e foto da refeição (IA Plus)",
            ], "EP 01 · VISÃO GERAL"),
        ],
    },
    {
        "file": "02_treinos.mp4",
        "title_pt": "Treinos e modalidades",
        "slides": [
            ("Treinos", "Musculação, cardio e esportes", [
                "Hub masculino/feminino e treino em casa",
                "Inicie a ficha e registre séries",
                "Timer de descanso e resumo final",
            ], "EP 02 · TREINOS"),
            ("Cardio & esportes", "Do clássico ao avançado", [
                "Corrida, bike, natação, esteira",
                "Surf, kite, remo, escalada e luta (Fit)",
                "Diários e análises profundas (IA Plus)",
            ], "EP 02 · TREINOS"),
            ("Apple Watch", "Treino no pulso", [
                "Instale o app no Watch",
                "Batimentos e calorias na sessão",
                "Mantenha o iPhone próximo",
            ], "EP 02 · TREINOS"),
        ],
    },
    {
        "file": "03_nutricao.mp4",
        "title_pt": "Nutrição e foto com IA",
        "slides": [
            ("Nutrição", "Plano, cardápio e suplementos", [
                "Ajuste biotipo, objetivo e preferências",
                "Gere o cardápio da semana (Fit)",
                "Lista de compras no ícone do carrinho",
            ], "EP 03 · NUTRIÇÃO"),
            ("Análise por foto", "Recurso do plano IA Plus", [
                "Aba Nutrição → Análise",
                "Foto do prato ou do rótulo no topo",
                "Revise macros, ajuste porção e salve",
            ], "EP 03 · NUTRIÇÃO"),
            ("Privacidade", "O que é guardado", [
                "A foto é descartada após a análise",
                "Só macros e metadados ficam salvos",
                "Rótulo nutricional tem prioridade na leitura",
            ], "EP 03 · NUTRIÇÃO"),
        ],
    },
    {
        "file": "04_iassistente.mp4",
        "title_pt": "IAssistente",
        "slides": [
            ("IAssistente", "Orientação local no aparelho", [
                "Pergunte sobre treino, sono e recuperação",
                "Respostas por regras locais (sem LLM cloud)",
                "Seja específico na pergunta",
            ], "EP 04 · IA"),
            ("Limites por plano", "Quanto você pode conversar", [
                "Fit: até 5 mensagens por dia",
                "IA Plus / Completo: ilimitado",
                "Upgrade no Perfil → Meu plano",
            ], "EP 04 · IA"),
        ],
    },
    {
        "file": "05_dupla_equipe.mp4",
        "title_pt": "Dupla e equipe",
        "slides": [
            ("Dupla / equipe", "Treine acompanhado", [
                "Crie a equipe e convide o parceiro",
                "Aceite o consentimento da Dupla",
                "Chat para combinar treinos",
            ], "EP 05 · DUPLA"),
            ("Notificações", "Não perca a mensagem", [
                "Toque no push abre o chat",
                "Sem GPS ao vivo entre membros",
                "Histórico recente do chat (~12h)",
            ], "EP 05 · DUPLA"),
        ],
    },
    {
        "file": "06_planos.mp4",
        "title_pt": "Planos e assinaturas",
        "slides": [
            ("Planos HealthFit", "Liberação progressiva", [
                "Básico: treinos + Watch",
                "Fit: esportes + cardápio + IA limitada",
                "IA Plus: foto, diários e IA ilimitada",
            ], "EP 06 · PLANOS"),
            ("Assinar e restaurar", "Perfil → Meu plano", [
                "Mensal ou anual (economia no anual)",
                "Restaurar compras após reinstalar",
                "Gerenciar assinatura na App Store",
            ], "EP 06 · PLANOS"),
        ],
    },
]


def render_video(spec: dict) -> Path:
    slides = [make_slide(*s) for s in spec["slides"]]
    frames: list[np.ndarray] = []
    for i, slide in enumerate(slides):
        if i > 0:
            frames.extend(fade_frames(slides[i - 1], slide, frames=12))
        frames.extend(hold(slide, 3.6 if i < len(slides) - 1 else 4.2))

    out = OUT_DIR / spec["file"]
    imageio.mimsave(out, frames, fps=FPS, codec="libx264", quality=7, pixelformat="yuv420p")
    return out


def write_scripts():
    lines = [
        "# Roteiros — vídeos explicativos HealthFit",
        "",
        "Use estes roteiros para gravar demos reais no iPhone (melhor retenção na App Store / redes).",
        "Os MP4 em `Docs/videos/` são versões slide geradas automaticamente.",
        "",
    ]
    for i, spec in enumerate(VIDEOS, 1):
        lines.append(f"## {i}. {spec['title_pt']} (`{spec['file']}`)")
        lines.append("")
        lines.append("| Tempo | Narração sugerida | Tela a mostrar |")
        lines.append("|------|-------------------|----------------|")
        for j, (title, subtitle, bullets, _) in enumerate(spec["slides"], 1):
            narr = f"**{title}.** {subtitle}. " + " ".join(bullets)
            lines.append(f"| ~{(j-1)*8}-{(j)*8}s | {narr} | Abrir fluxo correspondente no app |")
        lines.append("")
        lines.append("**CTA final:** Baixe o HealthFit e comece pelo Perfil (peso/altura) + primeira ficha de treino.")
        lines.append("")
    (OUT_DIR / "ROTEIROS.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write_scripts()
    paths = []
    for spec in VIDEOS:
        path = render_video(spec)
        paths.append(path)
        print(f"Wrote {path}")
    print(f"Scripts: {OUT_DIR / 'ROTEIROS.md'}")
    print(f"Total videos: {len(paths)}")


if __name__ == "__main__":
    main()
