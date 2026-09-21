import Foundation

/// Утилита для расчётов, связанных с напоминаниями
enum ReminderCalculator {

    // MARK: - Текущий пробег машины

    /// Определить текущий пробег как максимум из всех работ.
    /// Если работ с пробегом нет — вернём 0.
    static func currentMileage(from works: [CarWork]) -> Int {
        works.map(\.mileage).max() ?? 0
    }

    /// Текущий пробег с учётом напоминаний:
    /// если работ нет, но есть напоминания — берём максимум lastMileage.
    static func currentMileage(from works: [CarWork], reminders: [Reminder]) -> Int {
        let fromWorks = works.map(\.mileage).max() ?? 0
        let fromReminders = reminders.map(\.lastMileage).max() ?? 0
        return max(fromWorks, fromReminders)
    }

    // MARK: - Форматирование оставшегося времени

    /// "через 3 дня", "просрочено на 12 дней", "сегодня"
    static func daysText(_ days: Int) -> String {
        if days == 0 { return "сегодня" }
        if days < 0 {
            let n = abs(days)
            return "просрочено на \(n) \(dayWord(n))"
        }
        return "через \(days) \(dayWord(days))"
    }

    /// "осталось 2 500 км", "просрочено на 800 км"
    static func kmText(_ km: Int) -> String {
        if km < 0 {
            return "просрочено на \(abs(km).formatted()) км"
        }
        return "осталось \(km.formatted()) км"
    }

    /// Склонение слова "день"
    private static func dayWord(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "дней" }
        switch mod10 {
        case 1: return "день"
        case 2, 3, 4: return "дня"
        default: return "дней"
        }
    }

    // MARK: - Сводная информация

    /// Подсчитать количество напоминаний по статусам
    static func summary(reminders: [Reminder], currentMileage: Int) -> (overdue: Int, soon: Int, ok: Int) {
        var overdue = 0
        var soon = 0
        var ok = 0

        for reminder in reminders {
            switch reminder.status(currentMileage: currentMileage) {
            case .overdue: overdue += 1
            case .soon: soon += 1
            case .ok: ok += 1
            case .disabled: continue
            }
        }
        return (overdue, soon, ok)
    }

    /// Отсортировать напоминания так: сначала 🔴, потом 🟡, потом 🟢, потом ⚪
    static func sorted(_ reminders: [Reminder], currentMileage: Int) -> [Reminder] {
        reminders.sorted { lhs, rhs in
            let l = lhs.status(currentMileage: currentMileage)
            let r = rhs.status(currentMileage: currentMileage)
            return priority(l) < priority(r)
        }
    }

    private static func priority(_ status: ReminderStatus) -> Int {
        switch status {
        case .overdue: return 0
        case .soon: return 1
        case .ok: return 2
        case .disabled: return 3
        }
    }

    // MARK: - Текст для уведомления

    /// Сформировать текст локального уведомления для напоминания
    static func notificationBody(for reminder: Reminder, currentMileage: Int) -> String {
        let status = reminder.status(currentMileage: currentMileage)

        switch status {
        case .overdue:
            return "🔴 Пора: \(reminder.title). \(reminder.remainingText(currentMileage: currentMileage))"
        case .soon:
            return "🟡 Скоро: \(reminder.title). \(reminder.remainingText(currentMileage: currentMileage))"
        case .ok, .disabled:
            return reminder.title
        }
    }
}
