import Foundation
import Combine

/// Хранилище напоминаний.
final class ReminderStore: ObservableObject {

    @Published var reminders: [Reminder] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let repository = RemindersRepository.shared
    private let realtime = RealtimeManager.shared
    private var userId: UUID?

    init() {}

    // MARK: - Загрузка / Realtime

    @MainActor
    func loadReminders(userId: UUID) async {
        self.userId = userId
        isLoading = true
        error = nil

        do {
            let activeVehicleId = VehicleStore.shared.activeVehicleId

            let fetched = try await repository.fetchAll(
                userId: userId,
                vehicleId: activeVehicleId
            )
            self.reminders = sortReminders(fetched)
            isLoading = false

            let vehicleInfo = activeVehicleId?.uuidString.prefix(8) ?? "все"
            print("✅ Загружено напоминаний: \(fetched.count) (ТС: \(vehicleInfo))")
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            print("❌ Ошибка загрузки напоминаний: \(error)")
        }
    }
    
    @MainActor
    func reload() async {
        guard let userId = userId else {
            print("⚠️ Нет userId для reload напоминаний")
            return
        }
        await loadReminders(userId: userId)
    }

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

    @MainActor
    func unsubscribeRealtime() async {
        realtime.onRemindersChanged = nil
        await realtime.unsubscribeReminders()
    }

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

        var withVehicle = reminder
        if withVehicle.vehicleId == nil {
            withVehicle.vehicleId = VehicleStore.shared.activeVehicleId
        }

        var newReminders: [Reminder] = reminders
        newReminders.append(withVehicle)
        reminders = sortReminders(newReminders)

        do {
            try await repository.create(withVehicle, userId: userId)
        } catch {
            reminders.removeAll { $0.id == withVehicle.id }
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

        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = reminder
            reminders = sortReminders(reminders)
        }

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
    func remove(_ reminder: Reminder) async {
        let previous: [Reminder] = reminders

        reminders.removeAll { $0.id == reminder.id }

        do {
            try await repository.delete(id: reminder.id)
        } catch {
            reminders = previous
            self.error = error.localizedDescription
            print("❌ Ошибка удаления напоминания: \(error)")
        }
    }

    // MARK: - Действия

    @MainActor
    func markDone(_ reminder: Reminder, currentMileage: Int) async {
        var updated = reminder
        updated.lastDate = Date()
        updated.lastMileage = currentMileage
        await update(updated)
    }

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

    func remindersNeedingAttention(currentMileage: Int) -> [Reminder] {
        reminders.filter {
            let s = $0.status(currentMileage: currentMileage)
            return s == .overdue || s == .soon
        }
    }

    // MARK: - Миграция

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
            let result = try await repository.bulkInsert(decoded, userId: userId)

            UserDefaults.standard.removeObject(forKey: key)

            if result.skipped > 0 {
                print("ℹ️ Напоминания: добавлено \(result.inserted), пропущено \(result.skipped)")
            }

            return result.inserted
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
    func status(currentMileage: Int) -> ReminderStatus {
        guard isEnabled else { return .disabled }

        if let nextDate = nextDate {
            let daysLeft = Calendar.current.dateComponents(
                [.day],
                from: Date(),
                to: nextDate
            ).day ?? 0

            if daysLeft < 0 { return .overdue }
            if daysLeft < 30 { return .soon }
        }

        if let nextMileage = nextMileage {
            let kmLeft = nextMileage - currentMileage

            if kmLeft < 0 { return .overdue }
            if kmLeft < 1_000 { return .soon }
        }

        return .ok
    }

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
