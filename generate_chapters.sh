#!/bin/bash
# Генерирует файл chapters.txt для ffmpeg на основе списка mp3 файлов
# Использование: ./generate_chapters.sh file1.mp3 file2.mp3 ...

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <file1.mp3> <file2.mp3> ..."
  exit 1
fi

CHAPTERS_FILE="chapters.txt"
echo ";FFMETADATA1" > "$CHAPTERS_FILE"

START=0
for FILE in "$@"; do
  DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FILE")
  END=$(echo "$START + $DURATION" | bc)
  BASENAME=$(basename "$FILE" .mp3)
  echo "[CHAPTER]" >> "$CHAPTERS_FILE"
  echo "TIMEBASE=1/1" >> "$CHAPTERS_FILE"
  echo "START=$(printf '%.0f' "$START")" >> "$CHAPTERS_FILE"
  echo "END=$(printf '%.0f' "$END")" >> "$CHAPTERS_FILE"
  echo "title=$BASENAME" >> "$CHAPTERS_FILE"
  echo "" >> "$CHAPTERS_FILE"
  START=$END
done

echo "Файл глав сгенерирован: $CHAPTERS_FILE"
