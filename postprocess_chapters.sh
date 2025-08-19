#!/bin/bash
# Скрипт для добавления глав в аудиокнигу через ffmpeg и AtomicParsley
# Требуется: ffmpeg, AtomicParsley
# Пример использования:
# ./postprocess_chapters.sh output.m4a chapters.txt

AUDIO_FILE="$1"
CHAPTERS_FILE="$2"
OUTPUT_FILE="${AUDIO_FILE%.m4a}.m4b"

if [[ -z "$AUDIO_FILE" || -z "$CHAPTERS_FILE" ]]; then
  echo "Usage: $0 <audio.m4a> <chapters.txt>"
  exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
  echo "ffmpeg не установлен!"
  exit 1
fi
if ! command -v AtomicParsley &> /dev/null; then
  echo "AtomicParsley не установлен!"
  exit 1
fi

# Добавляем главы через ffmpeg
ffmpeg -i "$AUDIO_FILE" -i "$CHAPTERS_FILE" -map_metadata 1 -codec copy "$OUTPUT_FILE"

# Добавляем метаданные аудиокниги через AtomicParsley
AtomicParsley "$OUTPUT_FILE" --title "Аудиокнига" --genre "Audiobook" --overWrite

echo "Готово! Итоговый файл: $OUTPUT_FILE"
