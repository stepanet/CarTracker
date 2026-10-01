import SwiftUI

struct VehicleFormView: View {
    @EnvironmentObject var vehicleStore: VehicleStore
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle?

    @State private var name = ""
    @State private var type: VehicleType = .car
    @State private var plate = ""
    @State private var year = ""
    @State private var icon = "car"
    @State private var initialMileage = ""
    @State private var isSaving = false
    @State private var saveError: String?

    private var isEditing: Bool { vehicle != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Варианты иконок (ключи хранятся в Supabase)
    private let iconOptions: [(key: String, label: String, systemName: String)] = [
        ("car", "Машина", "car.fill"),
        ("bike", "Мотоцикл", "bicycle"),
        ("truck", "Фургон", "box.truck.fill"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Название
                Section("Название") {
                    TextField(
                        "Например: Toyota Camry или Honda CB500",
                        text: $name
                    )
                }

                // Тип
                Section("Тип") {
                    Picker("Тип", selection: $type) {
                        ForEach(VehicleType.allCases) { t in
                            Label(t.label, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { _, newType in
                        // Автоматически подставляем иконку
                        switch newType {
                        case .car: icon = "car"
                        case .motorcycle, .scooter: icon = "bike"
                        case .other: icon = "truck"
                        }
                    }
                }

                // Иконка
                Section("Иконка") {
                    HStack(spacing: 12) {
                        ForEach(iconOptions, id: \.key) { opt in
                            Button {
                                icon = opt.key
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: opt.systemName)
                                        .font(.title2)
                                    Text(opt.label)
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    icon == opt.key
                                        ? Color.accentColor.opacity(0.15)
                                        : Color(.secondarySystemFill)
                                )
                                .foregroundStyle(
                                    icon == opt.key
                                        ? Color.accentColor
                                        : Color.primary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Госномер
                Section("Госномер") {
                    TextField("А123БВ 77", text: $plate)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                // Год выпуска
                Section("Год выпуска") {
                    TextField("2018", text: $year)
                        .keyboardType(.numberPad)
                }

                // Пробег
                Section {
                    HStack {
                        Text("Текущий пробег")
                        Spacer()
                        TextField("0", text: $initialMileage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("км")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Пробег на момент добавления. Учитывается в напоминаниях, пока нет работ с большим пробегом.")
                        .font(.caption)
                }

                // Ошибка
                if let saveError = saveError {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(saveError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Редактирование" : "Новый транспорт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Сохранить") {
                            Task { await save() }
                        }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear { loadIfEditing() }
        }
    }

    // MARK: - Загрузка при редактировании

    private func loadIfEditing() {
        guard let vehicle = vehicle else { return }
        name = vehicle.name
        type = vehicle.type
        plate = vehicle.plate
        year = vehicle.year.map(String.init) ?? ""
        icon = vehicle.icon
        initialMileage = vehicle.initialMileage > 0
            ? String(vehicle.initialMileage)
            : ""
    }

    // MARK: - Сохранение

    @MainActor
    private func save() async {
        isSaving = true
        saveError = nil

        let cleanedName = name.trimmingCharacters(in: .whitespaces)
        let yearValue = Int(year)
        let mileageValue = Int(initialMileage) ?? 0

        if var existing = vehicle {
            existing.name = cleanedName
            existing.type = type
            existing.plate = plate.trimmingCharacters(in: .whitespaces)
            existing.year = yearValue
            existing.icon = icon
            existing.initialMileage = mileageValue
            await vehicleStore.update(existing)
        } else {
            let new = Vehicle(
                name: cleanedName,
                type: type,
                plate: plate.trimmingCharacters(in: .whitespaces),
                year: yearValue,
                icon: icon,
                initialMileage: mileageValue
            )
            await vehicleStore.add(new)
        }

        isSaving = false

        if let storeError = vehicleStore.error {
            saveError = storeError
            return
        }

        dismiss()
    }
}
