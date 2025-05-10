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
source "$PROJECT_ROOT/lib/monitor.sh"

### Codes d'erreur ###
readonly ERR_NO_OPTION=100        # Option saisie non existante
readonly ERR_MISSING_PARAM=101    # Paramètre obligatoire manquant
readonly ERR_DIR_NOT_FOUND=102    # Répertoire introuvable
readonly ERR_NO_PERMISSION=103    # Permissions insuffisantes
readonly ERR_NO_BACKUP=104        # Aucune sauvegarde trouvée
readonly ERR_THREAD_CONV=105      # Erreur dans thread_converter
readonly ERR_CONVERSION=106       # Erreur pendant la conversion

### Variables par défaut ###
FORK=false
THREADS=false
SUBSHELL=false
RESTORE=false
THREAD_COUNT=0
CUSTOM_LOG_DIR=""
CONFIG_FILE="$PROJECT_ROOT/config/config.ini"

usage() {
  cat <<EOF
Mediasmith - Outil de surveillance, sauvegarde et conversion multimédia
Usage: $0 [options] <répertoire_source>

Options :
  -h            Affiche cette aide
  -f            Mode fork (exécution en parallèle avec &)
  -t            Mode threads (utilise bin/thread_converter)
  -s            Mode subshell (exécution dans un sous-shell)
  -j <n>        Nombre de threads à utiliser (avec -t)
  -l <chemin>   Chemin personnalisé pour le répertoire de logs
  -r            Restaurer la dernière sauvegarde (nécessite des droits admin)

<répertoire_source> est le chemin vers les fichiers à traiter (obligatoire)

Exemples :
  $0 ~/Videos                  # Conversion simple
  $0 -f ~/Videos               # Avec fork (&)
  $0 -t -j 4 ~/Videos          # Avec 4 threads
  $0 -s ~/Videos               # Dans un subshell
  $0 -l /var/log/custom ~/Videos  # Log personnalisé
  $0 -r ~/Videos               # Restaurer depuis backup

Pour plus d'informations, consultez la documentation complète.
EOF
}

### Vérification de permissions administrateur ###
check_admin_required() {
  if [ "$EUID" -ne 0 ]; then
    log_error "Cette opération nécessite des privilèges administrateur."
    log_info "Utilisez sudo $0 $*"
    return 1
  fi
  return 0
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
    *) log_error "Option non reconnue: -$opt"; usage; exit $ERR_NO_OPTION ;;
  esac
done
shift $((OPTIND-1))

