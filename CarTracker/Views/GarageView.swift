import SwiftUI
import Auth

struct GarageView: View {
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var authManager: AuthManager

    @State private var showingForm = false
    @State private var editingVehicle: Vehicle?
    @State private var pendingDelete: Vehicle?
    @State private var showingDeleteAlert = false

    // Выход
    @State private var showingLogoutAlert = false
    @State private var isLoggingOut = false

    var body: some View {
        NavigationStack {
            Group {
                if vehicleStore.vehicles.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Гараж")
            .toolbar {
                // Кнопка "Выйти" — справа
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLogoutAlert = true
                    } label: {
                        if isLoggingOut {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.red)
                                .frame(width: 32, height: 32)   // ← фиксируем
                                .contentShape(Circle())
                        }
                    }
                    .disabled(isLoggingOut)
                }
            }
            .sheet(isPresented: $showingForm) {
                VehicleFormView(vehicle: editingVehicle)
                    .environmentObject(vehicleStore)
            }
            .alert(
                "Удалить транспорт?",
                isPresented: $showingDeleteAlert,
                presenting: pendingDelete
            ) { vehicle in
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    Task { await vehicleStore.remove(vehicle) }
                }
            } message: { vehicle in
                Text("«\(vehicle.displayName)» и все его работы и напоминания будут удалены. Отменить действие нельзя.")
            }
            .alert("Выйти из аккаунта?", isPresented: $showingLogoutAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Выйти", role: .destructive) {
                    Task { await performLogout() }
                }
            } message: {
                Text("Данные останутся в облаке — сможете войти снова.")
            }
        }
    }

    // MARK: - Контент

    private var content: some View {
        List {
            Section {
                ForEach(vehicleStore.vehicles) { vehicle in
                    VehicleCardView(
                        vehicle: vehicle,
                        isActive: vehicle.id == vehicleStore.activeVehicleId,
                        onSelect: {
                            withAnimation {
                                vehicleStore.setActiveVehicle(vehicle.id)
                            }
                        },
                        onEdit: {
                            editingVehicle = vehicle
                            showingForm = true
                        },
                        onDelete: {
                            pendingDelete = vehicle
                            showingDeleteAlert = true
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                HStack {
                    Text("Мой гараж")
                        .textCase(nil)
                        .font(.headline)
                    Spacer()
                    Text("\(vehicleStore.vehicles.count)")
                        .textCase(nil)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    openAddForm()
                } label: {
                    HStack {
                        Spacer()
                        Label("Добавить транспорт", systemImage: "plus.circle")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Пустое состояние

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "car.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Пока нет транспорта")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Добавьте машину, мотоцикл или другую технику —\nчтобы разделить работы")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)

            Button {
                openAddForm()
            } label: {
                Label("Добавить транспорт", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    private func openAddForm() {
        editingVehicle = nil
        showingForm = true
    }

    // MARK: - Выход

    @MainActor
    private func performLogout() async {
        isLoggingOut = true

        do {
            try await authManager.signOut()
            print("👋 Выход выполнен")
        } catch {
            print("❌ Ошибка выхода: \(error)")
        }

        isLoggingOut = false
    }
}

#Preview {
    GarageView()
        .environmentObject(VehicleStore.shared)
        .environmentObject(AuthManager.shared)
}
