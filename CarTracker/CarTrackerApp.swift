import SwiftUI

@main
struct CarTrackerApp: App {
    @StateObject private var workStore = CarWorkStore()
    @StateObject private var reminderStore = ReminderStore()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workStore)
                .environmentObject(reminderStore)
                .onAppear {
                    handleFirstLaunch()
                    rescheduleNotifications()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Когда возвращаемся из фона — пересчитываем уведомления
            // (мог измениться пробег, дата, статус)
            if newPhase == .active {
                rescheduleNotifications()
            }
        }
    }

    // MARK: - Первый запуск
    private func handleFirstLaunch() {
        let key = "did_request_notifications_v1"
        let didRequest = UserDefaults.standard.bool(forKey: key)

        if !didRequest {
            // Запрашиваем разрешение через небольшую задержку,
            // чтобы UI успел появиться (иначе алерт «прилипнет» к splash)
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
