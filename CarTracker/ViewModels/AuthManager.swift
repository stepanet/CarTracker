import Foundation
import Supabase
import Combine


/// Ошибки аутентификации
enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case emailNotConfirmed
    case userAlreadyExists
    case weakPassword
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Вы не авторизованы"
        case .invalidCredentials:
            return "Неверный email или пароль"
        case .emailNotConfirmed:
            return "Email не подтверждён. Проверьте почту."
        case .userAlreadyExists:
            return "Пользователь с таким email уже существует"
        case .weakPassword:
            return "Пароль слишком короткий (минимум 6 символов)"
        case .unknown(let message):
            return message
        }
    }
}

/// Менеджер аутентификации.
/// Работает через Supabase Auth.
@MainActor
final class AuthManager: ObservableObject {

    static let shared = AuthManager()

    @Published var user: User?
    @Published var isLoading = false
    @Published var error: String?

    private let client = SupabaseService.shared.client

    private init() {
        // При старте — загружаем текущую сессию
        Task {
            await loadSession()
        }
    }

    // MARK: - Сессия

    /// Загрузить текущую сессию (если пользователь уже входил)
    func loadSession() async {
        do {
            let session = try await client.auth.session
            self.user = session.user
        } catch {
            // Сессии нет — нормально, значит не залогинен
            self.user = nil
        }
    }

    // MARK: - Вход

    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            self.user = session.user
        } catch {
            let authError = translateError(error)
            self.error = authError.localizedDescription
            throw authError
        }
    }

    // MARK: - Регистрация

    func signUp(email: String, password: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password
            )

            // Если подтверждение email отключено — session сразу вернётся
            if let session = response.session {
                self.user = session.user
            } else {
                // Иначе — ждём подтверждения email
                self.user = nil
            }
        } catch {
            let authError = translateError(error)
            self.error = authError.localizedDescription
            throw authError
        }
    }

    // MARK: - Выход

    func signOut() async throws {
        try await client.auth.signOut()
        self.user = nil
    }

    // MARK: - Перевод ошибок

    private func translateError(_ error: Error) -> AuthError {
        let message = error.localizedDescription.lowercased()

        if message.contains("invalid login credentials") {
            return .invalidCredentials
        }
        if message.contains("email not confirmed") {
            return .emailNotConfirmed
        }
        if message.contains("user already registered") {
            return .userAlreadyExists
        }
        if message.contains("password") && message.contains("6") {
            return .weakPassword
        }

        return .unknown(error.localizedDescription)
    }
}