### Vérifier l'argument <répertoire_source> ###
if [ $# -lt 1 ]; then
  log_error "Erreur : pas de répertoire source spécifié."
  usage
  exit $ERR_MISSING_PARAM
fi
SOURCE_DIR="$1"
if [ ! -d "$SOURCE_DIR" ]; then
  log_error "Erreur : répertoire introuvable : $SOURCE_DIR"
  exit $ERR_DIR_NOT_FOUND
fi

### Préparation des dossiers ###
LOG_DIR="${CUSTOM_LOG_DIR:-/var/log/convertisseur_multimedia}"
if [ "$CUSTOM_LOG_DIR" == "" ] && [ ! -w "/var/log" ]; then
  # Si log standard et pas de droits d'écriture, utiliser un répertoire local
  LOG_DIR="$PROJECT_ROOT/logs"
  log_info "Pas de droits d'écriture sur /var/log, utilisation de $LOG_DIR"
fi
ensure_dir "$LOG_DIR"
init_logging            # crée LOG_DIR et history.log
BACKUP_ROOT="$PROJECT_ROOT/backup"
OUTPUT_DIR="$PROJECT_ROOT/output"
ensure_dir "$BACKUP_ROOT" "$OUTPUT_DIR"

### Restauration si demandé ###
if [ "$RESTORE" = true ]; then
  # La restauration nécessite des droits admin
  if ! check_admin_required "$@"; then
    exit $ERR_NO_PERMISSION
  fi
  
  LAST=$(ls -dt "$BACKUP_ROOT"/*/ 2>/dev/null | head -n1 || true)
  if [ -z "$LAST" ]; then
    log_error "Aucune sauvegarde à restaurer."
    exit $ERR_NO_BACKUP
  fi
  cp -r "$LAST"* "$SOURCE_DIR"/
  log_info "Restauration effectuée depuis : $LAST"
  exit 0
fi

### Vérifier que les modes sont mutuellement exclusifs ###
MODES=0
$FORK && ((MODES++))
$THREADS && ((MODES++))
$SUBSHELL && ((MODES++))
if [ $MODES -gt 1 ]; then
  log_error "Les options -f, -t et -s sont mutuellement exclusives."
  exit $ERR_NO_OPTION
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
  log_info "Pas d'organisation préalable."
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
  *) log_error "Choix invalide."; exit $ERR_NO_OPTION ;;
esac

if [ ! -d "$TARGET" ]; then
  log_error "Dossier cible inexistant : $TARGET"
  exit $ERR_DIR_NOT_FOUND
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
  if ! ffmpeg -f concat -safe 0 -i "$LIST" "$OUTPUT_DIR/merged.$OUT_EXT"; then
    log_error "Échec de la fusion des fichiers"
    rm -f "$LIST"
    exit $ERR_CONVERSION
  fi
  log_info "Fusion produite : $OUTPUT_DIR/merged.$OUT_EXT"
  rm -f "$LIST"
else
  if [ "$THREADS" = true ]; then
    BIN="$PROJECT_ROOT/bin/thread_converter"
    [ -x "$BIN" ] || { log_error "thread_converter introuvable ; compilez src/thread_converter.c"; exit $ERR_THREAD_CONV; }
    N=${THREAD_COUNT:-$(nproc)}
    CMD=( "$BIN" -o "$OUTPUT_DIR" -e "$OUT_EXT" -j "$N" )
    for f in "$TARGET"/*; do
      [ -f "$f" ] && CMD+=( "$f" )
    done
    log_info "Lancement thread_converter (-j $N)..."
    if ! "${CMD[@]}"; then
      log_error "Échec de la conversion par threads"
      exit $ERR_THREAD_CONV
    fi
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

# Proposer de lancer la surveillance du répertoire
if ask_yes_no "Démarrer la surveillance continue du répertoire source?" "N"; then
  # Configuration du handler pour les nouveaux fichiers
  handle_new_file() {
    local filepath="$1"
    log_info "Nouveau fichier détecté: $filepath"
    
    # Sauvegarde du fichier
    init_backup "$BACKUP_ROOT"
    backup_file "$filepath" "$SOURCE_DIR"
    
    # Conversion du fichier
    local ext="${filepath##*.}"
    local filename="${filepath##*/}"
    local basename="${filename%.*}"
    
    # Déterminer le format de sortie selon le type
    local target_ext="$OUT_EXT"
    if [ -z "$target_ext" ]; then
      case "${ext,,}" in
        mp3|wav|flac|ogg|aac) target_ext="mp3" ;;
        mp4|mkv|avi|mov|flv)  target_ext="mp4" ;;
        png|jpg|jpeg|gif|bmp) target_ext="jpg" ;;
        *) target_ext="mp4" ;;  # défaut
      esac
    fi
    
    # Lancer la conversion avec le mode choisi
    if [ "$THREADS" = true ]; then
      "$BIN" -o "$OUTPUT_DIR" -e "$target_ext" -j "$N" "$filepath"
    else
      local cmd=( ffmpeg -y -i "$filepath" "$OUTPUT_DIR/${basename}.${target_ext}" )
      if [ "$FORK" = true ]; then
        "${cmd[@]}" &
      elif [ "$SUBSHELL" = true ]; then
        ( "${cmd[@]}" )
      else
        "${cmd[@]}"
      fi
    fi
    log_info "Traitement terminé pour: $filepath"
  }
  
  # Lancer la surveillance
  monitor_directory "$SOURCE_DIR" handle_new_file
fi

exit 0
