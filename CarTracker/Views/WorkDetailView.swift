import SwiftUI

struct WorkDetailView: View {
    let work: CarWork

    var body: some View {
        List {
            Section("Работа") {
                LabeledContent("Название", value: work.title)
                LabeledContent("Категория", value: work.category.rawValue)
                LabeledContent("Статус", value: work.isDone ? "Выполнено" : "Запланировано")
            }
            Section("Детали") {
                LabeledContent("Дата") {
                    Text(work.date, style: .date)
                }
                if work.mileage > 0 {
                    LabeledContent("Пробег", value: "\(work.mileage.formatted()) км")
                }
            }
            Section("Стоимость") {
                LabeledContent("Сумма", value: String(format: "%.2f ₽", work.cost))
            }
            if !work.note.isEmpty {
                Section("Заметки") {
                    Text(work.note)
                }
            }
        }
        .navigationTitle(work.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
