import SwiftUI

struct AddEditReminderView: View {
    @EnvironmentObject var reminderStore: ReminderStore
    @Environment(\.dismiss) private var dismiss

    let reminder: Reminder?

    @State private var title = ""
    @State private var icon = "wrench.and.screwdriver.fill"
    @State private var intervalKm = ""
    @State private var intervalMonths = ""
    @State private var lastDate = Date()
    @State private var lastMileage = ""
    @State private var isEnabled = true
    @State private var showingDeleteAlert = false

    private var isEditing: Bool { reminder != nil }

    private var isValid: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespaces).isEmpty
        let km = Int(intervalKm) ?? 0
        let months = Int(intervalMonths) ?? 0
        let hasInterval = km > 0 || months > 0
        return hasTitle && hasInterval
    }

    // MARK: - Палитра иконок
    private let iconPalette: [String] = [
        "drop.fill",
        "circle.circle.fill",
        "exclamationmark.octagon.fill",
        "wind",
        "flame.fill",
        "bolt.fill",
        "snowflake",
        "sun.max.fill",
        "engine.combustion.fill",
        "car.fill",
        "fuelpump.fill",
        "wrench.and.screwdriver.fill",
        "hammer.fill",
        "shield.lefthalf.filled",
        "gear",
        "battery.100percent",
        "lightbulb.fill",
        "sparkles"
    ]

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Название
                Section("Название") {
                    TextField("Например: Замена масла", text: $title)
                }

                // MARK: Иконка
                Section("Иконка") {
                    iconPicker
                }

                // MARK: Интервалы
                Section {
                    HStack {
                        Text("Каждые")
                        Spacer()
                        TextField("—", text: $intervalKm)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("км")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Каждые")
                        Spacer()
                        TextField("—", text: $intervalMonths)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("мес.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Интервал")
                } footer: {
                    Text("Заполните хотя бы одно поле. Если оба — сработает то, что наступит раньше.")
                        .font(.caption)
                }

                // MARK: Последнее выполнение
                Section("Последнее выполнение") {
                    DatePicker(
                        "Дата",
                        selection: $lastDate,
                        displayedComponents: .date
                    )

                    HStack {
                        Text("Пробег")
                        Spacer()
                        TextField("0", text: $lastMileage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("км")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Вкл/выкл
                Section {
                    Toggle("Напоминание включено", isOn: $isEnabled)
                }

                // MARK: Удалить
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Удалить напоминание")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Редактирование" : "Новое напоминание")
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
            .alert("Удалить напоминание?", isPresented: $showingDeleteAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    deleteReminder()
                }
            } message: {
                Text("«\(title)» будет удалено. Отменить действие нельзя.")
            }
        }
    }

    // MARK: - Палитра иконок
    private var iconPicker: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 6),
            spacing: 12
        ) {
            ForEach(iconPalette, id: \.self) { symbol in
                Button {
                    icon = symbol
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .background(
                            icon == symbol
                                ? Color.accentColor
                                : Color(.secondarySystemFill)
                        )
                        .foregroundStyle(
                            icon == symbol
                                ? Color.white
                                : Color.primary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Загрузка при редактировании
    private func loadIfEditing() {
        guard let reminder else { return }
        title = reminder.title
        icon = reminder.icon
        intervalKm = reminder.intervalKm > 0 ? "\(reminder.intervalKm)" : ""
        intervalMonths = reminder.intervalMonths > 0 ? "\(reminder.intervalMonths)" : ""
        lastDate = reminder.lastDate
        lastMileage = reminder.lastMileage > 0 ? "\(reminder.lastMileage)" : ""
        isEnabled = reminder.isEnabled
    }

    // MARK: - Сохранение
    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespaces)
        let km = Int(intervalKm) ?? 0
        let months = Int(intervalMonths) ?? 0
        let mileage = Int(lastMileage) ?? 0

        if var existing = reminder {
            existing.title = cleanedTitle
            existing.icon = icon
            existing.intervalKm = km
            existing.intervalMonths = months
            existing.lastDate = lastDate
            existing.lastMileage = mileage
            existing.isEnabled = isEnabled
            reminderStore.update(existing)
        } else {
            let new = Reminder(
                title: cleanedTitle,
                icon: icon,
                intervalKm: km,
                intervalMonths: months,
                lastDate: lastDate,
                lastMileage: mileage,
                isEnabled: isEnabled
            )
            reminderStore.add(new)
        }

        rescheduleNotifications()
        dismiss()
    }

    // MARK: - Удаление
    private func deleteReminder() {
        guard let reminder else { return }
        NotificationManager.shared.cancel(for: reminder)
        reminderStore.delete(reminder)
        rescheduleNotifications()
        dismiss()
    }

    // MARK: - Пересчёт уведомлений
    private func rescheduleNotifications() {
        // Мы не знаем текущий пробег здесь напрямую — на всякий случай
        // используем lastMileage самого напоминания. Полный пересчёт
        // произойдёт при следующем открытии экрана «Напоминания».
        NotificationManager.shared.reschedule(
            reminders: reminderStore.reminders,
            currentMileage: reminderStore.reminders.map(\.lastMileage).max() ?? 0
        )
    }
}
