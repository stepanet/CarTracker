import Foundation

/// Обёртка для бэкапа всех данных приложения.
/// Используется для экспорта/импорта в JSON-файл.
struct BackupData: Codable {

    /// Версия формата бэкапа.
    /// Меняется, если структура данных несовместимо изменилась.
    /// Текущая версия: 1.
    var version: Int = 1

    /// Дата создания бэкапа
    var exportedAt: Date = Date()

    /// Все работы
    var works: [CarWork]

    /// Все напоминания
    var reminders: [Reminder]

    // MARK: - Удобные конструкторы

    /// Создать бэкап из текущего состояния приложения
    static func make(from works: [CarWork], reminders: [Reminder]) -> BackupData {
        BackupData(
            version: 1,
            exportedAt: Date(),
            works: works,
            reminders: reminders
        )
    }

    // MARK: - Информация о бэкапе

    /// Суммарная информация для отображения пользователю
    var summaryDescription: String {
        let worksText = "\(works.count) \(worksWord(works.count))"
        let remindersText = "\(reminders.count) \(remindersWord(reminders.count))"
        return "Работ: \(worksText), напоминаний: \(remindersText)"
    }

    private func worksWord(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "работ" }
        switch mod10 {
        case 1: return "работа"
        case 2, 3, 4: return "работы"
        default: return "работ"
        }
    }

    private func remindersWord(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "напоминаний" }
        switch mod10 {
        case 1: return "напоминание"
        case 2, 3, 4: return "напоминания"
        default: return "напоминаний"
        }
    }
}
