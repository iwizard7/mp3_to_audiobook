#!/bin/bash

echo "Переключение на GUI версию приложения..."

# Изменение Package.swift для GUI версии
sed -i '' 's/ConsoleApp/MP3ToAudiobook/g' Package.swift

# Добавление @main к App.swift
sed -i '' 's/struct MP3ToAudiobookApp/@main\
struct MP3ToAudiobookApp/g' Sources/MP3ToAudiobook/App.swift

# Удаление @main из ConsoleApp.swift
sed -i '' 's/@main//' Sources/MP3ToAudiobook/ConsoleApp.swift

echo "✅ Переключено на GUI версию"
echo ""
echo "Для запуска используйте:"
echo "  ./build_and_run.sh"
echo ""
echo "Для возврата к консольной версии:"
echo "  ./switch_to_console.sh"