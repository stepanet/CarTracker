import Foundation
import Supabase

/// Центральный сервис для работы с Supabase.
/// Единый экземпляр (singleton) для всего приложения.
final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}

    /// URL проекта Supabase.
    /// ⚠️ Замените на свой — Project Settings → API → Project URL
    private let supabaseURL = URL(string: "https://vnyvjbnlovbypvbrpqdt.supabase.co")!

    /// Anon public key.
    /// ⚠️ Замените на свой — Project Settings → API → anon public
    private let supabaseAnonKey = "sb_publishable_5SehM7hgx2LoJxDTfm1ZWQ_TqiJOrUg"

    /// Клиент Supabase. Единый для всего приложения.
    lazy var client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }()

    /// Текущий авторизованный пользователь (nil если не залогинен)
    var currentUser: User? {
        client.auth.currentUser
    }

    /// Есть ли активная сессия
    var isAuthenticated: Bool {
        currentUser != nil
    }
}
