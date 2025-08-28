#!/bin/bash

echo "Запуск приложения MP3ToAudiobook..."

# Проверка наличия собранного приложения
if [ ! -f ".build/arm64-apple-macosx/debug/MP3ToAudiobook" ]; then
    echo "Приложение не собрано. Сначала выполните ./build_and_run.sh"
    exit 1
fi

# Запуск приложения
echo "Приложение запускается..."
.build/arm64-apple-macosx/debug/MP3ToAudiobook &

echo "Приложение запущено!"
echo "Если окно не появилось, проверьте Dock"
echo "Для остановки используйте: pkill -f MP3ToAudiobook"