#!/usr/bin/env bash
# lib/logging.sh - fonctions de journalisation pour convertisseur_multimedia

set -euo pipefail

# Charger les utils pour ensure_dir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Variables globales
LOG_DIR=""
LOG_FILE=""

# init_logging : préparer le fichier de log
# Doit être appelé après avoir défini LOG_DIR
init_logging() {
  : "${LOG_DIR:?Variable LOG_DIR non définie}"
  ensure_dir "$LOG_DIR"
  LOG_FILE="$LOG_DIR/history.log"
  touch "$LOG_FILE"
  
  # Vérifier les permissions
  if [ ! -w "$LOG_FILE" ]; then
    # Si pas de droits, utiliser un répertoire local
    LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/logs"
    ensure_dir "$LOG_DIR"
    LOG_FILE="$LOG_DIR/history.log"
    touch "$LOG_FILE"
    echo "ATTENTION: Redirection des logs vers $LOG_FILE"
  fi
}

# Fonction interne pour format de date selon les specs
_get_formatted_date() {
  date +'%Y-%m-%d-%H-%M-%S'
}

# log_info <message> : journalise un message INFO selon le format spécifié
# Format: yyyy-mm-dd-hh-mm-ss : username : INFOS : message
log_info() {
  local timestamp
  local username
  timestamp="$(_get_formatted_date)"
  username="$(whoami)"
  printf "%s : %s : INFOS : %s\n" \
    "$timestamp" \
    "$username" \
    "$*" \
    | tee -a "$LOG_FILE"
}

# log_error <message> : journalise un message ERROR selon le format spécifié
# Format: yyyy-mm-dd-hh-mm-ss : username : ERROR : message
log_error() {
  local timestamp
  local username
  timestamp="$(_get_formatted_date)"
  username="$(whoami)"
  printf "%s : %s : ERROR : %s\n" \
    "$timestamp" \
    "$username" \
    "$*" \
    | tee -a "$LOG_FILE" >&2
}
