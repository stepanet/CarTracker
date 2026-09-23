import SwiftUI
import UniformTypeIdentifiers

struct WorksListView: View {
    @EnvironmentObject var store: CarWorkStore
    @EnvironmentObject var reminderStore: ReminderStore
    @State private var showingAdd = false
    @State private var editingWork: CarWork?
    @State private var searchText = ""
    @State private var selectedCategory: CarWork.WorkCategory? = nil
    // Состояния для экспорта/импорта
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @State private var showingFileImporter = false
    @State private var alertMessage: AlertMessage?

    var filteredWorks: [CarWork] {
        store.works.filter { work in
            let matchesSearch = searchText.isEmpty ||
                work.title.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil ||
                work.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryHeader

                categoryPicker

                if filteredWorks.isEmpty {
                    emptyState
                } else {
                    worksList
                }
            }
            .navigationTitle("Мой автомобиль")
            .searchable(text: $searchText, prompt: "Поиск работ")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            exportBackup()
                        } label: {
                            Label("Экспорт бэкапа (JSON)", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            exportCSV()
                        } label: {
                            Label("Экспорт в CSV", systemImage: "tablecells")
                        }

                        Divider()

                        Button {
                            showingFileImporter = true
                        } label: {
                            Label("Импорт из файла", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddEditWorkView(work: nil)
            }
            .sheet(item: $editingWork) { work in
                AddEditWorkView(work: work)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert(item: $alertMessage) { msg in
                Alert(
                    title: Text(msg.title),
                    message: Text(msg.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Header со статистикой
    private var summaryHeader: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Всего",
                value: formatCurrency(store.totalCost),
                icon: "banknote.fill",
                color: .blue
            )
            statCard(
                title: "За год",
                value: formatCurrency(store.totalCostThisYear),
                icon: "calendar",
                color: .green
            )
            statCard(
                title: "Записей",
                value: "\(store.works.count)",
                icon: "list.bullet.rectangle",
                color: .orange
            )
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Фильтр по категориям
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Все", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(CarWork.WorkCategory.allCases) { cat in
                    chip(title: cat.rawValue, isSelected: selectedCategory == cat) {
                        selectedCategory = (selectedCategory == cat) ? nil : cat
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    // MARK: - Список работ
    private var worksList: some View {
        List {
            ForEach(filteredWorks) { work in
                NavigationLink {
                    WorkDetailView(work: work) {
                        editingWork = work
                    }
                } label: {
                    WorkRowView(work: work)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.delete(work)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Пока нет записей")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Нажмите + чтобы добавить первую работу")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₽"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value)) ₽"
    }
    
    // MARK: - Экспорт / импорт

    private func exportBackup() {
        do {
            let url = try BackupManager.exportBackup(
                works: store.works,
                reminders: reminderStore.reminders
            )
            shareURL = url
            showingShareSheet = true
        } catch {
            alertMessage = AlertMessage(
                title: "Ошибка экспорта",
                message: error.localizedDescription
            )
        }
    }

    private func exportCSV() {
        do {
            let url = try BackupManager.exportCSV(works: store.works)
            shareURL = url
            showingShareSheet = true
        } catch {
            alertMessage = AlertMessage(
                title: "Ошибка экспорта",
                message: error.localizedDescription
            )
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importFrom(url: url)

        case .failure(let error):
            alertMessage = AlertMessage(
                title: "Ошибка выбора файла",
                message: error.localizedDescription
            )
        }
    }

    private func importFrom(url: URL) {
        do {
            let backup = try BackupManager.importBackup(from: url)
            let merged = BackupManager.merge(
                backup: backup,
                into: store.works,
                and: reminderStore.reminders
            )

            // Применяем результат
            
            store.replaceAll(with: merged.works)
            reminderStore.replaceAll(with: merged.reminders)
            
            alertMessage = AlertMessage(
                title: "Импорт завершён",
                message: merged.result.summaryText
            )
        } catch {
            alertMessage = AlertMessage(
                title: "Ошибка импорта",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Вспомогательные типы для алертов

struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
