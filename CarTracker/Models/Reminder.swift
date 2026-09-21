import Foundation

struct Reminder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String               // Название работы, например "Замена масла"
    var icon: String                // SF Symbol
    var intervalKm: Int             // Интервал в км (0 = не используется)
    var intervalMonths: Int         // Интервал в месяцах (0 = не используется)
    var lastDate: Date              // Когда делалось в последний раз
    var lastMileage: Int            // Пробег на момент последнего выполнения
    var isEnabled: Bool = true      // Включено ли напоминание

    // MARK: - Вычисляемые значения

    /// Следующая дата замены (если задан интервал в месяцах)
    var nextDate: Date? {
        guard intervalMonths > 0 else { return nil }
        return Calendar.current.date(
            byAdding: .month,
            value: intervalMonths,
            to: lastDate
        )
    }

    /// Следующий пробег для замены (если задан интервал в км)
    var nextMileage: Int? {
        guard intervalKm > 0 else { return nil }
        return lastMileage + intervalKm
    }

    /// Описание интервала для отображения
    var intervalDescription: String {
        var parts: [String] = []
        if intervalKm > 0 {
            parts.append("каждые \(intervalKm.formatted()) км")
        }
        if intervalMonths > 0 {
            let word = monthsWord(intervalMonths)
            parts.append("каждые \(intervalMonths) \(word)")
        }
        return parts.isEmpty ? "интервал не задан" : parts.joined(separator: " или ")
    }

    private func monthsWord(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "месяцев" }
        switch mod10 {
        case 1: return "месяц"
        case 2, 3, 4: return "месяца"
        default: return "месяцев"
        }
    }
}

// MARK: - Статус напоминания

enum ReminderStatus {
    case ok         // 🟢 всё в порядке
    case soon       // 🟡 скоро
    case overdue    // 🔴 пора / просрочено
    case disabled   // ⚪ выключено

    var color: String {
        switch self {
        case .ok: return "green"
        case .soon: return "yellow"
        case .overdue: return "red"
        case .disabled: return "gray"
        }
    }

    var label: String {
        switch self {
        case .ok: return "В порядке"
        case .soon: return "Скоро"
        case .overdue: return "Пора"
        case .disabled: return "Выключено"
        }
    }
}
