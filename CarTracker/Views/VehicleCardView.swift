import SwiftUI

struct VehicleCardView: View {
    let vehicle: Vehicle
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Иконка
                ZStack {
                    Circle()
                        .fill(isActive ? Color.blue.opacity(0.15) : Color(.secondarySystemFill))
                        .frame(width: 48, height: 48)
                    Image(systemName: vehicle.type.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(isActive ? .blue : .secondary)
                }

                // Название + подзаголовок
                VStack(alignment: .leading, spacing: 3) {
                    Text(vehicle.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !vehicle.subtitle.isEmpty {
                        Text(vehicle.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if vehicle.initialMileage > 0 {
                        Text("Пробег: \(vehicle.initialMileage.formatted()) км")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Галочка активного
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)  // ← вся ширина
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isActive ? Color.blue : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())   // ← весь прямоугольник — тапабельный
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash")
            }

            Button {
                onEdit()
            } label: {
                Label("Изменить", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        VehicleCardView(
            vehicle: Vehicle(
                name: "Toyota Camry",
                type: .car,
                plate: "А123БВ 77",
                year: 2018,
                initialMileage: 45000,
                isDefault: true
            ),
            isActive: true,
            onSelect: {},
            onEdit: {},
            onDelete: {}
        )

        VehicleCardView(
            vehicle: Vehicle(
                name: "Honda CB500F",
                type: .motorcycle,
                plate: "Б456ГД 50",
                year: 2021,
                initialMileage: 12000
            ),
            isActive: false,
            onSelect: {},
            onEdit: {},
            onDelete: {}
        )
    }
    .padding()
}
