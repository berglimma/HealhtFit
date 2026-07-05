#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_ID="healthfit-30d87"

echo "==> HealthFit — deploy Firebase (projeto: ${PROJECT_ID})"
echo "    Console: https://console.firebase.google.com/project/${PROJECT_ID}"

if ! command -v npx >/dev/null 2>&1; then
  echo "Erro: Node.js/npx não encontrado. Instale Node.js e tente novamente."
  exit 1
fi

echo "==> Publicando regras Firestore e Storage..."
npx --yes firebase-tools@latest deploy \
  --project "${PROJECT_ID}" \
  --only firestore:rules,storage \
  --non-interactive

echo ""
echo "Deploy concluído."
echo ""
echo "Próximos passos no Console:"
echo "  1. Authentication → habilitar E-mail/Senha, Google e Apple"
echo "  2. Firestore → verificar banco criado"
echo "  3. Storage → criar pasta exerciseVideos/groups/"
echo "  4. Upload dos MP4:"
echo "       Coloque os arquivos em videos/groups/ e rode:"
echo "       ./scripts/upload_exercise_videos.sh"
echo "     Ou envie manualmente: peito, costas, pernas, ombros, bracos, abdomen, corpo_inteiro"
echo "  5. Abrir o app logado para sincronizar exerciseVideos no Firestore"
