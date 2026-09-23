import SwiftUI

struct WorkDetailView: View {
    let work: CarWork
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var workItems: [SubItem] {
        work.subWorks.filter { $0.type == .work }
    }

    private var partItems: [SubItem] {
        work.subWorks.filter { $0.type == .part }
    }

    private var worksTotal: Double {
        workItems.reduce(0) { $0 + $1.totalCost }
    }

    private var partsTotal: Double {
        partItems.reduce(0) { $0 + $1.totalCost }
    }

    var body: some View {
        List {
            // ─── Основная информация ───
            Section {
                LabeledContent("Название", value: work.title)
                LabeledContent("Категория") {
                    Label(work.category.rawValue, systemImage: work.category.icon)
                }
                LabeledContent("Статус") {
                    Text(work.isDone ? "Выполнено" : "Запланировано")
                        .foregroundStyle(work.isDone ? .green : .orange)
                }
            }

            Section("Детали") {
                LabeledContent("Дата") {
                    Text(work.date, style: .date)
                }
                if work.mileage > 0 {
                    LabeledContent("Пробег", value: "\(work.mileage.formatted()) км")
                }
            }

            // ─── Работы ───
            if !workItems.isEmpty {
                Section {
                    ForEach(workItems) { item in
                        SubItemDetailRow(item: item)
                    }
                } header: {
                    Text("🔧 Работы (\(workItems.count))")
                } footer: {
                    HStack {
                        Text("Итого работы")
                        Spacer()
                        Text(formatMoney(worksTotal))
                            .fontWeight(.semibold)
                    }
                }
            }

            // ─── Детали ───
            if !partItems.isEmpty {
                Section {
                    ForEach(partItems) { item in
                        SubItemDetailRow(item: item)
                    }
                } header: {
                    Text("🔩 Детали (\(partItems.count))")
                } footer: {
                    HStack {
                        Text("Итого детали")
                        Spacer()
                        Text(formatMoney(partsTotal))
                            .fontWeight(.semibold)
                    }
                }
            }

            // ─── Итоговая стоимость ───
            Section {
                HStack {
                    Text("Общая стоимость")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(formatMoney(work.cost))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.blue)
                }
            } footer: {
                if work.hasSubItems {
                    Text("Стоимость рассчитана автоматически из подзаписей.")
                } else {
                    Text("Стоимость введена вручную.")
                }
            }

            // ─── Заметки ───
            if !work.note.isEmpty {
                Section("Заметки") {
                    Text(work.note)
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle(work.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                }
            }
        }
    }

    private func formatMoney(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₽"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value)) ₽"
    }
}

// ─── Строка подзаписи (только для чтения) ───

private struct SubItemDetailRow: View {
    let item: SubItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.type.icon)
                .font(.caption)
                .frame(width: 22, height: 22)
                .background(
                    item.type == .work
                        ? Color.blue.opacity(0.15)
                        : Color.orange.opacity(0.15)
                )
                .foregroundStyle(item.type == .work ? .blue : .orange)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)

                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatMoney(item.totalCost))
                    .font(.subheadline.weight(.medium))

                if item.quantity != 1 {
                    Text(item.quantityDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func formatMoney(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₽"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value)) ₽"
    }
}
