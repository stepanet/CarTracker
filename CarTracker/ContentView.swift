import SwiftUI

struct ContentView: View {
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
        }
    }
}
