import Foundation

enum AppGroup {
    static let identifier = "group.com.stepanet.CarTracker"   // ← ваш ID
    static let defaults = UserDefaults(suiteName: identifier) ?? .standard
    enum Key {
        static let widgetData = "widget_data_v1"
    }
}
