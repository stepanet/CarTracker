import Foundation
import Combine

final class CarWorkStore: ObservableObject {
    @Published var works: [CarWork] = [] {
        didSet { save() }
    }
    
    private let saveKey = "car_works_v1"
    
    init() { load() }
    
    // MARK: - CRUD
    func add(_ work: CarWork) {
        var newWork = work
        // Если есть подработы — считаем стоимость автоматически
        if !newWork.subWorks.isEmpty {
            newWork.cost = newWork.subWorksTotal
        }
        works.append(newWork)
        sortWorks()
    }
    
    func update(_ work: CarWork) {
        guard let idx = works.firstIndex(where: { $0.id == work.id }) else { return }
        var updated = work
        // Если есть подработы — стоимость = сумма подработ
        if !updated.subWorks.isEmpty {
            updated.cost = updated.subWorksTotal
        }
        works[idx] = updated
        sortWorks()
    }
    
    func delete(_ work: CarWork) {
        works.removeAll { $0.id == work.id }
    }
    
    /// Заменить весь массив работ (используется при импорте бэкапа)
    func replaceAll(with newWorks: [CarWork]) {
        works = newWorks
        sortWorks()
    }
    
    func delete(at offsets: IndexSet, in list: [CarWork]) {
        let ids = offsets.map { list[$0].id }
        works.removeAll { ids.contains($0.id) }
    }
    
    // MARK: - Подзаписи (работы и детали)
    
    /// Добавить подзапись к работе
    func addSubItem(to workId: UUID, item: SubItem) {
        guard let index = works.firstIndex(where: { $0.id == workId }) else { return }
        works[index].subWorks.append(item)
        recalculateCost(at: index)
        sortWorks() // не обязательно, но подстрахуемся
    }
    
    /// Обновить подзапись
    func updateSubItem(in workId: UUID, item: SubItem) {
        guard let workIndex = works.firstIndex(where: { $0.id == workId }),
              let itemIndex = works[workIndex].subWorks.firstIndex(where: { $0.id == item.id })
                else { return }
        
        works[workIndex].subWorks[itemIndex] = item
        recalculateCost(at: workIndex)
    }
    
    /// Удалить подзапись
    func removeSubItem(from workId: UUID, itemId: UUID) {
        guard let workIndex = works.firstIndex(where: { $0.id == workId }) else { return }
        works[workIndex].subWorks.removeAll { $0.id == itemId }
        recalculateCost(at: workIndex)
    }
    
    /// Удалить все подзаписи работы
    func clearSubItems(from workId: UUID) {
        guard let workIndex = works.firstIndex(where: { $0.id == workId }) else { return }
        works[workIndex].subWorks.removeAll()
        recalculateCost(at: workIndex)
    }
    
    /// Пересчитать `cost` работы: если есть подзаписи — сумма подзаписей.
    /// Если подзаписей нет — оставляем введённое значение.
    private func recalculateCost(at index: Int) {
        let work = works[index]
        guard !work.subWorks.isEmpty else { return }
        works[index].cost = work.subWorksTotal
    }
    
    
    private func sortWorks() {
        works.sort { $0.date > $1.date }
    }
    
    // MARK: - Статистика
    var totalCost: Double {
        works.filter { $0.isDone }.reduce(0) { $0 + $1.cost }
    }
    
    var totalCostThisYear: Double {
        let year = Calendar.current.component(.year, from: Date())
        return works.filter {
            $0.isDone && Calendar.current.component(.year, from: $0.date) == year
        }.reduce(0) { $0 + $1.cost }
    }
    
    func costByCategory() -> [(WorkCategory: CarWork.WorkCategory, sum: Double)] {
        Dictionary(grouping: works.filter { $0.isDone }, by: { $0.category })
            .map { (key, value) in
                (WorkCategory: key, sum: value.reduce(0) { $0 + $1.cost })
            }
            .sorted { $0.sum > $1.sum }
    }
    
    // MARK: - Persistence
    private func save() {
        if let data = try? JSONEncoder().encode(works) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([CarWork].self, from: data)
                else { return }
        works = decoded
    }
    
    // MARK: - Данные для графиков
    
    /// Расходы по месяцам за последние N месяцев
    func monthlyCosts(monthsBack: Int = 6) -> [MonthlyCost] {
        let calendar = Calendar.current
        let now = Date()
        
        var result: [MonthlyCost] = []
        for offset in stride(from: monthsBack - 1, through: 0, by: -1) {
            guard let monthDate = calendar.date(
                byAdding: .month, value: -offset, to: now
            ) else { continue }
            
            let components = calendar.dateComponents([.year, .month], from: monthDate)
            let sum = works
                .filter { $0.isDone }
                .filter {
                    let c = calendar.dateComponents([.year, .month], from: $0.date)
                    return c.year == components.year && c.month == components.month
                }
                .reduce(0) { $0 + $1.cost }
            
            result.append(MonthlyCost(
                month: monthDate,
                label: Self.monthFormatter.string(from: monthDate),
                total: sum
            ))
        }
        return result
    }
    
