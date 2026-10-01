import SwiftUI

struct VehicleSwitcherView: View {
    @EnvironmentObject var vehicleStore: VehicleStore

    let onOpenGarage: () -> Void

    var body: some View {
        if vehicleStore.vehicles.isEmpty {
            EmptyView()
        } else {
            Menu {
                // Список транспортов
                ForEach(vehicleStore.vehicles) { vehicle in
                    Button {
                        withAnimation {
                            vehicleStore.setActiveVehicle(vehicle.id)
                        }
                    } label: {
                        HStack {
                            Label {
                                Text(vehicle.displayName)
                            } icon: {
                                Image(systemName: vehicle.type.icon)
                            }

                            if vehicle.id == vehicleStore.activeVehicleId {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                // Управление гаражом
                Button {
                    onOpenGarage()
                } label: {
                    Label("Управление гаражом", systemImage: "gear")
                }
            } label: {
                HStack(spacing: 6) {
                    if let active = vehicleStore.activeVehicle {
                        Image(systemName: active.type.icon)
                            .font(.caption)
                        Text(active.displayName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    } else {
                        Text("Выбрать ТС")
                            .font(.subheadline)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemFill))
                .clipShape(Capsule())
            }
        }
    }
}
