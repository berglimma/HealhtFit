#!/usr/bin/env python3
"""Upload dos MP4 de exercício para Firebase Storage via google-cloud-storage."""

from __future__ import annotations

import sys
from pathlib import Path

from google.cloud import storage

PROJECT_ID = "healthfit-30d87"
BUCKET_NAME = "healthfit-30d87.firebasestorage.app"
ROOT = Path(__file__).resolve().parent.parent
GROUPS_DIR = ROOT / "videos" / "groups"

GROUPS = [
    "peito",
    "costas",
    "pernas",
    "ombros",
    "bracos",
    "abdomen",
    "corpo_inteiro",
]


def main() -> int:
    missing = [f"{slug}.mp4" for slug in GROUPS if not (GROUPS_DIR / f"{slug}.mp4").exists()]
    if missing:
        print("Arquivos ausentes:", ", ".join(missing))
        return 1

    try:
        client = storage.Client(project=PROJECT_ID)
        bucket = client.bucket(BUCKET_NAME)
    except Exception as error:  # noqa: BLE001
        print(f"Falha ao autenticar no Google Cloud: {error}")
        print("Execute: gcloud auth application-default login")
        print("Ou defina GOOGLE_APPLICATION_CREDENTIALS com uma service account.")
        return 1

    uploaded = 0
    for slug in GROUPS:
        local_path = GROUPS_DIR / f"{slug}.mp4"
        remote_path = f"exerciseVideos/groups/{slug}.mp4"
        blob = bucket.blob(remote_path)
        blob.upload_from_filename(str(local_path), content_type="video/mp4")
        print(f"enviado: {remote_path}")
        uploaded += 1

    print(f"\nConcluído: {uploaded} arquivo(s).")
    print(f"Console: https://console.firebase.google.com/project/{PROJECT_ID}/storage")
    return 0


if __name__ == "__main__":
    sys.exit(main())
