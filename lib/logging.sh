#!/usr/bin/env bash
# lib/logging.sh - fonctions de journalisation pour convertisseur_multimedia

set -euo pipefail

# init_logging : préparer le fichier de log
# Doit être appelé après avoir défini LOG_DIR
init_logging() {
  : "${LOG_DIR:?Variable LOG_DIR non définie}"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/history.log"
  touch "$LOG_FILE"
}

# log_info <message> : journalise un message INFO
log_info() {
  printf "[INFO]  %s %s %s\n" \
    "$(date +'%Y-%m-%d-%H:%M:%S')" \
    "$(whoami)" \
    "$*" \
    | tee -a "$LOG_FILE"
}

# log_error <message> : journalise un message ERROR
log_error() {
  printf "[ERROR] %s %s %s\n" \
    "$(date +'%Y-%m-%d-%H:%M:%S')" \
    "$(whoami)" \
    "$*" \
    | tee -a "$LOG_FILE" >&2
}
