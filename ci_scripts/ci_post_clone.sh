#!/bin/sh
set -euo pipefail

# Xcode Cloud — roda após o clone, antes do resolve/build.
# Problema comum neste repo: GoogleService-Info.plist está no .gitignore
# e o target referencia o arquivo em Copy Bundle Resources.

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
PLIST_DIR="$REPO_ROOT/HealthFit/HealthFit/HealthFit"
PLIST_PATH="$PLIST_DIR/GoogleService-Info.plist"
EXAMPLE_PATH="$PLIST_DIR/GoogleService-Info.plist.example"

echo "[ci_post_clone] repo=$REPO_ROOT"

if [ -n "${CI_GOOGLE_SERVICE_INFO_BASE64:-}" ]; then
  echo "[ci_post_clone] Gerando GoogleService-Info.plist a partir do secret CI_GOOGLE_SERVICE_INFO_BASE64."
  printf '%s' "$CI_GOOGLE_SERVICE_INFO_BASE64" | base64 --decode > "$PLIST_PATH"
elif [ -f "$PLIST_PATH" ]; then
  echo "[ci_post_clone] GoogleService-Info.plist já existe no clone."
else
  echo "[ci_post_clone] ERRO: GoogleService-Info.plist ausente. Não usar .example na App Store."
  exit 1
fi

if grep -q 'REPLACE_ME' "$PLIST_PATH"; then
  echo "[ci_post_clone] ERRO: GoogleService-Info.plist ainda é o placeholder. O login da App Store fica sem Firebase."
  exit 1
fi

# Confirma caminho do projeto aninhado (ajuda a diagnosticar workflow mal configurado).
if [ ! -d "$REPO_ROOT/HealthFit/HealthFit/HealthFit.xcodeproj" ]; then
  echo "[ci_post_clone] ERRO: projeto não encontrado em HealthFit/HealthFit/HealthFit.xcodeproj"
  exit 1
fi

echo "[ci_post_clone] OK — projeto e GoogleService-Info prontos."
