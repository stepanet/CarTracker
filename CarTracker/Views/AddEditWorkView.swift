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

    private var isEditing: Bool { work != nil }
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
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

                Section("Стоимость") {
                    HStack {
                        TextField("0", text: $cost)
                            .keyboardType(.decimalPad)
                        Text("₽").foregroundStyle(.secondary)
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
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespaces)
        let mileageValue = Int(mileage) ?? 0
        let costValue = Double(cost.replacingOccurrences(of: ",", with: ".")) ?? 0

        if var existing = work {
            existing.title = cleanedTitle
            existing.category = category
            existing.date = date
            existing.mileage = mileageValue
            existing.cost = costValue
            existing.note = note
            existing.isDone = isDone
            store.update(existing)
        } else {
            let newWork = CarWork(
                title: cleanedTitle,
                category: category,
                date: date,
                mileage: mileageValue,
                cost: costValue,
                note: note,
                isDone: isDone
            )
            store.add(newWork)
        }
        dismiss()
    }
}
