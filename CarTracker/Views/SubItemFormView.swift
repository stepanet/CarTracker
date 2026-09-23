import SwiftUI

struct SubItemFormView: View {
    @Environment(\.dismiss) private var dismiss

    /// nil = создание, объект = редактирование
    let item: SubItem?
    /// Тип по умолчанию (для создания — work или part, в зависимости от кнопки)
    let defaultType: SubItemType
    /// Замыкание сохранения
    let onSave: (SubItem) -> Void

    @State private var type: SubItemType
    @State private var title = ""
    @State private var quantity = ""
    @State private var unitPrice = ""
    @State private var note = ""

    init(
        item: SubItem?,
        defaultType: SubItemType,
        onSave: @escaping (SubItem) -> Void
    ) {
        self.item = item
        self.defaultType = defaultType
        self.onSave = onSave
        _type = State(initialValue: item?.type ?? defaultType)
    }

    private var isEditing: Bool { item != nil }

    private var isValid: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespaces).isEmpty
        let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        let price = Double(unitPrice.replacingOccurrences(of: ",", with: ".")) ?? 0
        return hasTitle && qty > 0 && price >= 0
    }

    private var totalCost: Double {
        let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        let price = Double(unitPrice.replacingOccurrences(of: ",", with: ".")) ?? 0
        return qty * price
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Тип") {
                    Picker("Тип", selection: $type) {
                        ForEach(SubItemType.allCases) { t in
                            Label(t.label, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Название") {
                    TextField(
                        type == .work
                            ? "Например: Замена масла"
                            : "Например: Масло Mobil 5W-30",
                        text: $title
                    )
                }

                Section("Стоимость") {
                    HStack(spacing: 12) {
                        Text("Количество")

                        Spacer()

                        Button {
                            decrementQuantity()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)

                        TextField("1", text: $quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 60)
                            .font(.body.weight(.medium))

                        Button {
                            incrementQuantity()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)

                        Text("шт.")
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .leading)
                    }

                    HStack {
                        Text("Цена за единицу")
                        Spacer()
                        TextField("0", text: $unitPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("₽").foregroundStyle(.secondary)
                    }

                    // Итого
                    HStack {
                        Text("Итого")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(formatMoney(totalCost))
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                }

                Section {
                    TextField("Артикул, бренд, комментарий", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Заметка")
                } footer: {
                    if type == .part {
                        Text("Полезно записать артикул или бренд — пригодится при следующей замене.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Редактирование" : (type == .work ? "Новая работа" : "Новая деталь"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { loadIfEditing() }
        }
    }

    private func loadIfEditing() {
        guard let item else { return }
        type = item.type
        title = item.title
        // Если количество 1 — оставляем поле пустым (дефолт)
        quantity = item.quantity == 1 ? "" : formatQuantity(item.quantity)
        unitPrice = formatPrice(item.unitPrice)
        note = item.note
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespaces)
        let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1
        let price = Double(unitPrice.replacingOccurrences(of: ",", with: ".")) ?? 0

        let result = SubItem(
            id: item?.id ?? UUID(),
            type: type,
            title: cleanedTitle,
            quantity: qty,
            unitPrice: price,
            note: note.trimmingCharacters(in: .whitespaces)
        )
        onSave(result)
        dismiss()
    }

    private func formatQuantity(_ value: Double) -> String {
        if value == floor(value) {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }

    private func formatPrice(_ value: Double) -> String {
        if value == floor(value) {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }

    private func formatMoney(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₽"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value)) ₽"
    }
    
    private func incrementQuantity() {
        let current = currentQuantity
        quantity = formatQuantity(current + 1)
    }

    private func decrementQuantity() {
        let current = currentQuantity
        let newValue = max(1, current - 1)  // минимум 1
        quantity = newValue == 1 ? "" : formatQuantity(newValue)
    }

    private var currentQuantity: Double {
        Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1
    }
}
