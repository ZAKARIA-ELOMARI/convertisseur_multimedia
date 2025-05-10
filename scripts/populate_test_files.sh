#!/usr/bin/env bash
# populate_test_files.sh - Crée test_files/ et génère un jeu de fichiers multimédias pour les tests

set -euo pipefail

# Vérifier les dépendances
for cmd in ffmpeg convert; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] '$cmd' introuvable. Veuillez lancer deps_check.sh avant." >&2
    exit 1
  fi
done

# Définir les chemins
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_DIR="$PROJECT_ROOT/test_files"

# (Re)création du dossier de test
if [ -d "$TEST_DIR" ]; then
  rm -rf "$TEST_DIR"
fi
mkdir -p "$TEST_DIR"

echo "[INFO] Création de fichiers de test dans : $TEST_DIR"

# 1. Vidéo MP4 de 5 s (pattern testsrc)
ffmpeg -y -f lavfi -i testsrc=duration=5:size=320x240:rate=30 \
  "$TEST_DIR/sample.mp4"

# 2. Conversion de sample.mp4 en MKV
ffmpeg -y -i "$TEST_DIR/sample.mp4" \
  "$TEST_DIR/sample.mkv"

# 3. Audio WAV de 3 s (ton A4)
ffmpeg -y -f lavfi -i sine=frequency=440:duration=3 \
  "$TEST_DIR/sample.wav"

# 4. Conversion de sample.wav en FLAC
ffmpeg -y -i "$TEST_DIR/sample.wav" \
  "$TEST_DIR/sample.flac"

# 5. Image PNG 100×100 rouge
convert -size 100x100 xc:red \
  "$TEST_DIR/sample.png"

# 6. Image JPEG 100×100 bleue
convert -size 100x100 xc:blue \
  "$TEST_DIR/sample.jpg"

# 7. GIF animé simple (vert→jaune→magenta)
convert -delay 100 xc:green xc:yellow xc:magenta -loop 0 \
  "$TEST_DIR/sample.gif"

echo "[INFO] Génération des fichiers de test terminée."
