import SwiftUI

//проверка настройки гитХаба в ИксКоде
//проверка синхронизации с ГитХаб

@main
struct CarTrackerApp: App {
    @StateObject private var store = CarWorkStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
