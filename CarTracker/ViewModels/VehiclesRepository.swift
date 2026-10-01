import Foundation
import Supabase

/// Репозиторий для работы с таблицей `vehicles` в Supabase.
final class VehiclesRepository {
    static let shared = VehiclesRepository()
    private init() {}

    private let client = SupabaseService.shared.client

    // MARK: - Внутренняя модель для Supabase

    private struct VehicleRow: Codable {
        let id: UUID
        let user_id: UUID
        var name: String
        var type: String
        var plate: String
        var year: Int?
        var icon: String
        var initial_mileage: Int
        var is_default: Bool
    }

    // MARK: - Fetch

    /// Получить все транспорты пользователя
    func fetchAll(userId: UUID) async throws -> [Vehicle] {
        let rows: [VehicleRow] = try await client
            .from("vehicles")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        return rows.map { row in
            Vehicle(
                id: row.id,
                name: row.name,
                type: VehicleType(rawValue: row.type) ?? .car,
                plate: row.plate,
                year: row.year,
                icon: row.icon,
                initialMileage: row.initial_mileage,
                isDefault: row.is_default
            )
        }
    }

    // MARK: - Create

    func create(_ vehicle: Vehicle, userId: UUID) async throws {
        let row = VehicleRow(
            id: vehicle.id,
            user_id: userId,
            name: vehicle.name,
            type: vehicle.type.rawValue,
            plate: vehicle.plate,
            year: vehicle.year,
            icon: vehicle.icon,
            initial_mileage: vehicle.initialMileage,
            is_default: vehicle.isDefault
        )

        try await client
            .from("vehicles")
            .insert(row)
            .execute()
    }

    // MARK: - Update

    func update(_ vehicle: Vehicle, userId: UUID) async throws {
        let row = VehicleRow(
            id: vehicle.id,
            user_id: userId,
            name: vehicle.name,
            type: vehicle.type.rawValue,
            plate: vehicle.plate,
            year: vehicle.year,
            icon: vehicle.icon,
            initial_mileage: vehicle.initialMileage,
            is_default: vehicle.isDefault
        )

        try await client
            .from("vehicles")
            .update(row)
            .eq("id", value: vehicle.id.uuidString)
            .execute()
    }

    // MARK: - Delete

    func delete(id: UUID) async throws {
        try await client
            .from("vehicles")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Migrate

    /// Привязать работы без vehicle_id к указанному транспорту
    func migrateWorksToVehicle(userId: UUID, vehicleId: UUID) async throws -> Int {
        // Найти работы без vehicle_id
        struct IdRow: Codable { let id: UUID }

        let orphanWorks: [IdRow] = try await client
            .from("works")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .is("vehicle_id", value: nil)
            .execute()
            .value

        guard !orphanWorks.isEmpty else { return 0 }

        let ids = orphanWorks.map { $0.id }

        // Обновить их
        struct UpdatePayload: Codable {
            let vehicle_id: UUID
        }

        try await client
            .from("works")
            .update(UpdatePayload(vehicle_id: vehicleId))
            .in("id", values: ids.map { $0.uuidString })
            .execute()

        return ids.count
    }

    /// Привязать напоминания без vehicle_id к указанному транспорту
    func migrateRemindersToVehicle(userId: UUID, vehicleId: UUID) async throws -> Int {
        struct IdRow: Codable { let id: UUID }

        let orphanReminders: [IdRow] = try await client
            .from("reminders")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .is("vehicle_id", value: nil)
            .execute()
            .value

        guard !orphanReminders.isEmpty else { return 0 }

        let ids = orphanReminders.map { $0.id }

        struct UpdatePayload: Codable {
            let vehicle_id: UUID
        }

        try await client
            .from("reminders")
            .update(UpdatePayload(vehicle_id: vehicleId))
            .in("id", values: ids.map { $0.uuidString })
            .execute()

        return ids.count
    }
}
