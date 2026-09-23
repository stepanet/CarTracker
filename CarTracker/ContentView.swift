import SwiftUI

struct ContentView: View {
    @EnvironmentObject var reminderStore: ReminderStore

    var body: some View {
        TabView {
            WorksListView()
                .tabItem {
                    Label("Работы", systemImage: "list.bullet.rectangle")
                }

            StatsView()
                .tabItem {
                    Label("Статистика", systemImage: "chart.pie.fill")
                }

            RemindersView()
                .tabItem {
                    Label("Напоминания", systemImage: "bell.fill")
                }
                .badge(reminderStore.reminders.filter { $0.isEnabled }.count)
            
        }
    }
}
