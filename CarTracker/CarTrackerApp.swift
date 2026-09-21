import SwiftUI

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
