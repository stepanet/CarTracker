import Foundation

// ═══════════════════════════════════════════════
// Тип транспорта
// ═══════════════════════════════════════════════

enum VehicleType: String, Codable, CaseIterable, Identifiable {
    case car = "car"
    case motorcycle = "motorcycle"
    case scooter = "scooter"
    case snowblower = "snowblower"
    case lawnmower = "lawnmower"
    case tiller = "tiller"
    case generator = "generator"
    case atv = "atv"
    case boat = "boat"
    case trailer = "trailer"
    case other = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .car: return "Машина"
        case .motorcycle: return "Мотоцикл"
        case .scooter: return "Скутер"
        case .snowblower: return "Снегоуборщик"
        case .lawnmower: return "Газонокосилка"
        case .tiller: return "Мотоблок"
        case .generator: return "Генератор"
        case .atv: return "Квадроцикл"
        case .boat: return "Лодка"
        case .trailer: return "Прицеп"
        case .other: return "Другое"
        }
    }

    /// SF Symbol для UI
    var icon: String {
        switch self {
        case .car: return "car.fill"
        case .motorcycle: return "bicycle"
        case .scooter: return "scooter"
        case .snowblower: return "snowflake"
        case .lawnmower: return "leaf.fill"
        case .tiller: return "tractor"        // может отсутствовать — заменить
        case .generator: return "bolt.fill"
        case .atv: return "car.2.fill"
        case .boat: return "sailboat.fill"
        case .trailer: return "box.truck.fill"
        case .other: return "shippingbox.fill"
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
