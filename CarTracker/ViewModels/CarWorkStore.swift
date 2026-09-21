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
        works.append(work)
        sortWorks()
    }

    func update(_ work: CarWork) {
        if let idx = works.firstIndex(where: { $0.id == work.id }) {
            works[idx] = work
            sortWorks()
        }
    }

    func delete(_ work: CarWork) {
        works.removeAll { $0.id == work.id }
    }

    func delete(at offsets: IndexSet, in list: [CarWork]) {
        let ids = offsets.map { list[$0].id }
        works.removeAll { ids.contains($0.id) }
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
