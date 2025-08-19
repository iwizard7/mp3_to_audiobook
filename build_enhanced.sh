#!/bin/bash

# Улучшенный скрипт сборки для MP3 to Audiobook Converter
# Версия 2.0

set -e  # Остановить выполнение при ошибке

APP_NAME="MP3toAudiobook"
VERSION="2.0"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "🚀 Сборка ${APP_NAME} v${VERSION}"
echo "================================"

# Очистка предыдущей сборки
if [ -d "$BUILD_DIR" ]; then
    echo "🧹 Очистка предыдущей сборки..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

# Компиляция с улучшенными настройками
echo "🔨 Компиляция исходного кода..."

swiftc \
    -framework SwiftUI \
    -framework AVFoundation \
    -framework UniformTypeIdentifiers \
    -O \
    -whole-module-optimization \
    mp3toaudiobook/sources/Converter.swift \
    mp3toaudiobook/ui/EnhancedContentView.swift \
    mp3toaudiobook/mp3toaudiobookApp.swift \
    -o "${BUILD_DIR}/mp3toaudiobook_enhanced"

if [ $? -eq 0 ]; then
    echo "✅ Компиляция завершена успешно"
else
    echo "❌ Ошибка компиляции"
    exit 1
fi

# Создание bundle приложения (опционально)
echo "📦 Создание bundle приложения..."

mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Копирование исполняемого файла
cp "${BUILD_DIR}/mp3toaudiobook_enhanced" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Создание Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.mp3toaudiobook</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>mp3</string>
            </array>
            <key>CFBundleTypeName</key>
            <string>MP3 Audio File</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "✅ Сборка завершена!"
echo ""
echo "📁 Файлы сборки:"
echo "   • Исполняемый файл: ${BUILD_DIR}/mp3toaudiobook_enhanced"
echo "   • Bundle приложения: ${APP_BUNDLE}"
echo ""
echo "🚀 Запуск:"
echo "   Исполняемый файл: ./${BUILD_DIR}/mp3toaudiobook_enhanced"
echo "   Bundle приложения: open ${APP_BUNDLE}"
echo ""
echo "📋 Возможности версии 2.0:"
echo "   • Расширенные метаданные (автор, рассказчик, описание)"
echo "   • Поддержка обложек"
echo "   • Настройки качества и формата"
echo "   • Улучшенный интерфейс"
echo "   • Лучшая обработка ошибок"
