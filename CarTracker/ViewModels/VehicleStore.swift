import Foundation
import Combine

/// Хранилище транспорта.
/// Работает с Supabase через `VehiclesRepository`.
final class VehicleStore: ObservableObject {
    
    static let shared = VehicleStore()   // ← НОВОЕ

    // MARK: - Published

    @Published var vehicles: [Vehicle] = []
    @Published var activeVehicleId: UUID?
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Dependencies

    private let repository = VehiclesRepository.shared
    private let realtime = RealtimeManager.shared
    private var userId: UUID?

    private let activeVehicleKey = "cartracker-active-vehicle"

    // MARK: - Init

    init() {
        // Восстанавливаем активный транспорт из UserDefaults
        if let raw = UserDefaults.standard.string(forKey: activeVehicleKey),
           let uuid = UUID(uuidString: raw) {
            activeVehicleId = uuid
        }
    }

    // MARK: - Активный транспорт

    var activeVehicle: Vehicle? {
        guard let activeVehicleId = activeVehicleId else { return nil }
        return vehicles.first { $0.id == activeVehicleId }
    }

    func setActiveVehicle(_ vehicleId: UUID) {
        activeVehicleId = vehicleId
        UserDefaults.standard.set(vehicleId.uuidString, forKey: activeVehicleKey)
        print("🚗 Активный транспорт: \(activeVehicle?.displayName ?? "—")")
    }

    // MARK: - Загрузка / Realtime

    @MainActor
    func loadVehicles(userId: UUID) async {
        self.userId = userId
        isLoading = true
        error = nil

        do {
            let fetched = try await repository.fetchAll(userId: userId)
            self.vehicles = fetched
            isLoading = false

            // Устанавливаем активный, если ещё нет или удалён
            if activeVehicleId == nil || !fetched.contains(where: { $0.id == activeVehicleId }) {
                if let first = fetched.first {
                    setActiveVehicle(first.id)
                }
            }

            print("✅ Загружено транспортов: \(fetched.count)")
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            print("❌ Ошибка загрузки транспорта: \(error)")
        }
    }

    @MainActor
    func reload() async {
        guard let userId = userId else { return }
        await loadVehicles(userId: userId)
    }

    @MainActor
    func subscribeRealtime(userId: UUID) {
        realtime.onVehiclesChanged = { [weak self] in
            guard let self = self else { return }
            Task {
                await self.loadVehicles(userId: userId)
            }
        }

        realtime.subscribeVehicles(userId: userId)
    }

    @MainActor
    func unsubscribeRealtime() async {
        realtime.onVehiclesChanged = nil
        await realtime.unsubscribeVehicles()
    }

    @MainActor
    func clear() {
        vehicles = []
        userId = nil
        error = nil
        // activeVehicleId НЕ очищаем — пусть запомнится между сессиями
    }

    // MARK: - CRUD

    @MainActor
    func add(_ vehicle: Vehicle) async {
        guard let userId = userId else {
            error = "Не авторизован"
            return
        }

        // Оптимистично
        vehicles.append(vehicle)

        do {
            try await repository.create(vehicle, userId: userId)

            // Если это первый транспорт — делаем активным
            if vehicles.count == 1 {
                setActiveVehicle(vehicle.id)
            }
        } catch {
            vehicles.removeAll { $0.id == vehicle.id }
            self.error = error.localizedDescription
            print("❌ Ошибка создания транспорта: \(error)")
        }
    }

    @MainActor
    func update(_ vehicle: Vehicle) async {
        guard let userId = userId else {
            error = "Не авторизован"
            return
        }

        let previous = vehicles.first { $0.id == vehicle.id }

        if let idx = vehicles.firstIndex(where: { $0.id == vehicle.id }) {
            vehicles[idx] = vehicle
        }

        do {
            try await repository.update(vehicle, userId: userId)
        } catch {
            if let prev = previous,
               let idx = vehicles.firstIndex(where: { $0.id == prev.id }) {
                vehicles[idx] = prev
            }
            self.error = error.localizedDescription
            print("❌ Ошибка обновления транспорта: \(error)")
        }
    }

    @MainActor
    func remove(_ vehicle: Vehicle) async {
        let previous = vehicles

        vehicles.removeAll { $0.id == vehicle.id }

        // Если удалили активный — переключаемся на первый доступный
        if activeVehicleId == vehicle.id {
            if let first = vehicles.first {
                setActiveVehicle(first.id)
            } else {
                activeVehicleId = nil
                UserDefaults.standard.removeObject(forKey: activeVehicleKey)
            }
        }

        do {
            try await repository.delete(id: vehicle.id)
        } catch {
            vehicles = previous
            self.error = error.localizedDescription
            print("❌ Ошибка удаления транспорта: \(error)")
        }
    }

    // MARK: - Дефолтный транспорт

    /// Убедиться, что есть хотя бы один транспорт.
    /// Если нет — создаём «Мою машину».
    @MainActor
    func ensureDefaultVehicle(userId: UUID) async -> Vehicle? {
        if !vehicles.isEmpty {
            return vehicles.first { $0.isDefault } ?? vehicles.first
        }

        var newVehicle = Vehicle(
            name: "Моя машина",
            type: .car,
            plate: "",
            year: nil,
            icon: "car",
            initialMileage: 0,
            isDefault: true
        )
        newVehicle.id = UUID()

        do {
            try await repository.create(newVehicle, userId: userId)
            vehicles = [newVehicle]
            setActiveVehicle(newVehicle.id)
            print("🚗 Создан транспорт по умолчанию: \(newVehicle.name)")
            return newVehicle
        } catch {
            print("❌ Ошибка создания дефолтного транспорта: \(error)")
            return nil
        }
    }

    // MARK: - Миграция

    /// Привязать работы и напоминания без vehicle_id к указанному транспорту.
    @MainActor
    func migrateOrphans(userId: UUID, vehicleId: UUID) async {
        do {
            let worksCount = try await repository.migrateWorksToVehicle(
                userId: userId,
                vehicleId: vehicleId
            )
            let remindersCount = try await repository.migrateRemindersToVehicle(
                userId: userId,
                vehicleId: vehicleId
            )

            if worksCount > 0 {
                print("🔄 Привязано работ к транспорту: \(worksCount)")
            }
            if remindersCount > 0 {
                print("🔄 Привязано напоминаний к транспорту: \(remindersCount)")
            }
        } catch {
            print("❌ Ошибка миграции: \(error)")
        }
    }
}
