#!/usr/bin/env bash
# lib/conversion.sh - fonctions de conversion multimédia pour convertisseur_multimedia

set -euo pipefail

# Chemin du dossier courant (lib/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger les utilitaires et la journalisation
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/logging.sh"

# Vérifier la présence des outils nécessaires
check_command ffmpeg
check_command convert

# ext_lower <filename> : renvoie l’extension en minuscules (sans le point)
ext_lower() {
  local filename="$1"
  echo "${filename##*.}" | tr '[:upper:]' '[:lower:]'
}

# convert_file <source_file> <output_dir> <out_ext>
#   Convertit un fichier audio, vidéo ou image vers l'extension demandée.
#   - source_file : chemin complet du fichier à convertir
#   - output_dir  : dossier de sortie (sera créé si nécessaire)
#   - out_ext     : extension cible (ex : mp4, mp3, jpg)
convert_file() {
  local src="$1"
  local out_dir="$2"
  local out_ext="${3#.}"      # retirer point éventuel
  local base="$(basename "$src")"
  local name="${base%.*}"
  local ext_in
  ext_in="$(ext_lower "$src")"

  # Préparer dossier de sortie
  ensure_dir "$out_dir"

  local out_path="$out_dir/${name}.${out_ext}"

  # Choisir la commande selon le type de fichier
  local cmd=()
  case "$ext_in" in
    # Audio
    mp3|wav|flac|aac|ogg)
      log_info "Conversion audio : $src → $out_path"
      # -vn : ignore toute piste vidéo si présente
      cmd=(ffmpeg -y -i "$src" -vn "$out_path")
      ;;
    # Vidéo
    mp4|mkv|avi|mov|flv|wmv)
      log_info "Conversion vidéo : $src → $out_path"
      cmd=(ffmpeg -y -i "$src" "$out_path")
      ;;
    # Image
    png|jpg|jpeg|gif|bmp|tiff)
      log_info "Conversion image  : $src → $out_path"
      cmd=(convert "$src" "$out_path")
      ;;
    *)
      log_error "Type non supporté pour conversion : .$ext_in (fichier $src)"
      return 1
      ;;
  esac

  # Exécuter la conversion
  if "${cmd[@]}"; then
    log_info "Réussi : $out_path"
    return 0
  else
    log_error "Échec de la conversion : $src"
    return 2
  fi
}

# Exemple d'utilisation :
#   convert_file "/chemin/vers/fichier.mkv" "/chemin/output" "mp4"
