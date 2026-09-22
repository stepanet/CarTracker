import Foundation
import BackgroundTasks

/// Менеджер фоновых задач.
/// Регистрирует задачу в системе и планирует её выполнение.
final class BackgroundTaskManager {

    static let shared = BackgroundTaskManager()
    private init() {}

    /// Идентификатор задачи — должен совпадать с Info.plist
    private let refreshTaskIdentifier = "com.cartracker.app.refresh"

    /// Замыкание, которое вызывается при пробуждении приложения.
    /// Устанавливается из CarTrackerApp, чтобы менеджер не зависел от хранилищ.
    var onRefreshNeeded: (() -> Void)?

    // MARK: - Регистрация

    /// Вызывать один раз при старте приложения, до окончания запуска
    func registerTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else { return }
            self?.handleAppRefresh(task: task)
        }
    }

    // MARK: - Планирование

    /// Запланировать следующую фоновую проверку.
    /// Вызывается при старте и после каждого выполнения задачи.
    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)

        // Новый API для iOS 27+
        BGTaskScheduler.shared.submitTaskRequest(request) { error in
            if let error = error {
                print("❌ Не удалось запланировать фоновую задачу: \(error)")
            } else {
                print("✅ Фоновая задача запланирована")
            }
        }
    }

    // MARK: - Обработка пробуждения

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Сразу планируем следующую — правило BGTaskScheduler
        scheduleRefresh()

        // Даём задаче время на выполнение
        let refreshTask = Task {
            // Даём менеджеру знать, что пора пересчитать уведомления
            onRefreshNeeded?()
            task.setTaskCompleted(success: true)
        }

        // Обработка отмены: система может прервать задачу в любой момент
        task.expirationHandler = {
            refreshTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
