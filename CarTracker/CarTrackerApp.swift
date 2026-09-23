import SwiftUI

@main
struct CarTrackerApp: App {
    @StateObject private var workStore = CarWorkStore()
    @StateObject private var reminderStore = ReminderStore()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Регистрируем фоновую задачу при запуске приложения.
        // Это должно произойти до окончания запуска — init() подходит.
        BackgroundTaskManager.shared.registerTask()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workStore)
                .environmentObject(reminderStore)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .onAppear {
                    setupBackgroundTask()
                    handleFirstLaunch()
                    rescheduleNotifications()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                rescheduleNotifications()
            } else if newPhase == .background {
                // Когда уходим в фон — планируем фоновую проверку
                BackgroundTaskManager.shared.scheduleRefresh()
            }
        }
    }

    // MARK: - Настройка фоновой задачи
    private func setupBackgroundTask() {
        // При пробуждении система вызовет это замыкание
        BackgroundTaskManager.shared.onRefreshNeeded = { [weak workStore, weak reminderStore] in
            guard let workStore = workStore,
                  let reminderStore = reminderStore else { return }

            let currentMileage = ReminderCalculator.currentMileage(
                from: workStore.works,
                reminders: reminderStore.reminders
            )
            NotificationManager.shared.reschedule(
                reminders: reminderStore.reminders,
                currentMileage: currentMileage
            )
            print("🔄 Фоновая проверка напоминаний выполнена")
        }

        // Планируем первую проверку сразу после запуска
        BackgroundTaskManager.shared.scheduleRefresh()
    }

    // MARK: - Первый запуск
    private func handleFirstLaunch() {
        let key = "did_request_notifications_v1"
        let didRequest = UserDefaults.standard.bool(forKey: key)

        if !didRequest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NotificationManager.shared.requestAuthorization { granted in
                    print("🔔 Разрешение на уведомления: \(granted ? "да" : "нет")")
                }
            }
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    // MARK: - Пересчёт уведомлений
    private func rescheduleNotifications() {
        let currentMileage = ReminderCalculator.currentMileage(
            from: workStore.works,
            reminders: reminderStore.reminders
        )
        NotificationManager.shared.reschedule(
            reminders: reminderStore.reminders,
            currentMileage: currentMileage
        )
    }
}
