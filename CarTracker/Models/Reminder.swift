import Foundation

struct Reminder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var vehicleId: UUID?            // ← привязка к транспорту
    var title: String
    var icon: String
    var intervalKm: Int
    var intervalMonths: Int
    var lastDate: Date
    var lastMileage: Int
    var isEnabled: Bool = true

    // MARK: - Кастомное декодирование

    enum CodingKeys: String, CodingKey {
        case id, vehicleId, title, icon
        case intervalKm, intervalMonths
        case lastDate, lastMileage, isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        vehicleId = try container.decodeIfPresent(UUID.self, forKey: .vehicleId)
        title = try container.decode(String.self, forKey: .title)
        icon = try container.decode(String.self, forKey: .icon)
        intervalKm = try container.decode(Int.self, forKey: .intervalKm)
        intervalMonths = try container.decode(Int.self, forKey: .intervalMonths)
        lastDate = try container.decode(Date.self, forKey: .lastDate)
        lastMileage = try container.decode(Int.self, forKey: .lastMileage)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }

    // MARK: - Инициализатор

    init(
        id: UUID = UUID(),
        vehicleId: UUID? = nil,
        title: String,
        icon: String,
        intervalKm: Int,
        intervalMonths: Int,
        lastDate: Date,
        lastMileage: Int,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.title = title
        self.icon = icon
        self.intervalKm = intervalKm
        self.intervalMonths = intervalMonths
        self.lastDate = lastDate
        self.lastMileage = lastMileage
        self.isEnabled = isEnabled
    }

    // MARK: - Вычисляемые значения

    /// Следующая дата замены (если задан интервал в месяцах)
    var nextDate: Date? {
        guard intervalMonths > 0 else { return nil }
        return Calendar.current.date(
            byAdding: .month,
            value: intervalMonths,
            to: lastDate
        )
    }

    /// Следующий пробег для замены (если задан интервал в км)
    var nextMileage: Int? {
        guard intervalKm > 0 else { return nil }
        return lastMileage + intervalKm
    }

    /// Описание интервала для отображения
    var intervalDescription: String {
        var parts: [String] = []
        if intervalKm > 0 {
            parts.append("каждые \(intervalKm.formatted()) км")
        }
        if intervalMonths > 0 {
            let word = monthsWord(intervalMonths)
            parts.append("каждые \(intervalMonths) \(word)")
        }
        return parts.isEmpty ? "интервал не задан" : parts.joined(separator: " или ")
    }

    private func monthsWord(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "месяцев" }
        switch mod10 {
        case 1: return "месяц"
        case 2, 3, 4: return "месяца"
        default: return "месяцев"
        }
    }
}

// MARK: - Статус напоминания

enum ReminderStatus {
    case ok
    case soon
    case overdue
    case disabled

    var color: String {
        switch self {
        case .ok: return "green"
        case .soon: return "yellow"
        case .overdue: return "red"
        case .disabled: return "gray"
        }
    }

    var label: String {
        switch self {
        case .ok: return "В порядке"
        case .soon: return "Скоро"
        case .overdue: return "Пора"
        case .disabled: return "Выключено"
        }
    }
}
