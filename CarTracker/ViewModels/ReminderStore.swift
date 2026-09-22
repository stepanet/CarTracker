import Foundation
import Combine

final class ReminderStore: ObservableObject {
    @Published var reminders: [Reminder] = [] {
        didSet { save() }
    }

    private let saveKey = "car_reminders_v1"

    init() { load() }

    // MARK: - CRUD

    func add(_ reminder: Reminder) {
        reminders.append(reminder)
        sortReminders()
    }

    func update(_ reminder: Reminder) {
        if let idx = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[idx] = reminder
            sortReminders()
        }
    }

    func delete(_ reminder: Reminder) {
        reminders.removeAll { $0.id == reminder.id }
    }

    private func sortReminders() {
        // Сортируем по статусу: сначала "пора", потом "скоро", потом остальные
        reminders.sort { lhs, rhs in
            statusOrder(lhs.status(currentMileage: 0)) <
            statusOrder(rhs.status(currentMileage: 0))
        }
    }
    
    /// Заменить весь массив напоминаний (при импорте бэкапа)
    func replaceAll(with newReminders: [Reminder]) {
        reminders = newReminders
        sortReminders()
    }

    private func statusOrder(_ status: ReminderStatus) -> Int {
        switch status {
        case .overdue: return 0
        case .soon: return 1
        case .ok: return 2
        case .disabled: return 3
        }
    }

    // MARK: - Действия

    /// Пометить как выполненное сегодня
    func markDone(_ reminder: Reminder, currentMileage: Int) {
        guard var existing = reminders.first(where: { $0.id == reminder.id }) else { return }
        existing.lastDate = Date()
        existing.lastMileage = currentMileage
        update(existing)
    }

    /// Добавить типовой набор напоминаний
    func installDefaultSet() {
        let defaults: [Reminder] = [
            Reminder(
                title: "Замена масла",
                icon: "drop.fill",
                intervalKm: 10_000,
                intervalMonths: 12,
                lastDate: Date(),
                lastMileage: 0
            ),
            Reminder(
                title: "Ротация шин",
                icon: "circle.circle.fill",
                intervalKm: 15_000,
                intervalMonths: 12,
                lastDate: Date(),
                lastMileage: 0
            ),
            Reminder(
                title: "Замена тормозной жидкости",
                icon: "exclamationmark.octagon.fill",
                intervalKm: 0,
                intervalMonths: 24,
                lastDate: Date(),
                lastMileage: 0
            ),
            Reminder(
                title: "Замена салонного фильтра",
                icon: "wind",
                intervalKm: 20_000,
                intervalMonths: 12,
                lastDate: Date(),
                lastMileage: 0
            )
        ]
        reminders.append(contentsOf: defaults)
        sortReminders()
    }

    /// Напоминания, требующие внимания (для бейджа на вкладке)
    func remindersNeedingAttention(currentMileage: Int) -> [Reminder] {
        reminders.filter {
            let s = $0.status(currentMileage: currentMileage)
            return s == .overdue || s == .soon
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([Reminder].self, from: data)
        else { return }
        reminders = decoded
    }
}

// MARK: - Логика статуса

extension Reminder {
    /// Определить статус напоминания исходя из текущего пробега
    func status(currentMileage: Int) -> ReminderStatus {
        guard isEnabled else { return .disabled }

        // Проверяем по дате
        if let nextDate = nextDate {
            let daysLeft = Calendar.current.dateComponents(
                [.day],
                from: Date(),
                to: nextDate
            ).day ?? 0

            if daysLeft < 0 { return .overdue }
            // "Скоро" — если осталось меньше 30 дней
            if daysLeft < 30 { return .soon }
        }

        // Проверяем по пробегу
        if let nextMileage = nextMileage {
            let kmLeft = nextMileage - currentMileage

            if kmLeft < 0 { return .overdue }
            // "Скоро" — если осталось меньше 1000 км
            if kmLeft < 1_000 { return .soon }
        }

        return .ok
    }

    /// Сколько осталось до следующей замены (текстом)
    func remainingText(currentMileage: Int) -> String {
        guard isEnabled else { return "Выключено" }

        var parts: [String] = []

        // По пробегу
        if let nextMileage = nextMileage {
            let kmLeft = nextMileage - currentMileage
            if kmLeft < 0 {
                parts.append("просрочено на \(abs(kmLeft).formatted()) км")
            } else {
                parts.append("осталось \(kmLeft.formatted()) км")
            }
        }

        // По дате
        if let nextDate = nextDate {
            let days = Calendar.current.dateComponents(
                [.day],
                from: Date(),
                to: nextDate
            ).day ?? 0

            if days < 0 {
                parts.append("просрочено на \(abs(days)) дн.")
            } else {
                parts.append("осталось \(days) дн.")
            }
        }

        return parts.isEmpty ? "—" : parts.joined(separator: " • ")
    }
}
