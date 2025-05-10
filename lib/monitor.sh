#!/usr/bin/env bash
# lib/monitor.sh - fonctions de surveillance de répertoire pour convertisseur_multimedia

set -euo pipefail

# Déterminer le répertoire de ce script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger les utilitaires et la journalisation
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/logging.sh"

# Vérifier la présence de inotifywait
check_command inotifywait

# monitor_directory <dir> <handler_function>
#   Surveille récursivement <dir> pour les événements de création ou déplacement de fichiers
#   et appelle <handler_function> en lui passant le chemin complet du fichier détecté.
monitor_directory() {
  local dir="$1"
  local handler="$2"

  if [ -z "$dir" ] || [ -z "$handler" ]; then
    log_error "monitor_directory: usage: monitor_directory <dir> <handler_function>"
    return 1
  fi

  if [ ! -d "$dir" ]; then
    log_error "monitor_directory: répertoire introuvable : $dir"
    return 1
  fi

  if ! declare -F "$handler" >/dev/null; then
    log_error "monitor_directory: fonction handler introuvable : $handler"
    return 1
  fi

  log_info "Démarrage de la surveillance de '$dir' (création & déplacement)..."
  # -m : mode monitor (boucle infinie)
  # -r : récursif
  # -e create,moved_to : événement création ou déplacement vers ce répertoire
  inotifywait -m -r -e create,moved_to --format '%w%f' "$dir" \
    | while read -r filepath; do
        # filtrer uniquement les fichiers réguliers
        if [ -f "$filepath" ]; then
          log_info "Fichier détecté : $filepath"
          # appeler la fonction de traitement
          "$handler" "$filepath"
        fi
      done
}

# Exemple de handler à définir dans le script principal :
# handle_new_file() {
#   local filepath="$1"
#   # appel à la sauvegarde puis conversion...
#   init_backup "$BACKUP_ROOT"
#   backup_file "$filepath" "$SOURCE_ROOT"
#   convert_file "$filepath" "$OUTPUT_DIR" "$OUT_EXT"
# }

# Pour lancer la surveillance dans le script principal :
# monitor_directory "$SOURCE_DIR" handle_new_file
