import SwiftUI
import UniformTypeIdentifiers
import UIKit
import Auth  // для user.email

struct WorksListView: View {
    @EnvironmentObject var store: CarWorkStore
    @EnvironmentObject var authManager: AuthManager

    @State private var showingAdd = false
    @State private var editingWork: CarWork?
    @State private var viewingWork: CarWork?
    @State private var searchText = ""
    @State private var selectedCategory: CarWork.WorkCategory? = nil
    @State private var savingError: String?

    // Состояния для экспорта/импорта
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @State private var showingFileImporter = false
    @State private var alertMessage: AlertMessage?

    // Выход из аккаунта
    @State private var showingLogoutAlert = false
    @State private var isLoggingOut = false

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
                // Индикатор загрузки из облака
                if store.isLoading && store.works.isEmpty {
                    loadingIndicator
                }

                // Ошибка загрузки
                if let error = store.error {
                    errorBanner(error)
                }

                // Ошибка сохранения (локальная)
                if let savingError = savingError {
                    savingErrorBanner(savingError)
                }

                summaryHeader

                categoryPicker

                if filteredWorks.isEmpty {
                    emptyState
                } else {
                    worksList
                }
            }
            .navigationTitle("Мои работы")
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

                        Divider()

                        // Email пользователя
                        if let email = authManager.user?.email {
                            Text(email)
                                .font(.caption)
                        }

                        // Выйти из аккаунта
                        Button(role: .destructive) {
                            showingLogoutAlert = true
                        } label: {
                            Label(
                                "Выйти из аккаунта",
                                systemImage: "rectangle.portrait.and.arrow.right"
                            )
                        }
                        .disabled(isLoggingOut)
                    } label: {
                        if isLoggingOut {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddEditWorkView(work: nil)
            }
            .sheet(item: $editingWork) { work in
                AddEditWorkView(work: work)
            }
            .sheet(item: $viewingWork) { work in
                NavigationStack {
                    WorkDetailView(work: work) {
                        // КРИТИЧЕСКИЙ ПОРЯДОК: сначала закрываем детальный,
                        // потом открываем форму редактирования
                        viewingWork = nil
                        editingWork = work
                    }
                }
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
            .alert("Выйти из аккаунта?", isPresented: $showingLogoutAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Выйти", role: .destructive) {
                    Task { await performLogout() }
                }
            } message: {
                Text("Данные останутся в облаке — сможете войти снова.")
            }
        }
    }

    // MARK: - Индикаторы

    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Загрузка данных из облака...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.08))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                store.error = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }

    private func savingErrorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                savingError = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.12))
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
                    .onTapGesture { viewingWork = work }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await deleteWork(work) }
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refresh()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(store.isLoading ? "Загрузка..." : "Пока нет записей")
                .font(.title3)
                .foregroundStyle(.secondary)
            if !store.isLoading {
                Text("Нажмите + чтобы добавить первую работу")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    // MARK: - Действия

    private func deleteWork(_ work: CarWork) async {
        savingError = nil
        await store.remove(work)
    }

    @MainActor
    private func performLogout() async {
        isLoggingOut = true

        do {
            try await authManager.signOut()
            print("👋 Выход выполнен")
        } catch {
            print("❌ Ошибка выхода: \(error)")
        }

        isLoggingOut = false
    }

    // MARK: - Экспорт / импорт

    private func exportBackup() {
        do {
            let url = try BackupManager.exportBackup(
                works: store.works,
                reminders: []
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

            // Импортируем работы по одной через add
            Task {
                var added = 0
                var skipped = 0

                for work in backup.works {
                    // Проверяем, есть ли уже такая работа
                    if store.works.contains(where: { $0.id == work.id }) {
                        skipped += 1
                        continue
                    }
                    await store.add(work)
                    added += 1
                }

                await MainActor.run {
                    alertMessage = AlertMessage(
                        title: "Импорт завершён",
                        message: "Добавлено работ: \(added), пропущено дубликатов: \(skipped)"
                    )
                }
            }
        } catch {
            alertMessage = AlertMessage(
                title: "Ошибка импорта",
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Форматирование

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₽"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value)) ₽"
    }

    /// Обновить данные из облака (pull-to-refresh)
    @MainActor
    private func refresh() async {
        await store.reload()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Вспомогательные типы

struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
