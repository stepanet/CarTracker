import Foundation
import Supabase

/// Ошибки работы с базой
enum RepositoryError: LocalizedError {
    case notAuthenticated
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Вы не авторизованы"
        case .unknown(let message):
            return message
        }
    }
}

/// Репозиторий для работы с таблицами `works` и `sub_works` в Supabase.
final class WorksRepository {
    static let shared = WorksRepository()
    private init() {}

    private let client = SupabaseService.shared.client

    // MARK: - Внутренние модели

    private struct WorkRow: Codable {
        let id: UUID
        let user_id: UUID
        var vehicle_id: UUID?
        var title: String
        var category: String
        var date: Date
        var mileage: Int
        var cost: Double
        var note: String
        var is_done: Bool
    }

    private struct SubWorkRow: Codable {
        let id: UUID
        var work_id: UUID
        var type: String
        var title: String
        var quantity: Double
        var unit_price: Double
        var note: String
    }

    private struct WorkWithSubsRow: Codable {
        let id: UUID
        let user_id: UUID
        let vehicle_id: UUID?
        let title: String
        let category: String
        let date: Date
        let mileage: Int
        let cost: Double
        let note: String
        let is_done: Bool
        let sub_works: [SubWorkRow]
    }

    // MARK: - Fetch

    /// Получить все работы пользователя с подработы.
    /// Если vehicleId задан — фильтрует по транспорту.
    func fetchAll(userId: UUID, vehicleId: UUID? = nil) async throws -> [CarWork] {
        var query = client
            .from("works")
            .select("*, sub_works(*)")
            .eq("user_id", value: userId.uuidString)

        if let vehicleId = vehicleId {
            query = query.eq("vehicle_id", value: vehicleId.uuidString)
        }

        let rows: [WorkWithSubsRow] = try await query
            .order("date", ascending: false)
            .execute()
            .value

        return rows.map { row in
            CarWork(
                id: row.id,
                vehicleId: row.vehicle_id,
                title: row.title,
                category: WorkCategory(rawValue: row.category) ?? .other,
                date: row.date,
                mileage: row.mileage,
                cost: row.cost,
                note: row.note,
                isDone: row.is_done,
                subWorks: row.sub_works.map { sub in
                    SubItem(
                        id: sub.id,
                        type: SubItemType(rawValue: sub.type) ?? .work,
                        title: sub.title,
                        quantity: sub.quantity,
                        unitPrice: sub.unit_price,
                        note: sub.note
                    )
                }
            )
        }
    }

    // MARK: - Create

    func create(_ work: CarWork, userId: UUID) async throws {
        let workRow = WorkRow(
            id: work.id,
            user_id: userId,
            vehicle_id: work.vehicleId,
            title: work.title,
            category: work.category.rawValue,
            date: work.date,
            mileage: work.mileage,
            cost: work.cost,
            note: work.note,
            is_done: work.isDone
        )

        try await client
            .from("works")
            .insert(workRow)
            .execute()

        if !work.subWorks.isEmpty {
            let subRows = work.subWorks.map { sub in
                SubWorkRow(
                    id: sub.id,
                    work_id: work.id,
                    type: sub.type.rawValue,
                    title: sub.title,
                    quantity: sub.quantity,
                    unit_price: sub.unitPrice,
                    note: sub.note
                )
            }

            do {
                try await client
                    .from("sub_works")
                    .insert(subRows)
                    .execute()
            } catch {
                _ = try? await client
                    .from("works")
                    .delete()
                    .eq("id", value: work.id.uuidString)
                    .execute()
                throw error
            }
        }
    }

    // MARK: - Update

    func update(_ work: CarWork, userId: UUID) async throws {
        let workRow = WorkRow(
            id: work.id,
            user_id: userId,
            vehicle_id: work.vehicleId,
            title: work.title,
            category: work.category.rawValue,
            date: work.date,
            mileage: work.mileage,
            cost: work.cost,
            note: work.note,
            is_done: work.isDone
        )

        try await client
            .from("works")
            .update(workRow)
            .eq("id", value: work.id.uuidString)
            .execute()

        try await client
            .from("sub_works")
            .delete()
            .eq("work_id", value: work.id.uuidString)
            .execute()

        if !work.subWorks.isEmpty {
            let subRows = work.subWorks.map { sub in
                SubWorkRow(
                    id: sub.id,
                    work_id: work.id,
                    type: sub.type.rawValue,
                    title: sub.title,
                    quantity: sub.quantity,
                    unit_price: sub.unitPrice,
                    note: sub.note
                )
            }

            try await client
                .from("sub_works")
                .insert(subRows)
                .execute()
        }
    }

    // MARK: - Delete

    func delete(id: UUID) async throws {
        try await client
            .from("works")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Bulk insert

    func bulkInsert(_ works: [CarWork], userId: UUID) async throws -> (inserted: Int, skipped: Int) {
        guard !works.isEmpty else { return (0, 0) }

        let ids = works.map { $0.id.uuidString }
        let existing: [WorkRow] = try await client
            .from("works")
            .select("id, user_id, vehicle_id, title, category, date, mileage, cost, note, is_done")
            .eq("user_id", value: userId.uuidString)
            .in("id", values: ids)
            .execute()
            .value

        let existingIds = Set(existing.map { $0.id })
        let toInsert = works.filter { !existingIds.contains($0.id) }

        guard !toInsert.isEmpty else {
            return (0, works.count)
        }

        let workRows = toInsert.map { work in
            WorkRow(
                id: work.id,
                user_id: userId,
                vehicle_id: work.vehicleId,
                title: work.title,
                category: work.category.rawValue,
                date: work.date,
                mileage: work.mileage,
                cost: work.cost,
                note: work.note,
                is_done: work.isDone
            )
        }

        try await client
            .from("works")
            .insert(workRows)
            .execute()

        let allSubRows = toInsert.flatMap { work in
            work.subWorks.map { sub in
                SubWorkRow(
                    id: sub.id,
                    work_id: work.id,
                    type: sub.type.rawValue,
                    title: sub.title,
                    quantity: sub.quantity,
                    unit_price: sub.unitPrice,
                    note: sub.note
                )
            }
        }

        if !allSubRows.isEmpty {
            try await client
                .from("sub_works")
                .insert(allSubRows)
                .execute()
        }

        return (toInsert.count, works.count - toInsert.count)
    }
}
