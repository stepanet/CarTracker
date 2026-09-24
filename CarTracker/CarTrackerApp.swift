import SwiftUI

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
                if authManager.user != nil {
                    ContentView()
                        .environmentObject(workStore)
                        .environmentObject(reminderStore)
                        .environmentObject(authManager)
                        .onAppear {
                            setupBackgroundTask()
                            handleFirstLaunch()
                            rescheduleNotifications()
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
                rescheduleNotifications()
            } else if newPhase == .background {
                BackgroundTaskManager.shared.scheduleRefresh()
            }
        }
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
