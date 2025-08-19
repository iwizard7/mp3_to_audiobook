#!/bin/bash

# Скрипт для сборки приложения mp3toaudiobook

swiftc -framework SwiftUI -framework AVFoundation mp3toaudiobook/sources/Converter.swift mp3toaudiobook/ui/ContentView.swift mp3toaudiobook/mp3toaudiobookApp.swift -o mp3toaudiobook_app

if [ $? -eq 0 ]; then
    echo "Сборка прошла успешно. Запустите приложение командой: ./mp3toaudiobook_app"
else
    echo "Ошибка сборки."
fi
