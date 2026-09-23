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
    
    // MARK: - Кастомное декодирование
    // Нужно для чтения старых бэкапов, где нет поля subWorks

    enum CodingKeys: String, CodingKey {
        case id, title, category, date, mileage, cost, note, isDone, subWorks
    }
    
    // MARK: - Инициализатор (нужен, потому что при кастомном init(from:)
    // Swift не генерирует memberwise-инициализатор автоматически)

    init(
        id: UUID = UUID(),
        title: String,
        category: WorkCategory,
        date: Date,
        mileage: Int,
        cost: Double,
        note: String,
        isDone: Bool = true,
        subWorks: [SubItem] = []
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.date = date
        self.mileage = mileage
        self.cost = cost
        self.note = note
        self.isDone = isDone
        self.subWorks = subWorks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(WorkCategory.self, forKey: .category)
        date = try container.decode(Date.self, forKey: .date)
        mileage = try container.decode(Int.self, forKey: .mileage)
        cost = try container.decode(Double.self, forKey: .cost)
        note = try container.decode(String.self, forKey: .note)
        isDone = try container.decode(Bool.self, forKey: .isDone)
        subWorks = try container.decodeIfPresent([SubItem].self, forKey: .subWorks) ?? []
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
