#!/bin/bash
# Crée test_files/ avec médias factices

# Installe ffmpeg si manquant
if ! command -v ffmpeg &>/dev/null; then
  sudo apt-get update
  sudo apt-get install -y ffmpeg
fi

DEST="test_files"
rm -rf "$DEST"
mkdir -p "$DEST"/nested "$DEST"/deep/concerts "$DEST"/heavyset

# Vidéo courte
ffmpeg -f lavfi -i testsrc=size=320x240:rate=30 -t 5 -pix_fmt yuv420p "$DEST/root_vid_small.mkv"
cp "$DEST/root_vid_small.mkv" "$DEST/CAPITAL.MP4"

# Audio courte
ffmpeg -f lavfi -i sine=frequency=1000 -t 5 "$DEST/root_song.mp3"

# Image factice
ffmpeg -f lavfi -i color=c=red:s=100x100 -frames:v 1 "$DEST/root_picture.png"

# Nested
ffmpeg -f lavfi -i testsrc -t 3 -pix_fmt yuv420p "$DEST/nested/clip1.webm"
ffmpeg -f lavfi -i testsrc -t 3 -pix_fmt yuv420p "$DEST/nested/clip2.AVI"
ffmpeg -f lavfi -i color=c=blue:s=50x50 -frames:v 1 "$DEST/nested/img.bmp"

# Deep
ffmpeg -f lavfi -i sine=frequency=500 -t 3 "$DEST/deep/concerts/live.flac"
ffmpeg -f lavfi -i testsrc -t 3 -pix_fmt yuv420p "$DEST/deep/concerts/trailer.mov"

# Heavyset (taille modeste pour dev)
for i in {1..3}; do
  ffmpeg -f lavfi -i testsrc -t 4 -pix_fmt yuv420p "$DEST/heavyset/big${i}.ts"
done
for i in {1..2}; do
  ffmpeg -f lavfi -i sine=frequency=800 -t 4 "$DEST/heavyset/podcast${i}.ogg"
done

echo "Dossier test_files/ prêt."
