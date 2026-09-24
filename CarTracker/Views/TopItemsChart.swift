import SwiftUI

struct TopItemsChart: View {
    @EnvironmentObject var store: CarWorkStore

    @State private var selectedType: SubItemType = .part

    private var items: [TopItem] {
        store.topItems(type: selectedType, limit: 5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Топ-5 затрат")
                .font(.headline)

            // Переключатель тип
            HStack(spacing: 0) {
                typeChip(type: .work, label: "Работы", icon: "wrench.adjustable.fill", color: .blue)
                typeChip(type: .part, label: "Детали", icon: "shippingbox.fill", color: .orange)
            }
            .padding(3)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(10)

            // Список
            if items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(selectedType == .work
                         ? "Нет работ с указанной стоимостью"
                         : "Нет деталей с указанной стоимостью")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        row(index: index + 1, item: item)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Переключатель

    private func typeChip(type: SubItemType, label: String, icon: String, color: Color) -> some View {
        Button {
            selectedType = type
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectedType == type ? Color(.secondarySystemGroupedBackground) : Color.clear)
            .foregroundStyle(selectedType == type ? color : .secondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Строка

    private func row(index: Int, item: TopItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Номер
            Text("\(index)")
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(Color(.tertiarySystemGroupedBackground))
                .foregroundStyle(.secondary)
                .clipShape(Circle())

            // Название + контекст
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(1)

                // Количество и цена за единицу: "4 × 565 ₽"
                if let qty = item.quantity,
                   let price = item.unitPrice,
                   qty != 1 {
                    Text("\(formatQuantity(qty)) × \(formatMoney(price))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // К какому ТО относится
                if let workTitle = item.workTitle {
                    HStack(spacing: 4) {
                        Text(workTitle)
                        if let date = item.workDate {
                            Text("•")
                            Text(date, format: .dateTime.day().month(.abbreviated).year())
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                }
            }

            Spacer()

            // Сумма
            Text(formatMoney(item.total))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Форматирование

    private func formatMoney(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₽"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value)) ₽"
    }

    private func formatQuantity(_ value: Double) -> String {
        if value == floor(value) {
            return String(Int(value))
        }
        // Убираем хвостовые нули: 4.50 → 4.5
        return String(format: "%.2f", value)
            .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }
}
