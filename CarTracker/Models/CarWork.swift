import Foundation

struct CarWork: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String           // Название работы
    var category: WorkCategory  // Категория
    var date: Date              // Дата выполнения
    var mileage: Int            // Пробег (км)
    var cost: Double            // Стоимость
    var note: String            // Заметки
    var isDone: Bool = true     // Выполнено/запланировано
    var subWorks: [SubItem] = []    // ← НОВОЕ ПОЛЕ
    
    /// Есть ли у работы подзаписи (работы или детали)
    var hasSubItems: Bool {
        !subWorks.isEmpty
    }

    /// Количество работ
    var worksCount: Int {
        subWorks.filter { $0.type == .work }.count
    }

    /// Количество деталей
    var partsCount: Int {
        subWorks.filter { $0.type == .part }.count
    }

    /// Общая стоимость подзаписей
    var subWorksTotal: Double {
        subWorks.reduce(0) { $0 + $1.totalCost }
    }

    enum WorkCategory: String, Codable, CaseIterable, Identifiable {
        case maintenance = "ТО"
        case repair = "Ремонт"
        case tires = "Шины"
        case fuel = "Топливо"
        case insurance = "Страховка"
        case other = "Прочее"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .maintenance: return "wrench.and.screwdriver.fill"
            case .repair: return "hammer.fill"
            case .tires: return "circle.circle.fill"
            case .fuel: return "fuelpump.fill"
            case .insurance: return "shield.lefthalf.filled"
            case .other: return "ellipsis.circle.fill"
            }
        }
    }
}