    /// Расходы по категориям
    func categoryCosts() -> [CategoryCost] {
        Dictionary(grouping: works.filter { $0.isDone }, by: { $0.category })
            .map { (key, value) in
                CategoryCost(category: key, total: value.reduce(0) { $0 + $1.cost })
            }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }
    
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLL"
        return f
    }()
    
    // MARK: - Статистика 2.0 (работы / детали / топ позиций)
    
    /// Общая сумма работ (услуг) — из подзаписей типа .work
    var totalWorksCost: Double {
        works.filter { $0.isDone }
            .flatMap { $0.subWorks }
            .filter { $0.type == .work }
            .reduce(0) { $0 + $1.totalCost }
    }
    
    /// Общая сумма деталей — из подзаписей типа .part
    var totalPartsCost: Double {
        works.filter { $0.isDone }
            .flatMap { $0.subWorks }
            .filter { $0.type == .part }
            .reduce(0) { $0 + $1.totalCost }
    }
    
    /// Сумма работ и деталей по месяцам (для stacked bar)
    func monthlyCostsDetailed(monthsBack: Int = 6) -> [MonthlyCostDetailed] {
        let calendar = Calendar.current
        let now = Date()
        
        var result: [MonthlyCostDetailed] = []
        for offset in stride(from: monthsBack - 1, through: 0, by: -1) {
            guard let monthDate = calendar.date(
                byAdding: .month, value: -offset, to: now
            ) else { continue }
            
            let components = calendar.dateComponents([.year, .month], from: monthDate)
            
            // Все работы этого месяца
            let worksInMonth = works.filter {
                guard $0.isDone else { return false }
                let c = calendar.dateComponents([.year, .month], from: $0.date)
                return c.year == components.year && c.month == components.month
            }
            
            // Работы (услуги)
            let worksSum = worksInMonth
                .flatMap { $0.subWorks }
                .filter { $0.type == .work }
                .reduce(0) { $0 + $1.totalCost }
            
            // Детали
            let partsSum = worksInMonth
                .flatMap { $0.subWorks }
                .filter { $0.type == .part }
                .reduce(0) { $0 + $1.totalCost }
            
            // Работы БЕЗ подработ (только cost) — относим к "работам"
            // (потому что у таких работ обычно просто общая сумма)
            let worksWithoutSubs = worksInMonth
                .filter { $0.subWorks.isEmpty }
                .reduce(0) { $0 + $1.cost }
            
            result.append(MonthlyCostDetailed(
                month: monthDate,
                label: Self.monthFormatter.string(from: monthDate),
                worksTotal: worksSum + worksWithoutSubs,
                partsTotal: partsSum
            ))
        }
        return result
    }
    
    /// Топ-N затрат (работ или деталей) за всё время
    /// Возвращает агрегированные по названию позиции
    func topItems(type: SubItemType, limit: Int = 5) -> [TopItem] {
        // Собираем все подзаписи указанного типа
        let allItems = works
            .filter { $0.isDone }
            .flatMap { $0.subWorks }
            .filter { $0.type == type }
        
        // Группируем по названию (чтобы "Масло Mobil" суммировалось)
        var totals: [String: (sum: Double, count: Int)] = [:]
        for item in allItems {
            let key = item.title
            let current = totals[key] ?? (0, 0)
            totals[key] = (current.sum + item.totalCost, current.count + 1)
        }
        
        // Сортируем по убыванию суммы
        return totals
            .map { TopItem(title: $0.key, total: $0.value.sum, occurrences: $0.value.count) }
            .sorted { $0.total > $1.total }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Вспомогательные модели

struct MonthlyCost: Identifiable {
    let month: Date
    let label: String
    let total: Double
    var id: Date { month }
}

struct CategoryCost: Identifiable {
    let category: CarWork.WorkCategory
    let total: Double
    var id: String { category.rawValue }
}

// MARK: - Расширенные модели для статистики

struct MonthlyCostDetailed: Identifiable {
    let month: Date
    let label: String
    let worksTotal: Double
    let partsTotal: Double
    
    var id: Date { month }
    var total: Double { worksTotal + partsTotal }
}

struct TopItem: Identifiable {
    let title: String
    let total: Double
    let occurrences: Int
    
    var id: String { title }
}
