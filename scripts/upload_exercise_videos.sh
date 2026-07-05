#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_ID="${FIREBASE_PROJECT_ID:-healthfit-30d87}"
PLIST_PATH="${GOOGLE_SERVICE_INFO_PLIST:-$ROOT_DIR/HealthFit/HealthFit/HealthFit/GoogleService-Info.plist}"
GROUPS_DIR="${VIDEOS_GROUPS_DIR:-$ROOT_DIR/videos/groups}"
EXERCISES_DIR="${VIDEOS_EXERCISES_DIR:-$ROOT_DIR/videos/exercises}"
STORAGE_PREFIX="exerciseVideos"
DRY_RUN=0
AUTO_YES=0

REQUIRED_GROUP_VIDEOS=(
  peito
  costas
  pernas
  ombros
  bracos
  abdomen
  corpo_inteiro
)

usage() {
  cat <<EOF
Uso: $(basename "$0") [opções]

Envia MP4 locais para Firebase Storage (Google Cloud Storage).

Opções:
  --dry-run          Lista o que seria enviado, sem upload
  --yes              Confirma upload automaticamente (sem prompt)
  --bucket NOME      Bucket GCS (padrão: lido do GoogleService-Info.plist)
  --groups DIR       Pasta com vídeos de grupo (padrão: videos/groups)
  --exercises DIR    Pasta com vídeos por exercício (padrão: videos/exercises)
  -h, --help         Mostra esta ajuda

Variáveis de ambiente:
  FIREBASE_PROJECT_ID, GOOGLE_SERVICE_INFO_PLIST,
  VIDEOS_GROUPS_DIR, VIDEOS_EXERCISES_DIR, GCS_BUCKET

Exemplo:
  ./scripts/upload_exercise_videos.sh
  ./scripts/upload_exercise_videos.sh --dry-run
EOF
}

log() {
  printf '==> %s\n' "$*"
}

warn() {
  printf '!!  %s\n' "$*" >&2
}

die() {
  printf 'Erro: %s\n' "$*" >&2
  exit 1
}

read_bucket_from_plist() {
  if [[ ! -f "$PLIST_PATH" ]]; then
    return 1
  fi

  if command -v plutil >/dev/null 2>&1; then
    plutil -extract STORAGE_BUCKET raw "$PLIST_PATH" 2>/dev/null && return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' "$PLIST_PATH"
import plistlib, sys
with open(sys.argv[1], "rb") as f:
    print(plistlib.load(f).get("STORAGE_BUCKET", ""))
PY
    return 0
  fi

  grep -A1 '<key>STORAGE_BUCKET</key>' "$PLIST_PATH" | tail -1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/'
}

parse_args() {
  GCS_BUCKET="${GCS_BUCKET:-}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --yes|-y)
        AUTO_YES=1
        shift
        ;;
      --bucket)
        [[ $# -ge 2 ]] || die "Opção --bucket requer um valor"
        GCS_BUCKET="$2"
        shift 2
        ;;
      --groups)
        [[ $# -ge 2 ]] || die "Opção --groups requer um caminho"
        GROUPS_DIR="$2"
        shift 2
        ;;
      --exercises)
        [[ $# -ge 2 ]] || die "Opção --exercises requer um caminho"
        EXERCISES_DIR="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Argumento desconhecido: $1 (use --help)"
        ;;
    esac
  done

  if [[ -z "$GCS_BUCKET" ]]; then
    GCS_BUCKET="$(read_bucket_from_plist || true)"
  fi

  if [[ -z "$GCS_BUCKET" ]]; then
    GCS_BUCKET="${PROJECT_ID}.firebasestorage.app"
    warn "STORAGE_BUCKET não encontrado; usando padrão: $GCS_BUCKET"
  fi
}

detect_upload_tool() {
  if [[ -n "${GCLOUD_ACCESS_TOKEN:-}" ]]; then
    UPLOAD_TOOL="curl"
    return 0
  fi

  if [[ -x "$HOME/google-cloud-sdk/bin/gcloud" ]]; then
    if CLOUDSDK_PYTHON="${CLOUDSDK_PYTHON:-}" "$HOME/google-cloud-sdk/bin/gcloud" version >/dev/null 2>&1; then
      UPLOAD_TOOL="gcloud"
      GCLOUD_BIN="$HOME/google-cloud-sdk/bin/gcloud"
      return 0
    fi
  fi

  if command -v gcloud >/dev/null 2>&1; then
    UPLOAD_TOOL="gcloud"
    GCLOUD_BIN="gcloud"
    return 0
  fi

  if command -v gsutil >/dev/null 2>&1; then
    UPLOAD_TOOL="gsutil"
    return 0
  fi

  return 1
}

urlencode_path() {
  python3 - <<'PY' "$1"
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1], safe=""))
PY
}

