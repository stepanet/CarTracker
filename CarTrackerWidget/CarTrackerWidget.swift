import WidgetKit
import SwiftUI

// ═══════════════════════════════════════════════
// Timeline Entry — одна «точка» данных
// ═══════════════════════════════════════════════

struct CarTrackerEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// ═══════════════════════════════════════════════
// Provider — источник данных для виджета
// ═══════════════════════════════════════════════

struct CarTrackerProvider: TimelineProvider {

    /// Заглушка — пока данные не загружены (превью в галерее виджетов)
    func placeholder(in context: Context) -> CarTrackerEntry {
        CarTrackerEntry(date: Date(), data: .empty)
    }

    /// Быстрый снимок для галереи виджетов
    func getSnapshot(
        in context: Context,
        completion: @escaping (CarTrackerEntry) -> Void
    ) {
        let data = WidgetData.load()
        let entry = CarTrackerEntry(date: Date(), data: data)
        completion(entry)
    }

    /// Основной timeline — данные + расписание обновлений
    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<CarTrackerEntry>) -> Void
    ) {
        let data = WidgetData.load()
        let entry = CarTrackerEntry(date: Date(), data: data)

        // Обновление через 30 минут
        let nextUpdate = Calendar.current.date(
            byAdding: .minute, value: 30, to: Date()
        ) ?? Date().addingTimeInterval(1800)

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// ═══════════════════════════════════════════════
// UI виджета
// ═══════════════════════════════════════════════

struct CarTrackerWidgetEntryView: View {
    var entry: CarTrackerEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.data)
        case .systemMedium:
            MediumWidgetView(data: entry.data)
        default:
            SmallWidgetView(data: entry.data)
        }
    }
}

// ═══════════════════════════════════════════════
// systemSmall
// ═══════════════════════════════════════════════

struct SmallWidgetView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Верх: иконка ТС + имя
            HStack(spacing: 6) {
                Image(systemName: vehicleIcon(data.vehicleType))
                    .font(.caption)
                    .foregroundStyle(.blue)

                Text(data.vehicleName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Центр: напоминание
            if let reminder = data.topReminder {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor(reminder.status))
                            .frame(width: 8, height: 8)
                        Text(reminder.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Text(reminder.remainingText)
                        .font(.caption2)
                        .foregroundStyle(statusColor(reminder.status))
                        .lineLimit(2)
                }
            } else {
                // Нет напоминаний
                VStack(alignment: .leading, spacing: 2) {
                    Text("Нет напоминаний")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Добавьте в приложении")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// ═══════════════════════════════════════════════
// systemMedium
// ═══════════════════════════════════════════════

struct MediumWidgetView: View {
    let data: WidgetData

    var body: some View {
        HStack(spacing: 12) {
            // Левая колонка: иконка + имя
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: vehicleIcon(data.vehicleType))
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text(data.vehicleName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer()

                // Месяц
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.monthName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatMoney(data.monthTotal))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Правая колонка: напоминание
            VStack(alignment: .leading, spacing: 6) {
                if let reminder = data.topReminder {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor(reminder.status))
                            .frame(width: 8, height: 8)
                        Text(reminder.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

                    Text(reminder.remainingText)
                        .font(.caption2)
                        .foregroundStyle(statusColor(reminder.status))
                        .lineLimit(3)
                } else {
                    Text("Нет напоминаний")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// ═══════════════════════════════════════════════
// Хелперы
// ═══════════════════════════════════════════════

/// SF Symbol по raw value типа ТС
func vehicleIcon(_ type: String) -> String {
    switch type {
    case "car": return "car.fill"
    case "motorcycle": return "bicycle"
    case "scooter": return "scooter"
    case "snowblower": return "snowflake"
    case "lawnmower": return "leaf.fill"
    case "tiller": return "car.fill"
    case "generator": return "bolt.fill"
    case "atv": return "car.2.fill"
    case "boat": return "sailboat.fill"
    case "trailer": return "box.truck.fill"
    default: return "car.fill"
    }
}

/// Цвет по статусу напоминания
func statusColor(_ status: String) -> Color {
    switch status {
    case "overdue": return .red
    case "soon": return .orange
    case "ok": return .green
    case "disabled": return .gray
    default: return .gray
    }
}

/// Формат денег: "15 300 ₽"
func formatMoney(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencySymbol = "₽"
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: value)) ?? "\(Int(value)) ₽"
}

// ═══════════════════════════════════════════════
// Widget Configuration
// ═══════════════════════════════════════════════

struct CarTrackerWidget: Widget {
    let kind: String = "CarTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: CarTrackerProvider()
        ) { entry in
            CarTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("CarTracker")
        .description("Ближайшее ТО и расходы за месяц.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ═══════════════════════════════════════════════
// Widget Bundle — точка входа
// ═══════════════════════════════════════════════

@main
struct CarTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        CarTrackerWidget()
    }
}

// ═══════════════════════════════════════════════
// Preview
// ═══════════════════════════════════════════════

#Preview(as: .systemSmall) {
    CarTrackerWidget()
} timeline: {
    CarTrackerEntry(
        date: .now,
        data: WidgetData(
            vehicleName: "Toyota Camry",
            vehicleType: "car",
            topReminder: WidgetReminder(
                title: "Замена масла",
                status: "overdue",
                remainingText: "просрочено на 850 км"
            ),
            monthTotal: 15300,
            monthName: "Октябрь",
            updatedAt: .now
        )
    )
}

#Preview(as: .systemMedium) {
    CarTrackerWidget()
} timeline: {
    CarTrackerEntry(
        date: .now,
        data: WidgetData(
            vehicleName: "Toyota Camry",
            vehicleType: "car",
            topReminder: WidgetReminder(
                title: "Замена масла",
                status: "soon",
                remainingText: "осталось 850 км • через 12 дн."
            ),
            monthTotal: 15300,
            monthName: "Октябрь",
            updatedAt: .now
        )
    )
}
