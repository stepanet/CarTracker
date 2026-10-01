import Foundation

// ═══════════════════════════════════════════════
// Тип транспорта
// ═══════════════════════════════════════════════

enum VehicleType: String, Codable, CaseIterable, Identifiable {
    case car = "car"
    case motorcycle = "motorcycle"
    case scooter = "scooter"
    case other = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .car: return "Машина"
        case .motorcycle: return "Мотоцикл"
        case .scooter: return "Скутер"
        case .other: return "Другое"
        }
    }

    /// SF Symbol для UI
    var icon: String {
        switch self {
        case .car: return "car.fill"
        case .motorcycle: return "bicycle"       // SF Symbols не имеет motorcycle
        case .scooter: return "scooter"
        case .other: return "box.truck.fill"
        }
    }
}

// ═══════════════════════════════════════════════
// Модель Vehicle
// ═══════════════════════════════════════════════

struct Vehicle: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String                    // "Toyota Camry" / "Honda CB500F"
    var type: VehicleType               // car / motorcycle / scooter / other
    var plate: String = ""              // госномер
    var year: Int?                      // год выпуска
    var icon: String = "car"            // ключ иконки (car / bike / truck)
    var initialMileage: Int = 0         // начальный пробег
    var isDefault: Bool = false         // "по умолчанию"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Отображаемое имя
    var displayName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty
            ? type.label
            : name
    }

    /// Подзаголовок: "А123БВ 77 · 2018 г."
    var subtitle: String {
        var parts: [String] = []
        if !plate.isEmpty { parts.append(plate) }
        if let year = year { parts.append("\(year) г.") }
        return parts.joined(separator: " · ")
    }
}
