import Foundation
import UserNotifications

/// Менеджер локальных уведомлений о ТО
final class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    /// Идентификатор-префикс, чтобы легко находить наши уведомления
    private let idPrefix = "reminder_"

    // MARK: - Разрешение

    /// Запросить разрешение у пользователя (при первом запуске)
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Не удалось получить разрешение: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    /// Проверить текущий статус разрешения
    func checkAuthorization(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            let granted = settings.authorizationStatus == .authorized
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Планирование

    /// Пересчитать уведомления на основе текущего состояния напоминаний.
    /// Сначала удаляем все старые, потом ставим новые.
    func reschedule(reminders: [Reminder], currentMileage: Int) {
        // Удаляем все старые уведомления с нашим префиксом
        cancelAllReminders()

        for reminder in reminders where reminder.isEnabled {
            let status = reminder.status(currentMileage: currentMileage)

            switch status {
            case .overdue:
                // Просрочено — напомнить прямо сейчас (через 1 секунду)
                schedule(
                    for: reminder,
                    currentMileage: currentMileage,
                    fireDate: Date().addingTimeInterval(1)
                )
            case .soon:
                // Скоро — напомнить через сутки в 10:00
                let tomorrow = Calendar.current.date(
                    byAdding: .day, value: 1, to: Date()
                ) ?? Date()
                let fireDate = Calendar.current.date(
                    bySettingHour: 10, minute: 0, second: 0, of: tomorrow
                ) ?? tomorrow
                schedule(for: reminder, currentMileage: currentMileage, fireDate: fireDate)
            case .ok, .disabled:
                continue
            }
        }
    }

    /// Поставить одно уведомление
    private func schedule(for reminder: Reminder, currentMileage: Int, fireDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "CarTracker"
        content.body = ReminderCalculator.notificationBody(
            for: reminder,
            currentMileage: currentMileage
        )
        content.sound = .default
        content.userInfo = ["reminderId": reminder.id.uuidString]

        // Если fireDate уже в прошлом — стреляем через 5 секунд
        let fireInterval = max(fireDate.timeIntervalSinceNow, 5)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: fireInterval,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: idPrefix + reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("❌ Ошибка планирования уведомления: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Отмена

    /// Удалить все уведомления-напоминания
    func cancelAllReminders() {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(self.idPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Удалить уведомление для конкретного напоминания
    func cancel(for reminder: Reminder) {
        center.removePendingNotificationRequests(
            withIdentifiers: [idPrefix + reminder.id.uuidString]
        )
    }

    // MARK: - Отладка

    /// Вывести в консоль список запланированных уведомлений (для отладки)
    func printPending() {
        center.getPendingNotificationRequests { requests in
            let ours = requests.filter { $0.identifier.hasPrefix(self.idPrefix) }
            print("📅 Запланировано напоминаний: \(ours.count)")
            for request in ours {
                print("   • \(request.identifier) — \(request.content.body)")
            }
        }
    }
}
