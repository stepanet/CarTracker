import Foundation
import WidgetKit    // ← ДОБАВИТЬ

/// Данные для виджета — сериализуются в App Group UserDefaults.
struct WidgetData: Codable {

    /// Имя активного транспорта
    var vehicleName: String

    /// Тип активного транспорта (raw value: "car", "motorcycle", ...)
    var vehicleType: String

    /// Топ напоминаний (по статусу: overdue → soon → ok)
    var reminders: [WidgetReminder]

    /// Расходы за текущий месяц
    var monthTotal: Double

    /// Название текущего месяца ("октябрь")
    var monthName: String

    /// Когда последний раз обновляли (для отладки)
    var updatedAt: Date

    /// Пустой объект
    static let empty = WidgetData(
        vehicleName: "CarTracker",
        vehicleType: "car",
        reminders: [],
        monthTotal: 0,
        monthName: "",
        updatedAt: Date()
    )
}

/// Данные одного напоминания для виджета
struct WidgetReminder: Codable, Identifiable {
    var id: String { title + status }
    var title: String
    var status: String          // "ok" | "soon" | "overdue" | "disabled"
    var remainingText: String   // "осталось 850 км • через 12 дн."
}

// MARK: - Сохранение / загрузка

extension WidgetData {

    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            AppGroup.defaults.set(data, forKey: AppGroup.Key.widgetData)
            print("💾 WidgetData сохранён: \(vehicleName), напоминаний: \(reminders.count)")

            // Просим iOS обновить виджет сразу
            WidgetCenter.shared.reloadAllTimelines()
            print("🔄 Виджет: запрошено обновление")
        } catch {
            print("❌ Ошибка сохранения WidgetData: \(error)")
        }
    }

    static func load() -> WidgetData {
        guard let data = AppGroup.defaults.data(forKey: AppGroup.Key.widgetData),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data)
        else {
            return .empty
        }
        return decoded
    }
}
