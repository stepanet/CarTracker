import SwiftUI

struct GarageView: View {
    @EnvironmentObject var vehicleStore: VehicleStore

    @State private var showingForm = false
    @State private var editingVehicle: Vehicle?
    @State private var pendingDelete: Vehicle?
    @State private var showingDeleteAlert = false

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openAddForm()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
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
        }
    }

    // MARK: - Контент

    private var content: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("Мой гараж")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text("\(vehicleStore.vehicles.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)

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
                    .padding(.horizontal)
                }

                Button {
                    openAddForm()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                        Text("Добавить транспорт")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 2, dash: [6])
                            )
                            .foregroundStyle(Color(.tertiaryLabel))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.top, 4)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "car.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Пока нет транспорта")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Добавьте машину или мотоцикл,\nчтобы разделить работы")
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
}

#Preview {
    GarageView()
        .environmentObject(VehicleStore())
}
