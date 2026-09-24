import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var localError: String?
    @State private var successMessage: String?

    enum Mode {
        case signIn
        case signUp

        var title: String {
            switch self {
            case .signIn: return "Войти"
            case .signUp: return "Создать аккаунт"
            }
        }

        var subtitle: String {
            switch self {
            case .signIn: return "Войдите, чтобы синхронизировать данные"
            case .signUp: return "Создайте аккаунт для синхронизации"
            }
        }

        var switchPrompt: String {
            switch self {
            case .signIn: return "Нет аккаунта?"
            case .signUp: return "Уже есть аккаунт?"
            }
        }

        var switchAction: String {
            switch self {
            case .signIn: return "Создать"
            case .signUp: return "Войти"
            }
        }
    }

    private var isValid: Bool {
        email.trimmingCharacters(in: .whitespaces).contains("@")
            && password.count >= 6
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                // Логотип
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue)
                            .frame(width: 80, height: 80)
                        Text("🚗")
                            .font(.system(size: 42))
                    }

                    Text("CarTracker")
                        .font(.largeTitle.weight(.bold))

                    Text(mode.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Форма
                VStack(spacing: 16) {
                    // Email
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        TextField("you@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }

                    // Пароль
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Пароль")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        SecureField("Минимум 6 символов", text: $password)
                            .textContentType(
                                mode == .signIn ? .password : .newPassword
                            )
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)

                        if mode == .signUp && !password.isEmpty && password.count < 6 {
                            Text("Пароль должен быть не менее 6 символов")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.horizontal, 4)

                // Сообщения
                if let error = localError ?? authManager.error {
                    MessageBanner(
                        text: error,
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }

                if let success = successMessage {
                    MessageBanner(
                        text: success,
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }

                // Кнопка
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }
                        Text(authManager.isLoading ? "Подождите..." : mode.title)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        isValid && !authManager.isLoading
                            ? Color.blue
                            : Color.gray.opacity(0.4)
                    )
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(!isValid || authManager.isLoading)

                // Переключение режима
                HStack(spacing: 4) {
                    Text(mode.switchPrompt)
                        .foregroundStyle(.secondary)
                    Button(mode.switchAction) {
                        withAnimation {
                            mode = mode == .signIn ? .signUp : .signIn
                            localError = nil
                            successMessage = nil
                            password = ""
                        }
                    }
                    .fontWeight(.semibold)
                }
                .font(.subheadline)

                Spacer(minLength: 20)

                // Подсказка внизу
                Text("Ваши данные защищены и видны только вам")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.horizontal, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Действия

    private func submit() async {
        localError = nil
        successMessage = nil

        let cleanedEmail = email.trimmingCharacters(in: .whitespaces)

        do {
            if mode == .signIn {
                try await authManager.signIn(
                    email: cleanedEmail,
                    password: password
                )
                // После успешного входа authManager.user обновится,
                // и ContentView покажет основное приложение
            } else {
                try await authManager.signUp(
                    email: cleanedEmail,
                    password: password
                )

                if authManager.user == nil {
                    // Email-подтверждение включено
                    successMessage = "Аккаунт создан. Проверьте почту и подтвердите email."
                }
                // Если session сразу вернулась — пользователь уже залогинен
            }
        } catch let error as AuthError {
            localError = error.localizedDescription
        } catch {
            localError = error.localizedDescription
        }
    }
}

// ─── Баннер сообщения ─────────────────────────

private struct MessageBanner: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(color)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(color.opacity(0.12))
        .cornerRadius(10)
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager.shared)
}