upload_file() {
  local local_file="$1"
  local remote_path="$2"
  local gs_uri="gs://${GCS_BUCKET}/${remote_path}"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '  [dry-run] %s -> %s\n' "$local_file" "$gs_uri"
    return 0
  fi

  case "$UPLOAD_TOOL" in
    curl)
      local encoded
      encoded="$(urlencode_path "$remote_path")"
      curl -fsS -X POST \
        "https://firebasestorage.googleapis.com/v0/b/${GCS_BUCKET}/o?uploadType=media&name=${encoded}" \
        -H "Authorization: Bearer ${GCLOUD_ACCESS_TOKEN}" \
        -H "Content-Type: video/mp4" \
        --data-binary @"$local_file" >/dev/null
      ;;
    gcloud)
      "${GCLOUD_BIN:-gcloud}" storage cp "$local_file" "$gs_uri" \
        --content-type=video/mp4 \
        --cache-control="public,max-age=3600"
      ;;
    gsutil)
      gsutil -h "Content-Type:video/mp4" \
        -h "Cache-Control:public,max-age=3600" \
        cp "$local_file" "$gs_uri"
      ;;
  esac
}

collect_uploads() {
  UPLOAD_PLAN=()

  for slug in "${REQUIRED_GROUP_VIDEOS[@]}"; do
    local_file="$GROUPS_DIR/${slug}.mp4"
    remote_path="${STORAGE_PREFIX}/groups/${slug}.mp4"
    if [[ -f "$local_file" ]]; then
      UPLOAD_PLAN+=("$local_file|$remote_path")
    else
      MISSING_GROUP_VIDEOS+=("$slug.mp4")
    fi
  done

  if [[ -d "$EXERCISES_DIR" ]]; then
    shopt -s nullglob
    for local_file in "$EXERCISES_DIR"/*.mp4; do
      filename="$(basename "$local_file")"
      remote_path="${STORAGE_PREFIX}/exercises/${filename}"
      UPLOAD_PLAN+=("$local_file|$remote_path")
    done
    shopt -u nullglob
  fi
}

print_summary() {
  log "Projeto Firebase: $PROJECT_ID"
  log "Bucket GCS: gs://$GCS_BUCKET"
  log "Ferramenta: $UPLOAD_TOOL"
  log "Grupos: $GROUPS_DIR"
  log "Exercícios: $EXERCISES_DIR"
  echo

  if [[ ${#UPLOAD_PLAN[@]} -eq 0 ]]; then
    die "Nenhum MP4 encontrado para upload."
  fi

  log "Arquivos a enviar (${#UPLOAD_PLAN[@]}):"
  for entry in "${UPLOAD_PLAN[@]}"; do
    IFS='|' read -r local_file remote_path <<< "$entry"
    printf '  - %s -> gs://%s/%s\n' "$local_file" "$GCS_BUCKET" "$remote_path"
  done
  echo

  if [[ ${#MISSING_GROUP_VIDEOS[@]} -gt 0 ]]; then
    warn "Grupos obrigatórios ausentes (opcional enviar depois):"
    for name in "${MISSING_GROUP_VIDEOS[@]}"; do
      printf '  - %s/%s\n' "$GROUPS_DIR" "$name"
    done
    echo
  fi
}

main() {
  parse_args "$@"

  [[ -d "$GROUPS_DIR" ]] || die "Pasta não encontrada: $GROUPS_DIR"

  UPLOAD_PLAN=()
  MISSING_GROUP_VIDEOS=()
  collect_uploads

  if [[ "$DRY_RUN" -eq 1 ]]; then
    UPLOAD_TOOL="${UPLOAD_TOOL:-dry-run}"
    print_summary
    exit 0
  fi

  detect_upload_tool || die "Instale Google Cloud SDK ou defina GCLOUD_ACCESS_TOKEN. Veja videos/README.md"

  if [[ "$UPLOAD_TOOL" != "curl" ]]; then
    if ! "${GCLOUD_BIN:-gcloud}" auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | grep -q .; then
      die "Faça login primeiro: ${GCLOUD_BIN:-gcloud} auth login"
    fi
  fi

  print_summary

  if [[ "$AUTO_YES" -eq 0 ]]; then
    read -r -p "Confirmar upload? [s/N] " confirm
    if [[ ! "$confirm" =~ ^[sSyY]$ ]]; then
      log "Upload cancelado."
      exit 0
    fi
  fi

  uploaded=0
  for entry in "${UPLOAD_PLAN[@]}"; do
    IFS='|' read -r local_file remote_path <<< "$entry"
    log "Enviando $(basename "$local_file")..."
    upload_file "$local_file" "$remote_path"
    uploaded=$((uploaded + 1))
  done

  echo
  log "Upload concluído: $uploaded arquivo(s)."
  log "Console Storage: https://console.firebase.google.com/project/${PROJECT_ID}/storage"
  log "Abra o app logado para sincronizar o catálogo exerciseVideos no Firestore."
}

main "$@"
