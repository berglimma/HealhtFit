#!/usr/bin/env python3
"""Gera MP4 mínimos válidos para upload de teste no Firebase Storage."""

from pathlib import Path

# MP4 mínimo (ftyp + mdat) — válido para players e Storage.
MINIMAL_MP4 = bytes([
    0x00, 0x00, 0x00, 0x1C, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D,
    0x00, 0x00, 0x02, 0x00, 0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
    0x61, 0x76, 0x63, 0x31, 0x6D, 0x70, 0x34, 0x31, 0x00, 0x00, 0x00, 0x08,
    0x6D, 0x64, 0x61, 0x74, 0x00, 0x00, 0x00, 0x00,
])

GROUPS = [
    "peito",
    "costas",
    "pernas",
    "ombros",
    "bracos",
    "abdomen",
    "corpo_inteiro",
]

ROOT = Path(__file__).resolve().parent.parent
GROUPS_DIR = ROOT / "videos" / "groups"
BUNDLE_DIR = ROOT / "HealthFit" / "HealthFit" / "HealthFit" / "Resources" / "ExerciseVideos"


def main() -> None:
    GROUPS_DIR.mkdir(parents=True, exist_ok=True)
    BUNDLE_DIR.mkdir(parents=True, exist_ok=True)

    for slug in GROUPS:
        for target_dir in (GROUPS_DIR, BUNDLE_DIR):
            path = target_dir / f"{slug}.mp4"
            path.write_bytes(MINIMAL_MP4)
            print(f"criado: {path} ({len(MINIMAL_MP4)} bytes)")

    print("\nPróximo passo: ./scripts/upload_exercise_videos.sh")


if __name__ == "__main__":
    main()
