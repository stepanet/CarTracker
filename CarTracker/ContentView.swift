import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WorksListView()
                .tabItem {
                    Label("Работы", systemImage: "list.bullet.rectangle")
                }
                .tag(0)

            StatsView()
                .tabItem {
                    Label("Статистика", systemImage: "chart.pie.fill")
                }
                .tag(1)

            RemindersView()
                .tabItem {
                    Label("Напоминания", systemImage: "bell.fill")
                }
                .tag(2)

            GarageView()
                .tabItem {
                    Label("Гараж", systemImage: "car.2.fill")
                }
                .tag(3)
        }
    }
}
