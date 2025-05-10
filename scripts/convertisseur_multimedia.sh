#!/usr/bin/env bash
# scripts/convertisseur_multimedia.sh
set -euo pipefail

### Initialisation ###
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/deps_check.sh"  # vérifie ffmpeg, inotifywait, convert
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/logging.sh"
source "$PROJECT_ROOT/lib/backup.sh"
source "$PROJECT_ROOT/lib/conversion.sh"

# Options par defaut
FORK=false; THREADS=false; SUBSHELL=false; RESTORE=false
THREAD_COUNT=0; CUSTOM_LOG_DIR=""

usage() {
  cat <<EOF
Usage: $0 [options] <répertoire_source>
  -h              Aide
  -f              Mode fork
  -t              Mode threads
  -s              Mode subshell
  -j <n>          Nombre de threads (si -t)
  -l <rép_logs>   Répertoire de logs
  -r              Restaurer la dernière sauvegarde
EOF
}

while getopts "hftsrl:j:" opt; do
  case $opt in
    h) usage; exit 0 ;;
    f) FORK=true ;;
    t) THREADS=true ;;
    s) SUBSHELL=true ;;
    j) THREAD_COUNT=$OPTARG ;;
    l) CUSTOM_LOG_DIR=$OPTARG ;;
    r) RESTORE=true ;;
    *) usage; exit 1 ;;
  esac
done
shift $((OPTIND-1))

[ $# -ge 1 ] || { echo "Source manquante."; usage; exit 1; }
SOURCE_DIR="$1"

# Logs, backup, output
LOG_DIR="${CUSTOM_LOG_DIR:-/var/log/convertisseur_multimedia}"
init_logging
BACKUP_ROOT="$PROJECT_ROOT/backup"
OUTPUT_DIR="$PROJECT_ROOT/output"
ensure_dir "$BACKUP_ROOT" "$OUTPUT_DIR"

# Restauration si demandé
if [ "$RESTORE" = true ]; then
  LAST=$(ls -dt "$BACKUP_ROOT"/*/ | head -n1)
  [ -n "$LAST" ] || { log_error "Aucune sauvegarde."; exit 1; }
  cp -r "$LAST"* "$SOURCE_DIR"/
  log_info "Restauration depuis $LAST"
  exit 0
fi

# Organisation optionnelle
if ask_yes_no "Organiser par type ?"; then
  log_info "Organisation..."
  WORK_DIR="$SOURCE_DIR/organized"
  rm -rf "$WORK_DIR"
  mkdir -p "$WORK_DIR"/{audio,video,images}
  find "$SOURCE_DIR" -maxdepth 1 -type f \( \
    -iname '*.mp3' -o -iname '*.wav' -o -iname '*.flac' \
    -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.avi' \
    -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.gif' \
  \) -exec bash -c '
    ext="${1##*.}"
    case "${ext,,}" in
      mp3|wav|flac) mv "$1" "$0/audio/";;
      mp4|mkv|avi)  mv "$1" "$0/video/";;
      *)            mv "$1" "$0/images/";;
    esac
  ' "$WORK_DIR" {} \;
else
  WORK_DIR="$SOURCE_DIR"
fi

# Sélection du dossier
CHOICE=$(select_option "Que convertir ?" "Tous" "Audio" "Vidéo" "Images")
case $CHOICE in
  Tous)   TARGET="$WORK_DIR"     ;;
  Audio)  TARGET="$WORK_DIR/audio"  ;;
  Vidéo)  TARGET="$WORK_DIR/video"  ;;
  Images) TARGET="$WORK_DIR/images" ;;
esac

# Mode merge ou non
MERGE=false
ask_yes_no "Fusionner tous en un seul ?" && MERGE=true

# Format de sortie
read -p "Format de sortie (mp4,mp3,jpg) : " OUT_EXT
OUT_EXT="${OUT_EXT#.}"

# Sauvegarde
init_backup "$BACKUP_ROOT"
backup_directory "$TARGET" "$SOURCE_DIR"

# Conversion
if [ "$MERGE" = true ]; then
  LIST=$(mktemp)
  for f in "$TARGET"/*; do [ -f "$f" ] && printf "file '%s'\n" "$f"; done > "$LIST"
  ffmpeg -f concat -safe 0 -i "$LIST" "$OUTPUT_DIR/merged.$OUT_EXT"
  rm -f "$LIST"
  log_info "Merge → $OUTPUT_DIR/merged.$OUT_EXT"
else
  if [ "$THREADS" = true ]; then
    # Appel au binaire C
    BIN="$PROJECT_ROOT/bin/thread_converter"
    [ -x "$BIN" ] || { log_error "thread_converter introuvable, compiler src/thread_converter.c"; exit 1; }
    N=${THREAD_COUNT:-$(nproc)}
    CMD=( "$BIN" -o "$OUTPUT_DIR" -e "$OUT_EXT" -j "$N" )
    for f in "$TARGET"/*; do [ -f "$f" ] && CMD+=( "$f" ); done
    log_info "Lancement threads ($N)..."
    "${CMD[@]}"
  else
    for f in "$TARGET"/*; do
      [ -f "$f" ] || continue
      base="${f##*/}"; name="${base%.*}"
      cmd=( ffmpeg -y -i "$f" "$OUTPUT_DIR/${name}.${OUT_EXT}" )
      if [ "$FORK" = true ]; then
        "${cmd[@]}" &
      elif [ "$SUBSHELL" = true ]; then
        ( "${cmd[@]}" )
      else
        "${cmd[@]}"
      fi
      log_info "Converti → $OUTPUT_DIR/${name}.${OUT_EXT}"
    done
    $FORK && wait
  fi
fi

log_info "Terminé. Résultats dans $OUTPUT_DIR"
