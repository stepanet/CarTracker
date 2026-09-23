import Foundation

/// Тип подзаписи: работа (услуга) или деталь (запчасть)
enum SubItemType: String, Codable, CaseIterable, Identifiable {
    case work = "work"    // Работа — «Замена масла»
    case part = "part"    // Деталь — «Масло Mobil 5W-30»

    var id: String { rawValue }

    var label: String {
        switch self {
        case .work: return "Работа"
        case .part: return "Деталь"
        }
    }

    var icon: String {
        switch self {
        case .work: return "wrench.adjustable.fill"
        case .part: return "shippingbox.fill"
        }
    }
}

/// Подзапись внутри работы (например, внутри ТО).
/// Может быть работой (услугой) или деталью (запчастью).
struct SubItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var type: SubItemType
    var title: String               // «Замена масла» или «Масло Mobil 5W-30»
    var quantity: Double = 1        // Для деталей: 4 свечи, 4л масла
    var unitPrice: Double           // Цена за единицу
    var note: String = ""           // Артикул, бренд, комментарий

    // MARK: - Кастомное декодирование (для совместимости)

    enum CodingKeys: String, CodingKey {
        case id, type, title, quantity, unitPrice, note
    }

    
    init(
        id: UUID = UUID(),
        type: SubItemType,
        title: String,
        quantity: Double = 1,
        unitPrice: Double,
        note: String = ""
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.note = note
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(SubItemType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        quantity = try container.decodeIfPresent(Double.self, forKey: .quantity) ?? 1
        unitPrice = try container.decode(Double.self, forKey: .unitPrice)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
    
    /// Итоговая стоимость: количество × цена
    var totalCost: Double {
        quantity * unitPrice
    }

    /// Отформатированное описание количества и цены
    /// Например: «4 × 565 ₽» или «1 × 3 500 ₽»
    var quantityDescription: String {
        let qty = formatQuantity(quantity)
        let price = formatPrice(unitPrice)
        return "\(qty) × \(price)"
    }

    private func formatQuantity(_ value: Double) -> String {
        if value == floor(value) {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }

    private func formatPrice(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₽"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value)) ₽"
    }
}
