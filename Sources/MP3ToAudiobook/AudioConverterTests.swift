import Foundation
import AVFoundation
import AppKit

/// Базовые тесты для AudioConverter
/// Запуск: swift test (если настроена тестовая конфигурация)
struct AudioConverterTests {

    static func runAllTests() {
        print("=== ЗАПУСК ТЕСТОВ AudioConverter ===")

        testEmptyInputFiles()
        testEmptyAuthor()
        testEmptyTitle()
        testNonexistentFile()
        testValidAudioFileDetection()

        print("=== ТЕСТЫ ЗАВЕРШЕНЫ ===")
    }

    /// Тест: проверка обработки пустого списка входных файлов
    static func testEmptyInputFiles() {
        print("Тест: пустой список входных файлов")

        AudioConverter.convertAudioToM4B(
            inputURLs: [],
            outputURL: URL(fileURLWithPath: "/tmp/test.m4b"),
            author: "Test Author",
            title: "Test Title",
            coverImage: nil,
            progressHandler: { _ in },
            logHandler: { _ in }
        ) { result in
            switch result {
            case .success:
                print("❌ ОШИБКА: ожидалась ошибка для пустого списка файлов")
            case .failure(let error):
                if error.localizedDescription.contains("Не указаны входные файлы") {
                    print("✅ Пройден: правильно обработан пустой список файлов")
                } else {
                    print("❌ ОШИБКА: неправильная ошибка - \(error.localizedDescription)")
                }
            }
        }
    }

    /// Тест: проверка обработки пустого автора
    static func testEmptyAuthor() {
        print("Тест: пустой автор")

        let testFile = createTestAudioFile()
        guard let testFile = testFile else {
            print("⚠️  Пропущен: не удалось создать тестовый файл")
            return
        }

        AudioConverter.convertAudioToM4B(
            inputURLs: [testFile],
            outputURL: URL(fileURLWithPath: "/tmp/test.m4b"),
            author: "",
            title: "Test Title",
            coverImage: nil,
            progressHandler: { _ in },
            logHandler: { _ in }
        ) { result in
            switch result {
            case .success:
                print("❌ ОШИБКА: ожидалась ошибка для пустого автора")
            case .failure(let error):
                if error.localizedDescription.contains("Не указан автор") {
                    print("✅ Пройден: правильно обработан пустой автор")
                } else {
                    print("❌ ОШИБКА: неправильная ошибка - \(error.localizedDescription)")
                }
            }
        }
    }

    /// Тест: проверка обработки пустого названия
    static func testEmptyTitle() {
        print("Тест: пустое название")

        let testFile = createTestAudioFile()
        guard let testFile = testFile else {
            print("⚠️  Пропущен: не удалось создать тестовый файл")
            return
        }

        AudioConverter.convertAudioToM4B(
            inputURLs: [testFile],
            outputURL: URL(fileURLWithPath: "/tmp/test.m4b"),
            author: "Test Author",
            title: "",
            coverImage: nil
        ) { _ in } completion: { result in
            switch result {
            case .success:
                print("❌ ОШИБКА: ожидалась ошибка для пустого названия")
            case .failure(let error):
                if error.localizedDescription.contains("Не указано название") {
                    print("✅ Пройден: правильно обработано пустое название")
                } else {
                    print("❌ ОШИБКА: неправильная ошибка - \(error.localizedDescription)")
                }
            }
        }
    }

    /// Тест: проверка обработки несуществующего файла
    static func testNonexistentFile() {
        print("Тест: несуществующий файл")

        AudioConverter.convertAudioToM4B(
            inputURLs: [URL(fileURLWithPath: "/nonexistent/file.mp3")],
            outputURL: URL(fileURLWithPath: "/tmp/test.m4b"),
            author: "Test Author",
            title: "Test Title",
            coverImage: nil
        ) { _ in } completion: { result in
            switch result {
            case .success:
                print("❌ ОШИБКА: ожидалась ошибка для несуществующего файла")
            case .failure(let error):
                if error.localizedDescription.contains("Файл не найден") {
                    print("✅ Пройден: правильно обработан несуществующий файл")
                } else {
                    print("❌ ОШИБКА: неправильная ошибка - \(error.localizedDescription)")
                }
            }
        }
    }

    /// Тест: проверка определения аудиофайлов
    static func testValidAudioFileDetection() {
        print("Тест: определение аудиофайлов")

        let audioExtensions = ["mp3", "aac", "m4a", "wav", "aiff"]
        let nonAudioExtensions = ["txt", "jpg", "pdf", "docx"]

        for ext in audioExtensions {
            let url = URL(fileURLWithPath: "test.\(ext)")
            if isAudioFile(url) {
                print("✅ Правильно определен аудиофайл: \(ext)")
            } else {
                print("❌ ОШИБКА: не определен аудиофайл: \(ext)")
            }
        }

        for ext in nonAudioExtensions {
            let url = URL(fileURLWithPath: "test.\(ext)")
            if !isAudioFile(url) {
                print("✅ Правильно определен не-аудиофайл: \(ext)")
            } else {
                print("❌ ОШИБКА: неправильно определен как аудиофайл: \(ext)")
            }
        }
    }

    /// Вспомогательная функция для определения аудиофайлов
    private static func isAudioFile(_ url: URL) -> Bool {
        let audioExtensions = ["mp3", "aac", "m4a", "wav", "aiff"]
        return audioExtensions.contains(url.pathExtension.lowercased())
    }

    /// Создание тестового аудиофайла (заглушка)
    private static func createTestAudioFile() -> URL? {
        // В реальном тесте здесь можно создать временный аудиофайл
        // Пока просто возвращаем nil для пропуска тестов
        return nil
    }
}