#!/usr/bin/env python3
"""Gera screenshots 6.7\" (1290×2796) estilo App Store para upload na Connect."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1] / "screenshots"
W, H = 1290, 2796  # iPhone 15 Pro Max / 6.7"
BG = (12, 18, 16)
CARD = (28, 36, 34)
GREEN = (51, 217, 46)
WHITE = (245, 250, 247)
MUTED = (160, 176, 168)
ORANGE = (255, 140, 51)

LOCALES = {
    "pt-BR": {
        "shots": [
            ("01_inicio.png", "Início", "Seu painel de evolução", ["Passos e calorias", "Check-in de sono", "Relatório semanal"]),
            ("02_treinos.png", "Treinos", "Musculação, cardio e esportes", ["Fichas guiadas", "Luta e escalada", "Apple Watch"]),
            ("03_treino_ativo.png", "Treino ativo", "Série a série, com timer", ["Descanso inteligente", "GIFs de execução", "Resumo ao final"]),
            ("04_nutricao.png", "Nutrição", "Cardápio e metas calóricas", ["Plano da semana", "Lista de compras", "Suplementos"]),
            ("05_iassistente.png", "IAssistente", "Orientação no dia a dia", ["Treino e recuperação", "Sono e hábitos", "Regras locais no iPhone"]),
            ("06_watch_corrida.png", "Watch + Corrida", "Métricas no pulso e no mapa", ["FC e calorias", "GPS na corrida", "HealthKit"]),
        ]
    },
    "en-US": {
        "shots": [
            ("01_home.png", "Home", "Your progress dashboard", ["Steps & calories", "Sleep check-in", "Weekly report"]),
            ("02_workouts.png", "Workouts", "Strength, cardio & sports", ["Guided plans", "Fight & climbing", "Apple Watch"]),
            ("03_active.png", "Active workout", "Set by set with rest timer", ["Smart rest", "Form GIFs", "Summary"]),
            ("04_nutrition.png", "Nutrition", "Meal plan & calorie goals", ["Weekly menu", "Shopping list", "Supplements"]),
            ("05_assistant.png", "AI Assistant", "Guidance every day", ["Training & recovery", "Sleep & habits", "On-device rules"]),
            ("06_watch_run.png", "Watch + Run", "Metrics on wrist and map", ["HR & calories", "Outdoor GPS", "HealthKit"]),
        ]
    },
    "es-ES": {
        "shots": [
            ("01_inicio.png", "Inicio", "Tu panel de evolución", ["Pasos y calorías", "Check-in de sueño", "Informe semanal"]),
            ("02_entrenos.png", "Entrenos", "Fuerza, cardio y deportes", ["Planes guiados", "Lucha y escalada", "Apple Watch"]),
            ("03_activo.png", "Entreno activo", "Serie a serie con timer", ["Descanso", "GIFs", "Resumen"]),
            ("04_nutricion.png", "Nutrición", "Menú y metas calóricas", ["Plan semanal", "Lista de compras", "Suplementos"]),
            ("05_asistente.png", "IAsistente", "Orientación diaria", ["Entreno y recuperación", "Sueño", "En el iPhone"]),
            ("06_watch.png", "Watch + Carrera", "Métricas en pulso y mapa", ["FC y calorías", "GPS", "HealthKit"]),
        ]
    },
    "fr-FR": {
        "shots": [
            ("01_accueil.png", "Accueil", "Votre tableau de progrès", ["Pas et calories", "Check-in sommeil", "Rapport hebdo"]),
            ("02_seances.png", "Séances", "Force, cardio et sports", ["Plans guidés", "Combat et escalade", "Apple Watch"]),
            ("03_actif.png", "Séance active", "Série par série avec timer", ["Repos", "GIFs", "Résumé"]),
            ("04_nutrition.png", "Nutrition", "Menu et objectifs", ["Plan semaine", "Courses", "Compléments"]),
            ("05_assistant.png", "IAssistant", "Conseils au quotidien", ["Entraînement", "Sommeil", "Sur l’iPhone"]),
            ("06_watch.png", "Watch + Course", "Mesures au poignet", ["FC et calories", "GPS", "HealthKit"]),
        ]
    },
}


def font(size: int, bold: bool = False):
    paths = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def wrap(draw, text, fnt, max_w):
    words = text.split()
    lines, cur = [], ""
    for w in words:
        t = f"{cur} {w}".strip()
        if draw.textlength(t, font=fnt) <= max_w:
            cur = t
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines or [""]


def make_shot(title: str, subtitle: str, bullets: list[str], index: int) -> Image.Image:
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)

    # status bar fake
    draw.text((60, 70), "9:41", font=font(34, True), fill=WHITE)
    draw.text((W - 180, 70), "5G  ●●●", font=font(28), fill=MUTED)

    # brand
    draw.rounded_rectangle([60, 160, 320, 230], radius=28, fill=(30, 60, 45), outline=GREEN, width=3)
    draw.text((90, 175), "HealthFit", font=font(36, True), fill=GREEN)

    draw.text((60, 280), title, font=font(78, True), fill=WHITE)
    y = 400
    for line in wrap(draw, subtitle, font(42), W - 120):
        draw.text((60, y), line, font=font(42), fill=MUTED)
        y += 54

    # phone content card
    card_top = 560
    draw.rounded_rectangle([60, card_top, W - 60, H - 220], radius=40, fill=CARD)

    # tab bar preview
    tabs = ["Início", "Treinos", "Nutrição", "IA", "Perfil"]
    tab_y = H - 180
    for i, t in enumerate(tabs):
        x = 80 + i * 230
        color = GREEN if i == min(index, 4) else MUTED
        draw.ellipse([x + 40, tab_y, x + 70, tab_y + 30], fill=color)
        draw.text((x + 10, tab_y + 40), t, font=font(24), fill=color)

    by = card_top + 70
    draw.text((110, by), "HealthFit", font=font(36, True), fill=GREEN)
    by += 80
    for b in bullets:
        draw.rounded_rectangle([110, by, W - 110, by + 120], radius=24, fill=(20, 28, 26))
        draw.ellipse([140, by + 35, 190, by + 85], fill=GREEN if by == card_top + 150 else ORANGE)
        draw.text((220, by + 40), b, font=font(40, True), fill=WHITE)
        by += 150

    # footer legal-ish
    draw.text((60, H - 70), "App Store preview · iPhone 6.7\"", font=font(24), fill=MUTED)
    return img


def main():
    for loc, data in LOCALES.items():
        out = ROOT / loc / "iphone-6.7"
        out.mkdir(parents=True, exist_ok=True)
        # clean old readme-only note stays; write PNGs
        for i, (name, title, subtitle, bullets) in enumerate(data["shots"]):
            img = make_shot(title, subtitle, bullets, i)
            path = out / name
            img.save(path, format="PNG", optimize=True)
            print("wrote", path)
    (ROOT / "README.md").write_text(
        "# Screenshots HealthFit (6.7\")\n\n"
        "Gerados por `scripts/generate_appstore_screenshots.py`.\n\n"
        "Dimensão: **1290×2796** (iPhone 6.7\").\n\n"
        "Envie os PNGs de cada pasta `*/iphone-6.7/` na App Store Connect "
        "(pode reutilizar o set pt-BR nos outros idiomas se preferir).\n\n"
        "> Preferível substituir por capturas reais do Simulator antes do review final.\n",
        encoding="utf-8",
    )
    print("done")


if __name__ == "__main__":
    main()
