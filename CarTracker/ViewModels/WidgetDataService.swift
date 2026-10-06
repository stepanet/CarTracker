import Foundation

/// Сервис для подготовки и сохранения данных виджета.
@MainActor
final class WidgetDataService {

    static let shared = WidgetDataService()
    private init() {}

    /// Максимум напоминаний для виджета
    private let maxReminders = 5

    /// Обновить данные виджета.
    func update(
        works: [CarWork],
        reminders: [Reminder],
        activeVehicle: Vehicle?,
        currentMileage: Int
    ) {
        let data = WidgetData(
            vehicleName: activeVehicle?.displayName ?? "CarTracker",
            vehicleType: activeVehicle?.type.rawValue ?? "car",
            reminders: topReminders(from: reminders, currentMileage: currentMileage),
            monthTotal: monthTotal(from: works),
            monthName: currentMonthName(),
            updatedAt: Date()
        )

        data.save()
    }

    // MARK: - Приватные

    /// Топ-N напоминаний: сначала overdue, потом soon, потом ok
    private func topReminders(
        from reminders: [Reminder],
        currentMileage: Int
    ) -> [WidgetReminder] {
        let enabled = reminders.filter { $0.isEnabled }
        guard !enabled.isEmpty else { return [] }

        // Сортируем: overdue → soon → ok
        let sorted = enabled.sorted { lhs, rhs in
            priority(lhs.status(currentMileage: currentMileage)) <
            priority(rhs.status(currentMileage: currentMileage))
        }

        // Берём первые N
        return sorted.prefix(maxReminders).map { reminder in
            let statusString: String
            switch reminder.status(currentMileage: currentMileage) {
            case .overdue: statusString = "overdue"
            case .soon: statusString = "soon"
            case .ok: statusString = "ok"
            case .disabled: statusString = "disabled"
            }

            return WidgetReminder(
                title: reminder.title,
                status: statusString,
                remainingText: reminder.remainingText(currentMileage: currentMileage)
            )
        }
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
