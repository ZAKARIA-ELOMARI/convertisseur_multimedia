#!/usr/bin/env bash
# scripts/convertisseur_multimedia.sh
# Script principal : surveillance, organisation, sauvegarde et conversion multimédia

set -euo pipefail

### Initialisation des chemins ###
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

### Chargement des modules ###
source "$SCRIPT_DIR/deps_check.sh"
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/logging.sh"
source "$PROJECT_ROOT/lib/backup.sh"
source "$PROJECT_ROOT/lib/conversion.sh"

### Variables par défaut ###
FORK=false
THREADS=false
SUBSHELL=false
RESTORE=false
THREAD_COUNT=0
CUSTOM_LOG_DIR=""

usage() {
  cat <<EOF
Usage: $0 [options] <répertoire_source>
Options :
  -h            Aide
  -f            Mode fork (background)
  -t            Mode threads (utilise bin/thread_converter)
  -s            Mode subshell
  -j <n>        Nombre de threads (avec -t)
  -l <chemin>   Répertoire de logs
  -r            Restaurer la dernière sauvegarde
EOF
}

### Lecture des options ###
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

### Vérifier l’argument <répertoire_source> ###
if [ $# -lt 1 ]; then
  echo "Erreur : pas de répertoire source." >&2
  usage
  exit 1
fi
SOURCE_DIR="$1"
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Erreur : répertoire introuvable : $SOURCE_DIR" >&2
  exit 1
fi

### Préparation des dossiers ###
LOG_DIR="${CUSTOM_LOG_DIR:-/var/log/convertisseur_multimedia}"
init_logging            # crée LOG_DIR et history.log
BACKUP_ROOT="$PROJECT_ROOT/backup"
OUTPUT_DIR="$PROJECT_ROOT/output"
ensure_dir "$BACKUP_ROOT" "$OUTPUT_DIR"

### Restauration si demandé ###
if [ "$RESTORE" = true ]; then
  LAST=$(ls -dt "$BACKUP_ROOT"/*/ 2>/dev/null | head -n1 || true)
  if [ -z "$LAST" ]; then
    log_error "Aucune sauvegarde à restaurer."
    exit 1
  fi
  cp -r "$LAST"* "$SOURCE_DIR"/
  log_info "Restauration effectuée depuis : $LAST"
  exit 0
fi

### Organisation optionnelle ###
if ask_yes_no "Organiser par type ?" "N"; then
  log_info "Organisation des fichiers dans $SOURCE_DIR/organized"
  WORK_DIR="$SOURCE_DIR/organized"
  rm -rf "$WORK_DIR"
  mkdir -p "$WORK_DIR"/{audio,video,images}
  find "$SOURCE_DIR" -maxdepth 1 -type f \
    \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" \
       -o -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" \
       -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.gif" \) \
    -exec bash -c '
      dir="$0"; f="$1"
      ext="${f##*.}"
      case "${ext,,}" in
        mp3|wav|flac) mv "$f" "$dir/audio/" ;;
        mp4|mkv|avi)  mv "$f" "$dir/video/" ;;
        *)            mv "$f" "$dir/images/" ;;
      esac
    ' "$WORK_DIR" {} \;
else
  log_info "Pas d’organisation préalable."
  WORK_DIR="$SOURCE_DIR"
fi

### Choix du contenu à convertir (numérique) ###
echo "Que convertir ?"
echo "  1) Tous types"
echo "  2) Audio"
echo "  3) Vidéo"
echo "  4) Images"
read -p "Choix [1-4] : " NUM
case "$NUM" in
  1) TARGET="$WORK_DIR"       ;;
  2) TARGET="$WORK_DIR/audio" ;;
  3) TARGET="$WORK_DIR/video" ;;
  4) TARGET="$WORK_DIR/images" ;;
  *) log_error "Choix invalide."; exit 1 ;;
esac

if [ ! -d "$TARGET" ]; then
  log_error "Dossier cible inexistant : $TARGET"
  exit 1
fi

### Fusion ou non ###
MERGE=false
ask_yes_no "Fusionner tous en un seul ?" "N" && MERGE=true

### Format de sortie ###
read -p "Format de sortie (ex: mp4,mp3,jpg) : " OUT_EXT
OUT_EXT="${OUT_EXT#.}"

### Sauvegarde ###
init_backup "$BACKUP_ROOT"
backup_directory "$TARGET" "$SOURCE_DIR"

### Conversion ###
if [ "$MERGE" = true ]; then
  LIST=$(mktemp)
  for f in "$TARGET"/*; do
    [ -f "$f" ] && printf "file '%s'\n" "$f" >> "$LIST"
  done
  ffmpeg -f concat -safe 0 -i "$LIST" "$OUTPUT_DIR/merged.$OUT_EXT"
  log_info "Fusion produite : $OUTPUT_DIR/merged.$OUT_EXT"
  rm -f "$LIST"
else
  if [ "$THREADS" = true ]; then
    BIN="$PROJECT_ROOT/bin/thread_converter"
    [ -x "$BIN" ] || { log_error "thread_converter introuvable ; compilez src/thread_converter.c"; exit 1; }
    N=${THREAD_COUNT:-$(nproc)}
    CMD=( "$BIN" -o "$OUTPUT_DIR" -e "$OUT_EXT" -j "$N" )
    for f in "$TARGET"/*; do
      [ -f "$f" ] && CMD+=( "$f" )
    done
    log_info "Lancement thread_converter (-j $N)..."
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
      log_info "Converti : $f → $OUTPUT_DIR/${name}.${OUT_EXT}"
    done
    $FORK && wait
  fi
fi

log_info "Toutes les conversions sont terminées. Résultats dans : $OUTPUT_DIR"
