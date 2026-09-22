import Foundation

/// Ошибки экспорта/импорта
enum BackupError: LocalizedError {
    case encodingFailed
    case writingFailed(Error)
    case readingFailed(Error)
    case decodingFailed(Error)
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Не удалось закодировать данные."
        case .writingFailed(let error):
            return "Не удалось записать файл: \(error.localizedDescription)"
        case .readingFailed(let error):
            return "Не удалось прочитать файл: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Файл повреждён или не является бэкапом CarTracker. \(error.localizedDescription)"
        case .unsupportedVersion(let version):
            return "Версия бэкапа \(version) не поддерживается этой версией приложения."
        }
    }
}

/// Результат объединения бэкапа с текущими данными
struct MergeResult {
    var addedWorks: Int
    var skippedWorks: Int
    var addedReminders: Int
    var skippedReminders: Int

    var summaryText: String {
        var parts: [String] = []

        if addedWorks > 0 {
            parts.append("добавлено работ: \(addedWorks)")
        }
        if skippedWorks > 0 {
            parts.append("пропущено работ (дубликаты): \(skippedWorks)")
        }
        if addedReminders > 0 {
            parts.append("добавлено напоминаний: \(addedReminders)")
        }
        if skippedReminders > 0 {
            parts.append("пропущено напоминаний (дубликаты): \(skippedReminders)")
        }

        return parts.isEmpty ? "Изменений нет" : parts.joined(separator: ", ")
    }
}

/// Менеджер экспорта/импорта бэкапа
enum BackupManager {

    // MARK: - Экспорт в JSON

    /// Создать JSON-файл бэкапа и вернуть URL для share sheet.
    /// Файл сохраняется в системной временной директории — iOS сама очистит его.
    static func exportBackup(works: [CarWork], reminders: [Reminder]) throws -> URL {
        let backup = BackupData.make(from: works, reminders: reminders)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data: Data
        do {
            data = try encoder.encode(backup)
        } catch {
            throw BackupError.encodingFailed
        }

        let filename = fileNameForBackup()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw BackupError.writingFailed(error)
        }

        return url
    }

    // MARK: - Импорт из JSON

    /// Прочитать бэкап из файла
    static func importBackup(from url: URL) throws -> BackupData {
        // Проверяем доступ к файлу (вдруг он в защищённой папке iCloud)
        let needsStopAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsStopAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BackupError.readingFailed(error)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup: BackupData
        do {
            backup = try decoder.decode(BackupData.self, from: data)
        } catch {
            throw BackupError.decodingFailed(error)
        }

        // Проверяем версию
        guard backup.version <= 1 else {
            throw BackupError.unsupportedVersion(backup.version)
        }

        return backup
    }

    // MARK: - Объединение

    /// Объединить бэкап с текущими данными.
    /// Дубликаты определяются по `id` — они пропускаются.
    /// Возвращает новые массивы + статистику.
    static func merge(
        backup: BackupData,
        into currentWorks: [CarWork],
        and currentReminders: [Reminder]
    ) -> (works: [CarWork], reminders: [Reminder], result: MergeResult) {

        // --- Работы ---
        let existingWorkIDs = Set(currentWorks.map(\.id))
        let newWorks = backup.works.filter { !existingWorkIDs.contains($0.id) }
        let skippedWorks = backup.works.count - newWorks.count

        // --- Напоминания ---
        let existingReminderIDs = Set(currentReminders.map(\.id))
        let newReminders = backup.reminders.filter { !existingReminderIDs.contains($0.id) }
        let skippedReminders = backup.reminders.count - newReminders.count

        let result = MergeResult(
            addedWorks: newWorks.count,
            skippedWorks: skippedWorks,
            addedReminders: newReminders.count,
            skippedReminders: skippedReminders
        )

        let mergedWorks = currentWorks + newWorks
        let mergedReminders = currentReminders + newReminders

        return (mergedWorks, mergedReminders, result)
    }

    // MARK: - Экспорт в CSV (только работы)

    /// Создать CSV-файл со всеми работами и вернуть URL.
    static func exportCSV(works: [CarWork]) throws -> URL {
        let csv = makeCSV(from: works)

        // BOM (Byte Order Mark) — чтобы Excel правильно открывал UTF-8 с кириллицей
        var data = Data([0xEF, 0xBB, 0xBF])
        guard let csvData = csv.data(using: .utf8) else {
            throw BackupError.encodingFailed
        }
        data.append(csvData)

        let filename = fileNameForCSV()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw BackupError.writingFailed(error)
        }

        return url
    }

    /// Сформировать CSV-строку
    private static func makeCSV(from works: [CarWork]) -> String {
        var lines: [String] = []

        // Заголовок
        lines.append("Дата;Название;Категория;Пробег (км);Стоимость (₽);Статус;Заметки")

        // Форматтеры
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        dateFormatter.locale = Locale(identifier: "ru_RU")

        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.groupingSeparator = " "
        numberFormatter.maximumFractionDigits = 2

        for work in works {
            let date = dateFormatter.string(from: work.date)
            let title = escapeCSV(work.title)
            let category = escapeCSV(work.category.rawValue)
            let mileage = work.mileage > 0 ? "\(work.mileage)" : ""
            let cost = numberFormatter.string(from: NSNumber(value: work.cost)) ?? "\(work.cost)"
            let status = work.isDone ? "Выполнено" : "Запланировано"
            let note = escapeCSV(work.note)

            let line = [date, title, category, mileage, cost, status, note]
                .joined(separator: ";")
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    /// Экранирование для CSV: если есть `;`, `"` или перенос строки — оборачиваем в кавычки
    private static func escapeCSV(_ value: String) -> String {
        let needsQuotes = value.contains(";") || value.contains("\"") || value.contains("\n")
        if !needsQuotes { return value }

        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    // MARK: - Имена файлов

    private static func fileNameForBackup() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        return "cartracker_backup_\(dateString).json"
    }

    private static func fileNameForCSV() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        return "cartracker_works_\(dateString).csv"
    }
}
