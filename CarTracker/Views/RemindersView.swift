import SwiftUI
import UIKit

struct RemindersView: View {
    @EnvironmentObject var reminderStore: ReminderStore
    @EnvironmentObject var workStore: CarWorkStore

    @State private var showingAdd = false
    @State private var editingReminder: Reminder?

    // MARK: - Текущий пробег машины
    private var currentMileage: Int {
        ReminderCalculator.currentMileage(
            from: workStore.works,
            reminders: reminderStore.reminders
        )
    }

    // MARK: - Отсортированные напоминания
    private var sortedReminders: [Reminder] {
        ReminderCalculator.sorted(
            reminderStore.reminders,
            currentMileage: currentMileage
        )
    }

    // MARK: - Сводка
    private var summary: (overdue: Int, soon: Int, ok: Int) {
        ReminderCalculator.summary(
            reminders: reminderStore.reminders,
            currentMileage: currentMileage
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Индикатор загрузки из облака
                if reminderStore.isLoading && reminderStore.reminders.isEmpty {
                    loadingIndicator
                }

                // Ошибка загрузки
                if let error = reminderStore.error {
                    errorBanner(error)
                }

                NotificationPermissionBanner()

                Group {
                    if reminderStore.reminders.isEmpty {
                        emptyState
                    } else {
                        remindersList
                    }
                }
            }
            .navigationTitle("Напоминания")
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
                AddEditReminderView(reminder: nil)
            }
            .sheet(item: $editingReminder) { reminder in
                AddEditReminderView(reminder: reminder)
            }
            .onAppear {
                NotificationManager.shared.reschedule(
                    reminders: reminderStore.reminders,
                    currentMileage: currentMileage
                )
            }
        }
    }

    // MARK: - Индикаторы

    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Загрузка напоминаний...")
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
                reminderStore.error = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }

    // MARK: - Список
    private var remindersList: some View {
        List {
            Section {
                summaryRow
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(sortedReminders) { reminder in
                    ReminderCardView(
                        reminder: reminder,
                        currentMileage: currentMileage,
                        onMarkDone: { markDone(reminder) },
                        onToggleEnabled: { toggleEnabled(reminder) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { editingReminder = reminder }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteReminder(reminder)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            } header: {
                Text("Правила ТО")
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refresh()
        }
    }

    // MARK: - Шапка со сводкой
    private var summaryRow: some View {
        HStack(spacing: 12) {
            summaryBadge(count: summary.overdue, label: "Пора", color: .red)
            summaryBadge(count: summary.soon, label: "Скоро", color: .orange)
            summaryBadge(count: summary.ok, label: "ОК", color: .green)
        }
    }

    private func summaryBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.12))
        .cornerRadius(12)
    }

    // MARK: - Пустое состояние
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text(reminderStore.isLoading ? "Загрузка..." : "Пока нет напоминаний")
                .font(.title3)
                .foregroundStyle(.secondary)

            if !reminderStore.isLoading {
                Text("Создайте правило — приложение\nподскажет, когда пора делать ТО")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.tertiary)

                Button {
                    installDefaults()
                } label: {
                    Label("Установить типовой набор", systemImage: "wand.and.stars")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Действия

    private func markDone(_ reminder: Reminder) {
        Task {
            await reminderStore.markDone(reminder, currentMileage: currentMileage)

            NotificationManager.shared.cancel(for: reminder)
            NotificationManager.shared.reschedule(
                reminders: reminderStore.reminders,
                currentMileage: currentMileage
            )
        }
    }

    private func toggleEnabled(_ reminder: Reminder) {
        var updated = reminder
        updated.isEnabled.toggle()

        Task {
            await reminderStore.update(updated)

            if !updated.isEnabled {
                NotificationManager.shared.cancel(for: reminder)
            } else {
                NotificationManager.shared.reschedule(
                    reminders: reminderStore.reminders,
                    currentMileage: currentMileage
                )
            }
        }
    }

    private func deleteReminder(_ reminder: Reminder) {
        Task {
            NotificationManager.shared.cancel(for: reminder)
            await reminderStore.delete(reminder)
        }
    }

    private func installDefaults() {
        Task {
            await reminderStore.installDefaultSet()

            NotificationManager.shared.reschedule(
                reminders: reminderStore.reminders,
                currentMileage: currentMileage
            )
        }
    }

    @MainActor
    private func refresh() async {
        await reminderStore.reload()

        // Haptic feedback (работает только на реальном iPhone)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Пересчитываем уведомления
        NotificationManager.shared.reschedule(
            reminders: reminderStore.reminders,
            currentMileage: currentMileage
        )
    }
}
