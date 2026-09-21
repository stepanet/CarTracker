import SwiftUI

struct NotificationPermissionBanner: View {
    @State private var isAuthorized: Bool? = nil
    @State private var dismissed = false

    var body: some View {
        Group {
            if let authorized = isAuthorized, !authorized, !dismissed {
                content
            }
        }
        .onAppear {
            NotificationManager.shared.checkAuthorization { granted in
                isAuthorized = granted
            }
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Включите уведомления")
                        .font(.subheadline.weight(.semibold))

                    Text("Приложение будет напоминать о ТО, когда подойдёт срок")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                requestAndDismiss()
            } label: {
                Text("Включить")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func requestAndDismiss() {
        NotificationManager.shared.requestAuthorization { granted in
            isAuthorized = granted
            if granted {
                dismissed = true
            }
        }
    }
}
