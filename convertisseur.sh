#!/bin/bash
#
# convertisseur.sh – Conversion interactive audio/vidéo/images
#
APP="convertisseur_multimedia"
VER="1.0.0"

# --- Défaults & config ---
CFG="$(dirname "$0")/config.conf"
# Charger config
source "$CFG"

# Options & modes
EXEC_MODE="sequential"
LOG_DIR="/var/log/$APP"
BACKUP_BASE="${DEFAULT_BACKUP_BASE}"
LOG_FILE="$LOG_DIR/history.log"

# Extensions prises en charge (case-insensitive)
VIDEO_EXT=(mkv avi mp4 mov wmv flv webm ts m2ts mts)
AUDIO_EXT=(flac mp3 wav ogg aac m4a opus wma)
IMAGE_EXT=(png jpg jpeg bmp tiff gif webp)

# Active le cas-insensitive
shopt -s nocasematch
trap 'kill 0' EXIT

# — Loggers —
log() {
  local type="$1"; shift
  local ts user msg
  ts=$(date "+%Y-%m-%d-%H-%M-%S")
  user=$(whoami)
  msg="$*"
  printf "%s : %s : %s : %s\n" "$ts" "$user" "$type" "$msg" \
    | tee -a "$LOG_FILE" ${type//INFOS//}>&2
}

# — Aide & erreurs —
usage(){
  cat << EOF
Usage: $0 [options] <dossier>
Options obligatoires :contentReference[oaicite:0]{index=0}:contentReference[oaicite:1]{index=1}:
  -h        aide
  -f        fork
  -t        thread
  -s        subshell
  -l <dir>  dossier de logs
  -r        restaure /var/log et quitte
EOF
}
die(){ log ERROR "$*"; usage; exit "$2"; }

# — Restore defaults —
if [[ "$1"=="-r" ]]; then
  sudo mkdir -p "$LOG_DIR"; sudo chmod 755 "$LOG_DIR"
  sudo touch "$LOG_FILE"; sudo chmod 644 "$LOG_FILE"
  echo "Defaults restored."; exit 0
fi

# — Parse options —
while getopts ":hftsl:" o; do
  case $o in
    h) usage; exit 0 ;;
    f) EXEC_MODE="fork" ;;
    t) EXEC_MODE="thread" ;;
    s) EXEC_MODE="subshell" ;;
    l) LOG_DIR="$OPTARG"; LOG_FILE="$LOG_DIR/history.log"; mkdir -p "$LOG_DIR"; ;;
    \?) die "Option invalide -$OPTARG" 100 ;;
    :) die "Option -$OPTARG requiert un argument" 100 ;;
  esac
done
shift $((OPTIND-1))
[ -z "$1" ] && die "Paramètre manquant" 101
SRC_DIR="$1"
[ ! -d "$SRC_DIR" ] && die "Répertoire introuvable $SRC_DIR" 102

# — Création logs & backup —
sudo mkdir -p "$LOG_DIR"; sudo chmod 755 "$LOG_DIR"
touch "$LOG_FILE"
log INFOS "Démarrage $APP v$VER en mode $EXEC_MODE"

ts=$(date "+%Y%m%d_%H%M%S")
bk="$BACKUP_BASE/$(basename "$SRC_DIR")_$ts"
mkdir -p "$bk"
cp -r "$SRC_DIR/"* "$bk"/
log INFOS "Sauvegarde de $SRC_DIR → $bk"

# — Organisation par type —
ORG="$SRC_DIR/organized"
mkdir -p "$ORG"/audio "$ORG"/video "$ORG"/image
for f in "$SRC_DIR"/*; do
  [ -f "$f" ] || continue
  ext="${f##*.}"
  name="${f%.*}"
  for e in "${VIDEO_EXT[@]}"; do [[ "$ext"=="$e" ]] && mv "$f" "$ORG/video/" && continue 2; done
  for e in "${AUDIO_EXT[@]}"; do [[ "$ext"=="$e" ]] && mv "$f" "$ORG/audio/" && continue 2; done
  for e in "${IMAGE_EXT[@]}"; do [[ "$ext"=="$e" ]] && mv "$f" "$ORG/image/" && continue 2; done
  log INFOS "Ignoré: $(basename "$f")"
done

# — Menu interactif —
echo "Catégories disponibles :"
select CAT in audio video image; do
  [ -n "$CAT" ] && break
done

read -p "Format source (ex: ${CAT:0:3}): " SRC_FMT
read -p "Format cible (ex: ${CAT:0:3}): " DST_FMT

# — Conversion des fichiers —
OPTS_VAR="DEFAULT_FFMPEG_${CAT^^}_OPTS"
OPTS="${!OPTS_VAR}"

for src in "$ORG/$CAT"/*."$SRC_FMT"; do
  [ -f "$src" ] || continue
  dst="${src%.*}.$DST_FMT"
  log INFOS "Conversion $src → $dst"
  case "$EXEC_MODE" in
    sequential) ffmpeg -y -i "$src" $OPTS "$dst" ;;
    subshell)    ( ffmpeg -y -i "$src" $OPTS "$dst" ) & ;;
    fork)        { ffmpeg -y -i "$src" $OPTS "$dst"; } & ;;
    thread)      converter_thread_app "$src" "$dst" "$OPTS" ;;
  esac
done

wait
log INFOS "Conversion terminée. Résultats dans $ORG/$CAT"
