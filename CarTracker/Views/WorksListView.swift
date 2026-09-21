import SwiftUI

struct WorksListView: View {
    @EnvironmentObject var store: CarWorkStore
    @State private var showingAdd = false
    @State private var editingWork: CarWork?
    @State private var searchText = ""
    @State private var selectedCategory: CarWork.WorkCategory? = nil

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
            }
            .sheet(isPresented: $showingAdd) {
                AddEditWorkView(work: nil)
            }
            .sheet(item: $editingWork) { work in
                AddEditWorkView(work: work)
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
                WorkRowView(work: work)
                    .contentShape(Rectangle())
                    .onTapGesture { editingWork = work }
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
}
