import SwiftUI

struct ReminderCardView: View {
    let reminder: Reminder
    let currentMileage: Int
    let onMarkDone: () -> Void
    let onToggleEnabled: () -> Void

    // MARK: - Вычисляемые

    private var status: ReminderStatus {
        reminder.status(currentMileage: currentMileage)
    }

    private var statusColor: Color {
        switch status {
        case .ok: return .green
        case .soon: return .orange
        case .overdue: return .red
        case .disabled: return .gray
        }
    }

    /// Прогресс от 0 (только что сделали) до 1 (пора)
    /// Учитываем и км, и дату — берём то, что ближе к концу
    private var progress: Double {
        var maxProgress: Double = 0

        // Прогресс по пробегу
        if let nextMileage = reminder.nextMileage, reminder.intervalKm > 0 {
            let passed = currentMileage - reminder.lastMileage
            let ratio = Double(passed) / Double(reminder.intervalKm)
            maxProgress = max(maxProgress, ratio)
        }

        // Прогресс по дате
        if let nextDate = reminder.nextDate {
            let totalInterval = nextDate.timeIntervalSince(reminder.lastDate)
            let elapsed = Date().timeIntervalSince(reminder.lastDate)
            if totalInterval > 0 {
                maxProgress = max(maxProgress, elapsed / totalInterval)
            }
        }

        return min(max(maxProgress, 0), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            progressSection
            detailsRow
            if reminder.isEnabled {
                markDoneButton
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(alignment: .leading) {
            // Цветная полоса слева
            Rectangle()
                .fill(statusColor)
                .frame(width: 4)
                .clipShape(
                    .rect(
                        topLeadingRadius: 14,
                        bottomLeadingRadius: 14
                    )
                )
        }
        .opacity(status == .disabled ? 0.55 : 1.0)
        .contextMenu {
            Button {
                onToggleEnabled()
            } label: {
                Label(
                    reminder.isEnabled ? "Выключить" : "Включить",
                    systemImage: reminder.isEnabled ? "bell.slash" : "bell"
                )
            }
        }
    }

    // MARK: - Верхняя строка: иконка + название + статус
    private var headerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: reminder.icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.headline)
                    .strikethrough(status == .disabled, color: .secondary)
                    .lineLimit(2)

                Text(reminder.intervalDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge
        }
    }

    private var statusBadge: some View {
        Text(status.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    // MARK: - Прогресс-бар
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Прогресс-бар
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Фон
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 8)

                    // Заполнение
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [statusColor.opacity(0.7), statusColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)

            // Текст «осталось X км • Y дн.»
            if reminder.isEnabled {
                Text(reminder.remainingText(currentMileage: currentMileage))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
            } else {
                Text("Напоминание выключено")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Даты и пробеги
    private var detailsRow: some View {
        HStack(spacing: 16) {
            // Последнее
            VStack(alignment: .leading, spacing: 3) {
                Text("Последнее")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if reminder.lastMileage > 0 {
                    Text("\(reminder.lastMileage.formatted()) км")
                        .font(.caption.weight(.medium))
                }
                Text(reminder.lastDate, format: .dateTime.day().month(.abbreviated).year())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Следующее
            VStack(alignment: .leading, spacing: 3) {
                Text("Следующее")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let nextMileage = reminder.nextMileage {
                    Text("\(nextMileage.formatted()) км")
                        .font(.caption.weight(.medium))
                }
                if let nextDate = reminder.nextDate {
                    Text(nextDate, format: .dateTime.day().month(.abbreviated).year())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Кнопка «Сделано сегодня»
    private var markDoneButton: some View {
        Button {
            onMarkDone()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text("Сделано сегодня")
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(statusColor.opacity(0.12))
            .foregroundStyle(statusColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
