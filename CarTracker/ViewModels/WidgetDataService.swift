import Foundation

/// Сервис для подготовки и сохранения данных виджета.
/// Вызывается из приложения при изменениях.
@MainActor
final class WidgetDataService {

    static let shared = WidgetDataService()
    private init() {}

    /// Обновить данные виджета.
    /// Вызывать при любом изменении: работы, напоминания, активный ТС.
    func update(
        works: [CarWork],
        reminders: [Reminder],
        activeVehicle: Vehicle?,
        currentMileage: Int
    ) {
        let data = WidgetData(
            vehicleName: activeVehicle?.displayName ?? "CarTracker",
            vehicleType: activeVehicle?.type.rawValue ?? "car",
            topReminder: topReminder(from: reminders, currentMileage: currentMileage),
            monthTotal: monthTotal(from: works),
            monthName: currentMonthName(),
            updatedAt: Date()
        )

        data.save()
    }

    // MARK: - Приватные

    private func topReminder(
        from reminders: [Reminder],
        currentMileage: Int
    ) -> WidgetReminder? {
        let enabled = reminders.filter { $0.isEnabled }
        guard !enabled.isEmpty else { return nil }

        let sorted = enabled.sorted { lhs, rhs in
            priority(lhs.status(currentMileage: currentMileage)) <
            priority(rhs.status(currentMileage: currentMileage))
        }

        guard let top = sorted.first else { return nil }

        let statusString: String
        switch top.status(currentMileage: currentMileage) {
        case .overdue: statusString = "overdue"
        case .soon: statusString = "soon"
        case .ok: statusString = "ok"
        case .disabled: statusString = "disabled"
        }

        return WidgetReminder(
            title: top.title,
            status: statusString,
            remainingText: top.remainingText(currentMileage: currentMileage)
        )
    }

    private func priority(_ status: ReminderStatus) -> Int {
        switch status {
        case .overdue: return 0
        case .soon: return 1
        case .ok: return 2
        case .disabled: return 3
        }
    }

    private func monthTotal(from works: [CarWork]) -> Double {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        return works
            .filter { $0.isDone }
            .filter {
                let c = calendar.dateComponents([.year, .month], from: $0.date)
                return c.year == year && c.month == month
            }
            .reduce(0) { $0 + $1.cost }
    }

    private func currentMonthName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: Date()).capitalized
    }
}
