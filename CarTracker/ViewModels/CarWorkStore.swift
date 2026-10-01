import Foundation
import Combine

/// Хранилище работ.
final class CarWorkStore: ObservableObject {

    @Published var works: [CarWork] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let repository = WorksRepository.shared
    private let realtime = RealtimeManager.shared
    private var userId: UUID?

    init() {}

    // MARK: - Загрузка / Realtime

    @MainActor
    func loadWorks(userId: UUID) async {
        self.userId = userId
        isLoading = true
        error = nil

        do {
            let activeVehicleId = VehicleStore.shared.activeVehicleId

            let fetched = try await repository.fetchAll(
                userId: userId,
                vehicleId: activeVehicleId
            )
            self.works = sortWorks(fetched)
            isLoading = false

            let vehicleInfo = activeVehicleId?.uuidString.prefix(8) ?? "все"
            print("✅ Загружено работ: \(fetched.count) (ТС: \(vehicleInfo))")
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            print("❌ Ошибка загрузки работ: \(error)")
        }
    }
    
    @MainActor
    func reload() async {
        guard let userId = userId else {
            print("⚠️ Нет userId для reload работ")
            return
        }
        await loadWorks(userId: userId)
    }

    @MainActor
    func subscribeRealtime(userId: UUID) {
        realtime.onWorksChanged = { [weak self] in
            guard let self = self else { return }
            Task {
                await self.loadWorks(userId: userId)
            }
        }

        realtime.subscribeWorks(userId: userId)
    }

    @MainActor
    func unsubscribeRealtime() async {
        realtime.onWorksChanged = nil
        await realtime.unsubscribeWorks()
    }

    @MainActor
    func clear() {
        works = []
        userId = nil
        error = nil
    }

    // MARK: - CRUD

    @MainActor
    func add(_ work: CarWork) async {
        guard let userId = userId else {
            error = "Не авторизован"
            return
        }

        // Проставляем активный транспорт, если не задан
        var withVehicle = work
        if withVehicle.vehicleId == nil {
            withVehicle.vehicleId = VehicleStore.shared.activeVehicleId
        }

        let normalized: CarWork = normalizeCost(withVehicle)

        var newWorks: [CarWork] = works
        newWorks.append(normalized)
        works = sortWorks(newWorks)

        do {
            try await repository.create(normalized, userId: userId)
        } catch {
            works.removeAll { $0.id == normalized.id }
            self.error = error.localizedDescription
            print("❌ Ошибка создания работы: \(error)")
        }
    }

    @MainActor
    func update(_ work: CarWork) async {
        guard let userId = userId else {
            error = "Не авторизован"
            return
        }

        let normalized: CarWork = normalizeCost(work)
        let previous: CarWork? = works.first { $0.id == work.id }

        if let index = works.firstIndex(where: { $0.id == normalized.id }) {
            works[index] = normalized
            works = sortWorks(works)
        }

        do {
            try await repository.update(normalized, userId: userId)
        } catch {
            if let prev = previous,
               let index = works.firstIndex(where: { $0.id == prev.id }) {
                works[index] = prev
                works = sortWorks(works)
            }
            self.error = error.localizedDescription
            print("❌ Ошибка обновления работы: \(error)")
        }
    }

    @MainActor
    func remove(_ work: CarWork) async {
        let previous: [CarWork] = works

        works.removeAll { $0.id == work.id }

        do {
            try await repository.delete(id: work.id)
        } catch {
            works = previous
            self.error = error.localizedDescription
            print("❌ Ошибка удаления работы: \(error)")
        }
    }

    // MARK: - Подработы

    @MainActor
    func addSubItem(to workId: UUID, item: SubItem) async {
        guard let work = works.first(where: { $0.id == workId }) else { return }
        var updated: CarWork = work
        updated.subWorks.append(item)
        await update(updated)
    }

    @MainActor
    func updateSubItem(in workId: UUID, item: SubItem) async {
        guard let work = works.first(where: { $0.id == workId }) else { return }
        var updated: CarWork = work
        if let index = updated.subWorks.firstIndex(where: { $0.id == item.id }) {
            updated.subWorks[index] = item
        }
        await update(updated)
    }

    @MainActor
    func removeSubItem(from workId: UUID, itemId: UUID) async {
        guard let work = works.first(where: { $0.id == workId }) else { return }
        var updated: CarWork = work
        updated.subWorks.removeAll { $0.id == itemId }
        await update(updated)
    }

    // MARK: - Миграция

