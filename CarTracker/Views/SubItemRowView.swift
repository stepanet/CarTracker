import SwiftUI

struct SubItemRowView: View {
    let item: SubItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Иконка типа
            Image(systemName: item.type.icon)
                .font(.caption)
                .frame(width: 24, height: 24)
                .background(item.type == .work ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                .foregroundStyle(item.type == .work ? .blue : .orange)
                .clipShape(Circle())

            // Текст
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(1)

                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Стоимость
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatMoney(item.totalCost))
                    .font(.subheadline.weight(.medium))

                if item.quantity != 1 {
                    Text(item.quantityDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Кнопка удаления
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }

    private func formatMoney(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₽"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value)) ₽"
    }
}
