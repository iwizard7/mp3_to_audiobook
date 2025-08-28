#!/bin/bash

echo "Переключение на консольную версию приложения..."

# Изменение Package.swift для консольной версии
sed -i '' 's/MP3ToAudiobook/ConsoleApp/g' Package.swift

# Удаление @main из App.swift
sed -i '' 's/@main//' Sources/MP3ToAudiobook/App.swift

# Добавление @main к ConsoleApp.swift
sed -i '' 's/struct ConsoleApp/@main\
struct ConsoleApp/g' Sources/MP3ToAudiobook/ConsoleApp.swift

echo "✅ Переключено на консольную версию"
echo ""
echo "Для запуска используйте:"
echo "  swift run"
echo ""
echo "Для возврата к GUI версии:"
echo "  ./switch_to_gui.sh"