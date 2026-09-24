import Foundation
import Supabase

/// Репозиторий для работы с таблицей `reminders` в Supabase.
/// Аналог `remindersApi.ts` в веб-версии.
final class RemindersRepository {
    static let shared = RemindersRepository()
    private init() {}

    private let client = SupabaseService.shared.client

    // MARK: - Внутренняя модель для Supabase

    private struct ReminderRow: Codable {
        let id: UUID
        let user_id: UUID
        var title: String
        var icon: String
        var interval_km: Int
        var interval_months: Int
        var last_date: Date
        var last_mileage: Int
        var is_enabled: Bool
    }

    // MARK: - Fetch

    /// Получить все напоминания пользователя
    func fetchAll(userId: UUID) async throws -> [Reminder] {
        let rows: [ReminderRow] = try await client
            .from("reminders")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        return rows.map { row in
            Reminder(
                id: row.id,
                title: row.title,
                icon: row.icon,
                intervalKm: row.interval_km,
                intervalMonths: row.interval_months,
                lastDate: row.last_date,
                lastMileage: row.last_mileage,
                isEnabled: row.is_enabled
            )
        }
    }

    // MARK: - Create

    func create(_ reminder: Reminder, userId: UUID) async throws {
        let row = ReminderRow(
            id: reminder.id,
            user_id: userId,
            title: reminder.title,
            icon: reminder.icon,
            interval_km: reminder.intervalKm,
            interval_months: reminder.intervalMonths,
            last_date: reminder.lastDate,
            last_mileage: reminder.lastMileage,
            is_enabled: reminder.isEnabled
        )

        try await client
            .from("reminders")
            .insert(row)
            .execute()
    }

    // MARK: - Update

    func update(_ reminder: Reminder, userId: UUID) async throws {
        let row = ReminderRow(
            id: reminder.id,
            user_id: userId,
            title: reminder.title,
            icon: reminder.icon,
            interval_km: reminder.intervalKm,
            interval_months: reminder.intervalMonths,
            last_date: reminder.lastDate,
            last_mileage: reminder.lastMileage,
            is_enabled: reminder.isEnabled
        )

        try await client
            .from("reminders")
            .update(row)
            .eq("id", value: reminder.id.uuidString)
            .execute()
    }

    // MARK: - Delete

    func delete(id: UUID) async throws {
        try await client
            .from("reminders")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Bulk insert (для миграции)

    /// Массовая вставка (для миграции из UserDefaults).
    /// Пропускает записи, которые уже есть в базе.
    func bulkInsert(_ reminders: [Reminder], userId: UUID) async throws -> Int {
        guard !reminders.isEmpty else { return 0 }

        // Смотрим, какие id уже есть
        let ids = reminders.map { $0.id.uuidString }
        let existing: [ReminderRow] = try await client
            .from("reminders")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .in("id", values: ids)
            .execute()
            .value

        let existingIds = Set(existing.map { $0.id })
        let toInsert = reminders.filter { !existingIds.contains($0.id) }

        guard !toInsert.isEmpty else { return 0 }

        let rows = toInsert.map { reminder in
            ReminderRow(
                id: reminder.id,
                user_id: userId,
                title: reminder.title,
                icon: reminder.icon,
                interval_km: reminder.intervalKm,
                interval_months: reminder.intervalMonths,
                last_date: reminder.lastDate,
                last_mileage: reminder.lastMileage,
                is_enabled: reminder.isEnabled
            )
        }

        try await client
            .from("reminders")
            .insert(rows)
            .execute()

        return toInsert.count
    }
}