    @MainActor
    func migrateFromUserDefaults(userId: UUID) async -> Int {
        let key = "car_works_v1"

        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CarWork].self, from: data),
              !decoded.isEmpty
        else {
            return 0
        }

        do {
            let result = try await repository.bulkInsert(decoded, userId: userId)

            UserDefaults.standard.removeObject(forKey: key)

            if result.skipped > 0 {
                print("ℹ️ Работы: добавлено \(result.inserted), пропущено \(result.skipped)")
            }

            return result.inserted
        } catch {
            print("❌ Ошибка миграции работ: \(error)")
            return 0
        }
    }

    // MARK: - Утилиты

    var totalCost: Double {
        works.filter { $0.isDone }.reduce(0) { $0 + $1.cost }
    }

    var totalCostThisYear: Double {
        let year = Calendar.current.component(.year, from: Date())
        return works
            .filter {
                $0.isDone &&
                Calendar.current.component(.year, from: $0.date) == year
            }
            .reduce(0) { $0 + $1.cost }
    }

    var totalWorksCost: Double {
        works.filter { $0.isDone }
            .flatMap { $0.subWorks }
            .filter { $0.type == .work }
            .reduce(0) { $0 + $1.totalCost }
    }

    var totalPartsCost: Double {
        works.filter { $0.isDone }
            .flatMap { $0.subWorks }
            .filter { $0.type == .part }
            .reduce(0) { $0 + $1.totalCost }
    }

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

    func monthlyCostsDetailed(monthsBack: Int = 6) -> [MonthlyCostDetailed] {
        let calendar = Calendar.current
        let now = Date()
        var result: [MonthlyCostDetailed] = []

        for offset in stride(from: monthsBack - 1, through: 0, by: -1) {
            guard let monthDate = calendar.date(
                byAdding: .month, value: -offset, to: now
            ) else { continue }

            let components = calendar.dateComponents([.year, .month], from: monthDate)
            let worksInMonth = works.filter {
                guard $0.isDone else { return false }
                let c = calendar.dateComponents([.year, .month], from: $0.date)
                return c.year == components.year && c.month == components.month
            }

            let worksSum = worksInMonth
                .flatMap { $0.subWorks }
                .filter { $0.type == .work }
                .reduce(0) { $0 + $1.totalCost }

            let partsSum = worksInMonth
                .flatMap { $0.subWorks }
                .filter { $0.type == .part }
                .reduce(0) { $0 + $1.totalCost }

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

    func categoryCosts() -> [CategoryCost] {
        Dictionary(grouping: works.filter { $0.isDone }, by: { $0.category })
            .map { (key, value) in
                CategoryCost(category: key, total: value.reduce(0) { $0 + $1.cost })
            }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    func topItems(type: SubItemType, limit: Int = 5) -> [TopItem] {
        struct ItemWithContext {
            let item: SubItem
            let workTitle: String
            let workDate: Date
        }

        let allItems: [ItemWithContext] = works
            .filter { $0.isDone }
            .flatMap { work in
                work.subWorks
                    .filter { $0.type == type }
                    .map { subItem in
                        ItemWithContext(
                            item: subItem,
                            workTitle: work.title,
                            workDate: work.date
                        )
                    }
            }

        return allItems
            .sorted { $0.item.totalCost > $1.item.totalCost }
            .prefix(limit)
            .map { ctx in
                TopItem(
                    id: ctx.item.id,
                    title: ctx.item.title,
                    total: ctx.item.totalCost,
                    occurrences: 1,
                    workTitle: ctx.workTitle,
                    workDate: ctx.workDate,
                    quantity: ctx.item.quantity,
                    unitPrice: ctx.item.unitPrice
                )
            }
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLL"
        return f
    }()

    // MARK: - Приватные

    private func sortWorks(_ works: [CarWork]) -> [CarWork] {
        works.sorted { $0.date > $1.date }
    }

    private func normalizeCost(_ work: CarWork) -> CarWork {
        guard !work.subWorks.isEmpty else { return work }
        var normalized: CarWork = work
        normalized.cost = work.subWorksTotal
        return normalized
    }
}

// MARK: - Модели для статистики

struct MonthlyCost: Identifiable {
    let month: Date
    let label: String
    let total: Double
    var id: Date { month }
}

struct MonthlyCostDetailed: Identifiable {
    let month: Date
    let label: String
    let worksTotal: Double
    let partsTotal: Double

    var id: Date { month }
    var total: Double { worksTotal + partsTotal }
}

struct CategoryCost: Identifiable {
    let category: CarWork.WorkCategory
    let total: Double
    var id: String { category.rawValue }
}

struct TopItem: Identifiable {
    let id: UUID
    let title: String
    let total: Double
    let occurrences: Int
    let workTitle: String?
    let workDate: Date?
    let quantity: Double?
    let unitPrice: Double?
}

typealias WorkCategory = CarWork.WorkCategory
