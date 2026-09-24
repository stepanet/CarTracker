import SwiftUI
import Auth
import Foundation

@main
struct CarTrackerApp: App {
    @StateObject private var workStore = CarWorkStore()
    @StateObject private var reminderStore = ReminderStore()
    @StateObject private var authManager = AuthManager.shared

    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundTaskManager.shared.registerTask()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let user = authManager.user {
                    ContentView()
                        .environmentObject(workStore)
                        .environmentObject(reminderStore)
                        .environmentObject(authManager)
                        .task {
                            // Загрузка данных при появлении основного экрана
                            await bootstrap(userId: user.id)
                        }
                } else {
                    AuthView()
                        .environmentObject(authManager)
                }
            }
            .environment(\.locale, Locale(identifier: "ru_RU"))
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                if let user = authManager.user {
                    Task {
                        await workStore.loadWorks(userId: user.id)
                        await workStore.unsubscribeRealtime()
                        workStore.subscribeRealtime(userId: user.id)

                        await reminderStore.loadReminders(userId: user.id)
                        await reminderStore.unsubscribeRealtime()
                        reminderStore.subscribeRealtime(userId: user.id)
                    }
                }
                rescheduleNotifications()
            } else if newPhase == .background {
                BackgroundTaskManager.shared.scheduleRefresh()
            }
        }
    }

    // MARK: - Bootstrap

    /// Загрузка данных при входе пользователя
    @MainActor
    private func bootstrap(userId: UUID) async {
        // 1. Миграция UserDefaults → Supabase
        let migratedWorks = await workStore.migrateFromUserDefaults(userId: userId)
        if migratedWorks > 0 {
            print("📤 Мигрировано работ: \(migratedWorks)")
        }

        let migratedReminders = await reminderStore.migrateFromUserDefaults(userId: userId)
        if migratedReminders > 0 {
            print("📤 Мигрировано напоминаний: \(migratedReminders)")
        }

        // 2. Загрузка из Supabase
        await workStore.loadWorks(userId: userId)
        await reminderStore.loadReminders(userId: userId)

        // 3. Подписки Realtime
        workStore.subscribeRealtime(userId: userId)
        reminderStore.subscribeRealtime(userId: userId)

        // 4. Остальные настройки
        setupBackgroundTask()
        handleFirstLaunch()
        rescheduleNotifications()
    }

    // MARK: - Фоновые задачи

    private func setupBackgroundTask() {
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
        BackgroundTaskManager.shared.scheduleRefresh()
    }

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
