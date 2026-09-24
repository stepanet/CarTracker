import SwiftUI
import Auth

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var workStore: CarWorkStore
    @EnvironmentObject var reminderStore: ReminderStore

    @State private var showingLogoutAlert = false
    @State private var isLoggingOut = false

    var body: some View {
        TabView {
            WorksListView()
                .tabItem {
                    Label("Работы", systemImage: "list.bullet.rectangle")
                }

            StatsView()
                .tabItem {
                    Label("Статистика", systemImage: "chart.pie.fill")
                }

            RemindersView()
                .tabItem {
                    Label("Напоминания", systemImage: "bell.fill")
                }
        }
        .safeAreaInset(edge: .top) {
            topBar
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

    // MARK: - Верхняя панель с именем пользователя и кнопкой выхода

    private var topBar: some View {
        HStack {
            Text("CarTracker")
                .font(.headline)

            Spacer()

            // Email пользователя
            if let email = authManager.user?.email {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Кнопка «Выйти»
            Button {
                showingLogoutAlert = true
            } label: {
                if isLoggingOut {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
            }
            .disabled(isLoggingOut)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color(.separator)),
            alignment: .bottom
        )
    }

    // MARK: - Выход

    @MainActor
    private func performLogout() async {
        isLoggingOut = true

        // Очищаем сторы
        workStore.clear()
        reminderStore.clear()

        do {
            try await authManager.signOut()
            print("👋 Выход выполнен")
        } catch {
            print("❌ Ошибка выхода: \(error)")
        }

        isLoggingOut = false
    }
}
