import SwiftUI

struct AddEditWorkView: View {
    @EnvironmentObject var store: CarWorkStore
    @Environment(\.dismiss) private var dismiss

    let work: CarWork?

    @State private var title = ""
    @State private var category: CarWork.WorkCategory = .maintenance
    @State private var date = Date()
    @State private var mileage = ""
    @State private var cost = ""
    @State private var note = ""
    @State private var isDone = true
    // Состояния для подзаписей
    @State private var subWorks: [SubItem] = []
    @State private var editingSubItem: SubItem?
    @State private var newSubItemType: SubItemType = .work
    @State private var showingSubItemForm = false

    private var isEditing: Bool { work != nil }
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// Есть ли у работы подзаписи
    private var hasSubItems: Bool {
        !subWorks.isEmpty
    }

    /// Сумма всех подзаписей
    private var subItemsTotal: Double {
        subWorks.reduce(0) { $0 + $1.totalCost }
    }

    /// Отфильтрованные работы (type = .work)
    private var workItems: [SubItem] {
        subWorks.filter { $0.type == .work }
    }

    /// Отфильтрованные детали (type = .part)
    private var partItems: [SubItem] {
        subWorks.filter { $0.type == .part }
    }

    /// Текущая стоимость работы — либо сумма подзаписей, либо введённое значение
    private var effectiveCost: Double {
        hasSubItems ? subItemsTotal : (Double(cost.replacingOccurrences(of: ",", with: ".")) ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Работа") {
                    TextField("Название (например: Замена масла)", text: $title)
                    Picker("Категория", selection: $category) {
                        ForEach(CarWork.WorkCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    Toggle("Выполнено", isOn: $isDone)
                }

                Section("Детали") {
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("Пробег")
                        Spacer()
                        TextField("км", text: $mileage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("км").foregroundStyle(.secondary)
                    }
                }

                // Секция «Работы» — только если есть подработы-работы
                if !workItems.isEmpty {
                    Section {
                        ForEach(workItems) { item in
                            SubItemRowView(
                                item: item,
                                onEdit: { openEditSubItem(item) },
                                onDelete: { deleteSubItem(item) }
                            )
                        }

                        Button {
                            openAddSubItem(type: .work)
                        } label: {
                            Label("Добавить работу", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                        }
                    } header: {
                        Text("🔧 Работы")
                    } footer: {
                        Text("Итого работы: \(formatMoney(workItems.reduce(0) { $0 + $1.totalCost }))")
                    }
                } else {
                    Section {
                        Button {
                            openAddSubItem(type: .work)
                        } label: {
                            Label("Добавить работу", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                        }
                    } header: {
                        Text("🔧 Работы")
                    } footer: {
                        Text("Услуги: замена, диагностика, регулировка")
                    }
                }

                // Секция «Детали» — только если есть подработы-детали
                if !partItems.isEmpty {
                    Section {
                        ForEach(partItems) { item in
                            SubItemRowView(
                                item: item,
                                onEdit: { openEditSubItem(item) },
                                onDelete: { deleteSubItem(item) }
                            )
                        }

                        Button {
                            openAddSubItem(type: .part)
                        } label: {
                            Label("Добавить деталь", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                        }
                    } header: {
                        Text("🔩 Детали")
                    } footer: {
                        Text("Итого детали: \(formatMoney(partItems.reduce(0) { $0 + $1.totalCost }))")
                    }
                } else {
                    Section {
                        Button {
                            openAddSubItem(type: .part)
                        } label: {
                            Label("Добавить деталь", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                        }
                    } header: {
                        Text("🔩 Детали")
                    } footer: {
                        Text("Запчасти: масло, фильтры, свечи, колодки")
                    }
                }

                // Стоимость — либо автоматическая (если есть подзаписи), либо ручная
                Section("Стоимость") {
                    if hasSubItems {
                        HStack {
                            Text("Автоматически")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatMoney(subItemsTotal))
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                    } else {
                        HStack {
                            TextField("0", text: $cost)
                                .keyboardType(.decimalPad)
                            Text("₽").foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Заметки") {
                    TextField("Комментарий", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Редактирование" : "Новая работа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear { loadIfEditing() }
            .sheet(isPresented: $showingSubItemForm) {
                SubItemFormView(
                    item: editingSubItem,
                    defaultType: newSubItemType
                ) { savedItem in
                    saveSubItem(savedItem)
                }
            }
        }
    }

    private func loadIfEditing() {
        guard let work else { return }
        title = work.title
        category = work.category
        date = work.date
        mileage = work.mileage > 0 ? "\(work.mileage)" : ""
        cost = work.cost > 0 ? String(format: "%.2f", work.cost) : ""
        note = work.note
        isDone = work.isDone
        subWorks = work.subWorks    // ← ЗАГРУЖАЕМ ПОДЗАПИСИ
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespaces)
        let mileageValue = Int(mileage) ?? 0

        // Если есть подзаписи — стоимость = сумма подзаписей.
        // Если нет — берём ручной ввод.
        let costValue: Double
        if hasSubItems {
            costValue = subItemsTotal
        } else {
            costValue = Double(cost.replacingOccurrences(of: ",", with: ".")) ?? 0
        }

        if var existing = work {
            existing.title = cleanedTitle
            existing.category = category
            existing.date = date
            existing.mileage = mileageValue
            existing.cost = costValue
            existing.note = note
            existing.isDone = isDone
            existing.subWorks = subWorks    // ← СОХРАНЯЕМ ПОДЗАПИСИ
            store.update(existing)
        } else {
            let newWork = CarWork(
                title: cleanedTitle,
                category: category,
                date: date,
                mileage: mileageValue,
                cost: costValue,
                note: note,
                isDone: isDone,
                subWorks: subWorks    // ← ПЕРЕДАЁМ ПОДЗАПИСИ
            )
            store.add(newWork)
        }
        dismiss()
    }
    
    // MARK: - Подзаписи

    private func openAddSubItem(type: SubItemType) {
        newSubItemType = type
        editingSubItem = nil
        showingSubItemForm = true
    }

    private func openEditSubItem(_ item: SubItem) {
        newSubItemType = item.type
        editingSubItem = item
        showingSubItemForm = true
    }

    private func saveSubItem(_ item: SubItem) {
        if let editingIndex = subWorks.firstIndex(where: { $0.id == item.id }) {
            // Обновление
            subWorks[editingIndex] = item
        } else {
            // Добавление
            subWorks.append(item)
        }
        // Сбрасываем ручную стоимость — она теперь считается автоматически
        if hasSubItems {
            cost = ""
        }
    }

    private func deleteSubItem(_ item: SubItem) {
        subWorks.removeAll { $0.id == item.id }
        // Если все подзаписи удалены — возвращаем ручной ввод
        if subWorks.isEmpty {
            cost = String(format: "%.0f", item.totalCost)
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
