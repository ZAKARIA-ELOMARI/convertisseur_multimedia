#!/bin/bash
# convertisseur.sh – Conversion interactive audio/vidéo/images

APP="convertisseur_multimedia"
VER="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CFG="$SCRIPT_DIR/config.conf"
source "$CFG"

# 1. Auto-install ffmpeg if missing
if ! command -v ffmpeg &>/dev/null; then
  echo "ffmpeg manquant, installation..."
  sudo apt-get update
  sudo apt-get install -y ffmpeg
fi

# 2. Auto-build & install C module if missing
if ! command -v converter_thread_app &>/dev/null; then
  echo "Module C introuvable, compilation..."
  if [ -d "$SCRIPT_DIR/converter_module" ]; then
    (cd "$SCRIPT_DIR/converter_module" && make && sudo make install)
  else
    echo "Erreur : dossier converter_module manquant." >&2
    exit 1
  fi
fi

# 3. Defaults
EXEC_MODE="sequential"
LOG_DIR="/var/log/$APP"
LOG_FILE="$LOG_DIR/history.log"
BACKUP_BASE="${DEFAULT_BACKUP_BASE}"

C_MODULE="converter_thread_app"

VIDEO_EXT=(mkv avi mp4 mov wmv flv webm ts m2ts mts)
AUDIO_EXT=(flac mp3 wav ogg aac m4a opus wma)
IMAGE_EXT=(png jpg jpeg bmp tiff gif webp)

shopt -s nocasematch
trap 'kill 0' EXIT

# 4. Logging
log_info(){
  ts=$(date "+%Y-%m-%d-%H-%M-%S")
  user=$(whoami)
  echo "$ts : $user : INFOS : $*" | tee -a "$LOG_FILE"
}
log_error(){
  ts=$(date "+%Y-%m-%d-%H-%M-%S")
  user=$(whoami)
  echo "$ts : $user : ERROR : $*" | tee -a "$LOG_FILE" >&2
}

# 5. Help & die
usage(){
  cat << EOF
Usage: $0 [options] <dossier_media>
Options obligatoires :
  -h        aide
  -f        fork
  -t        thread
  -s        subshell
  -l <dir>  dossier de logs
  -r        restaure logs par défaut
EOF
}
die(){
  log_error "$1"
  usage
  exit "$2"
}

# 6. Parse options
while getopts ":hftsrl:" opt; do
  case $opt in
    h) usage; exit 0                           ;;
    f) EXEC_MODE="fork"                        ;;
    t) EXEC_MODE="thread"                      ;;
    s) EXEC_MODE="subshell"                    ;;
    r)
      sudo mkdir -p "$LOG_DIR"
      sudo chmod 755 "$LOG_DIR"
      sudo touch "$LOG_FILE"
      sudo chmod 644 "$LOG_FILE"
      echo "Logs restaurés."
      exit 0
      ;;
    l) LOG_DIR="$OPTARG"
       LOG_FILE="$LOG_DIR/history.log"
       mkdir -p "$LOG_DIR"
       ;;
    \?) die "Option invalide : -$OPTARG" 100   ;;
    :)  die "Option -$OPTARG requiert un argument" 100 ;;
  esac
done
shift $((OPTIND-1))

# 7. Check folder param
[ -z "$1" ] && die "Paramètre manquant" 101
SRC_DIR="$1"
[ ! -d "$SRC_DIR" ] && die "Répertoire introuvable : $SRC_DIR" 102

# 8. Init logs & backup
sudo mkdir -p "$LOG_DIR"
sudo chmod 755 "$LOG_DIR"
touch "$LOG_FILE"
log_info "Démarrage $APP v$VER en mode $EXEC_MODE"

TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_BASE/$(basename "$SRC_DIR")_$TIMESTAMP"
mkdir -p "$BACKUP_DIR"
cp -r "$SRC_DIR/"* "$BACKUP_DIR"/
log_info "Sauvegarde $SRC_DIR → $BACKUP_DIR"

# — Organisation par type (récursive) —
ORG="$SRC_DIR/organized"
mkdir -p "$ORG"/audio "$ORG"/video "$ORG"/image

# Parcours tous les fichiers hors du dossier organized
find "$SRC_DIR" -type f ! -path "$ORG/*" -print0 \
| while IFS= read -r -d '' f; do
  ext="${f##*.}"
  case "${ext,,}" in
    # vidéo
    mkv|avi|mp4|mov|wmv|flv|webm|ts|m2ts|mts)
      mv "$f" "$ORG/video/";;
    # audio
    flac|mp3|wav|ogg|aac|m4a|opus|wma)
      mv "$f" "$ORG/audio/";;
    # image
    png|jpg|jpeg|bmp|tiff|gif|webp)
      mv "$f" "$ORG/image/";;
    *)
      log INFOS "Ignoré: $(basename "$f")";;
  esac
done


# 10. Interactive menu
echo "Choisissez une catégorie à convertir :"
select CAT in audio video image; do
  [ -n "$CAT" ] && break
done

read -p "Format source (ex: ${CAT:0:3}): " SRC_EXT_CONV
read -p "Format cible  (ex: ${CAT:0:3}): " DST_EXT_CONV

# 11. Pick ffmpeg opts from config
case "$CAT" in
  video) FFMPEG_OPTS="$DEFAULT_FFMPEG_VIDEO_OPTS" ;;
  audio) FFMPEG_OPTS="$DEFAULT_FFMPEG_AUDIO_OPTS" ;;
  image) FFMPEG_OPTS="$DEFAULT_FFMPEG_IMAGE_OPTS" ;;
esac

# 12. Convert files
COUNT=0
for src in "$ORG_DIR/$CAT"/*."$SRC_EXT_CONV"; do
  [ -f "$src" ] || continue
  dst="${src%.*}.$DST_EXT_CONV"
  log_info "Convert $src → $dst"
  case "$EXEC_MODE" in
    sequential)
      ffmpeg -y -i "$src" $FFMPEG_OPTS "$dst"
      ;;
    subshell)
      ( ffmpeg -y -i "$src" $FFMPEG_OPTS "$dst" ) &
      ;;
    fork)
      { ffmpeg -y -i "$src" $FFMPEG_OPTS "$dst"; } &
      ;;
    thread)
      converter_thread_app "$src" "$dst" "$FFMPEG_OPTS"
      ;;
  esac
  COUNT=$((COUNT+1))
done

wait
log_info "Conversion terminée : $COUNT fichiers. Résultats dans $ORG_DIR/$CAT"
