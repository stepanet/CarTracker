import Foundation
import Combine

/// Хранилище напоминаний.
/// Работает с Supabase через `RemindersRepository`.
final class ReminderStore: ObservableObject {

    // MARK: - Published

    @Published var reminders: [Reminder] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    // MARK: - Dependencies

    private let repository = RemindersRepository.shared
    private let realtime = RealtimeManager.shared
    private var userId: UUID?

    // MARK: - Init

    init() {
        // При старте ничего не грузим — загрузка идёт из CarTrackerApp
    }

    // MARK: - Загрузка / Realtime

    /// Загрузить напоминания из Supabase
    @MainActor
    func loadReminders(userId: UUID) async {
        self.userId = userId
        isLoading = true
        error = nil

        do {
            let fetched = try await repository.fetchAll(userId: userId)
            self.reminders = sortReminders(fetched)
            isLoading = false
            print("✅ Загружено напоминаний: \(fetched.count)")
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            print("❌ Ошибка загрузки напоминаний: \(error)")
        }
    }

    /// Перезагрузить данные (для pull-to-refresh)
    @MainActor
    func reload() async {
        guard let userId = userId else {
            print("⚠️ Нет userId для reload напоминаний")
            return
        }
        await loadReminders(userId: userId)
    }

    /// Подписаться на Realtime-изменения
    @MainActor
    func subscribeRealtime(userId: UUID) {
        realtime.onRemindersChanged = { [weak self] in
            guard let self = self else { return }
            Task {
                await self.loadReminders(userId: userId)
            }
        }

        realtime.subscribeReminders(userId: userId)
    }

    /// Отписаться от Realtime
    @MainActor
    func unsubscribeRealtime() async {
        realtime.onRemindersChanged = nil
        await realtime.unsubscribeReminders()
    }

    /// Очистить данные (при выходе)
    @MainActor
    func clear() {
        reminders = []
        userId = nil
        error = nil
    }

    // MARK: - CRUD

    @MainActor
    func add(_ reminder: Reminder) async {
        guard let userId = userId else {
            error = "Не авторизован"
            return
        }

        // 1. Оптимистично добавляем
        var newReminders: [Reminder] = reminders
        newReminders.append(reminder)
        reminders = sortReminders(newReminders)

        // 2. Сохраняем в Supabase
        do {
            try await repository.create(reminder, userId: userId)
        } catch {
            reminders.removeAll { $0.id == reminder.id }
            self.error = error.localizedDescription
            print("❌ Ошибка создания напоминания: \(error)")
        }
    }

    @MainActor
    func update(_ reminder: Reminder) async {
        guard let userId = userId else {
            error = "Не авторизован"
            return
        }

        let previous: Reminder? = reminders.first { $0.id == reminder.id }

        // 1. Оптимистично обновляем
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = reminder
            reminders = sortReminders(reminders)
        }

        // 2. Сохраняем в Supabase
        do {
            try await repository.update(reminder, userId: userId)
        } catch {
            if let prev = previous,
               let index = reminders.firstIndex(where: { $0.id == prev.id }) {
                reminders[index] = prev
                reminders = sortReminders(reminders)
            }
            self.error = error.localizedDescription
            print("❌ Ошибка обновления напоминания: \(error)")
        }
    }

    @MainActor
    func delete(_ reminder: Reminder) async {
        let previous: [Reminder] = reminders

        // 1. Оптимистично удаляем
        reminders.removeAll { $0.id == reminder.id }

        // 2. Удаляем из Supabase
        do {
            try await repository.delete(id: reminder.id)
        } catch {
            reminders = previous
            self.error = error.localizedDescription
            print("❌ Ошибка удаления напоминания: \(error)")
        }
    }

    // MARK: - Действия

    /// Пометить как выполненное сегодня
    @MainActor
    func markDone(_ reminder: Reminder, currentMileage: Int) async {
        var updated = reminder
        updated.lastDate = Date()
        updated.lastMileage = currentMileage
        await update(updated)
    }

    /// Добавить типовой набор напоминаний
    @MainActor
    func installDefaultSet() async {
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

        for reminder in defaults {
            await add(reminder)
        }
    }

    /// Напоминания, требующие внимания (для бейджа на вкладке)
    func remindersNeedingAttention(currentMileage: Int) -> [Reminder] {
        reminders.filter {
            let s = $0.status(currentMileage: currentMileage)
            return s == .overdue || s == .soon
        }
    }

    // MARK: - Миграция

    /// Перенести данные из UserDefaults в Supabase (одноразово).
    /// Возвращает количество перенесённых напоминаний.
    @MainActor
    func migrateFromUserDefaults(userId: UUID) async -> Int {
        let key = "car_reminders_v1"

        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Reminder].self, from: data),
              !decoded.isEmpty
        else {
            return 0
        }

        do {
            let count = try await repository.bulkInsert(decoded, userId: userId)

            // Удаляем старый ключ — миграция завершена
            UserDefaults.standard.removeObject(forKey: key)

            if count > 0 {
                print("📤 Мигрировано напоминаний: \(count)")
            } else {
                print("ℹ️ Напоминания уже были в базе")
            }

            return count
        } catch {
            print("❌ Ошибка миграции напоминаний: \(error)")
            return 0
        }
    }

    // MARK: - Приватные

    private func sortReminders(_ reminders: [Reminder]) -> [Reminder] {
        reminders.sorted { lhs, rhs in
            statusOrder(lhs.status(currentMileage: 0)) <
            statusOrder(rhs.status(currentMileage: 0))
        }
    }

    private func statusOrder(_ status: ReminderStatus) -> Int {
        switch status {
        case .overdue: return 0
        case .soon: return 1
        case .ok: return 2
        case .disabled: return 3
        }
    }
}

// MARK: - Логика статуса (extension Reminder)

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
            if daysLeft < 30 { return .soon }
        }

        // Проверяем по пробегу
        if let nextMileage = nextMileage {
            let kmLeft = nextMileage - currentMileage

            if kmLeft < 0 { return .overdue }
            if kmLeft < 1_000 { return .soon }
        }

        return .ok
    }

    /// Сколько осталось до следующей замены (текстом)
    func remainingText(currentMileage: Int) -> String {
        guard isEnabled else { return "Выключено" }

        var parts: [String] = []

        if let nextMileage = nextMileage {
            let kmLeft = nextMileage - currentMileage
            if kmLeft < 0 {
                parts.append("просрочено на \(abs(kmLeft).formatted()) км")
            } else {
                parts.append("осталось \(kmLeft.formatted()) км")
            }
        }

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
