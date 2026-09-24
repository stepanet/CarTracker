import Foundation
import Supabase
import Combine

/// Менеджер Realtime-подписок на изменения таблиц.
/// Аналог `realtimeHelpers.ts` в веб-версии.
@MainActor
final class RealtimeManager: ObservableObject {

    static let shared = RealtimeManager()
    private init() {}

    private let client = SupabaseService.shared.client

    /// Текущие подписки
    private var worksChannel: RealtimeChannelV2?
    private var remindersChannel: RealtimeChannelV2?

    /// Колбэки на изменения
    var onWorksChanged: (() -> Void)?
    var onRemindersChanged: (() -> Void)?

    // MARK: - Подписки

    /// Подписаться на изменения таблиц `works` и `sub_works`
    func subscribeWorks(userId: UUID) {
        Task {
            // Отписываемся от старой подписки
            await unsubscribeWorks()

            let channel = client.realtimeV2.channel("works-changes-\(userId)")

            let worksChanges = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "works",
                filter: .eq("user_id", value: userId.uuidString)
            )

            let subWorksChanges = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "sub_works"
            )

            do {
                try await channel.subscribeWithError()
            } catch {
                print("❌ Ошибка подписки: \(error)")
            }

            // Слушаем изменения
            Task {
                for await change in worksChanges {
                    print("🔔 Realtime: изменение works — \(change)")
                    self.onWorksChanged?()
                }
            }

            Task {
                for await change in subWorksChanges {
                    print("🔔 Realtime: изменение sub_works — \(change)")
                    self.onWorksChanged?()
                }
            }

            self.worksChannel = channel
            print("🔔 Realtime: подписка на works активна")
        }
    }

    /// Подписаться на изменения таблицы `reminders`
    func subscribeReminders(userId: UUID) {
        Task {
            await unsubscribeReminders()

            let channel = client.realtimeV2.channel("reminders-changes-\(userId)")

            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "reminders",
                filter: .eq("user_id", value: userId.uuidString)
            )

            do {
                try await channel.subscribeWithError()
            } catch {
                print("❌ Ошибка подписки: \(error)")
            }
            
            Task {
                for await _ in changes {
                    self.onRemindersChanged?()
                }
            }

            self.remindersChannel = channel
            print("🔔 Realtime: подписка на reminders активна")
        }
    }

    // MARK: - Отписки

    func unsubscribeWorks() async {
        if let channel = worksChannel {
            await channel.unsubscribe()
            worksChannel = nil
            print("🔕 Realtime: works отписана")
        }
    }

    func unsubscribeReminders() async {
        if let channel = remindersChannel {
            await channel.unsubscribe()
            remindersChannel = nil
            print("🔕 Realtime: reminders отписана")
        }
    }

    func unsubscribeAll() async {
        await unsubscribeWorks()
        await unsubscribeReminders()
    }
}
