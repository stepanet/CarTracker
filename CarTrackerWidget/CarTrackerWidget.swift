import WidgetKit
import SwiftUI

// ═══════════════════════════════════════════════
// Timeline Entry
// ═══════════════════════════════════════════════

struct CarTrackerEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// ═══════════════════════════════════════════════
// Provider
// ═══════════════════════════════════════════════

struct CarTrackerProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> CarTrackerEntry {
        CarTrackerEntry(date: Date(), data: .empty)
    }
    
    func getSnapshot(
        in context: Context,
        completion: @escaping (CarTrackerEntry) -> Void
    ) {
        let data = WidgetData.load()
        print("🔵 Widget snapshot: data has \(data.reminders.count) reminders")
        completion(CarTrackerEntry(date: Date(), data: data))
    }
    
    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<CarTrackerEntry>) -> Void
    ) {
        let data = WidgetData.load()
        print("🔵 Widget timeline: data has \(data.reminders.count) reminders, vehicle: \(data.vehicleName)")
        let entry = CarTrackerEntry(date: Date(), data: data)
        
        let nextUpdate = Calendar.current.date(
            byAdding: .minute, value: 30, to: Date()
        ) ?? Date().addingTimeInterval(1800)
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
// ═══════════════════════════════════════════════
// UI
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
// systemSmall — одно (самое горящее) напоминание
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

            // Первое напоминание
            if let reminder = data.reminders.first {
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
// systemMedium — топ-3 напоминания + расходы
// ═══════════════════════════════════════════════

struct MediumWidgetView: View {
    let data: WidgetData

    var body: some View {
        HStack(spacing: 12) {
            // ЛЕВАЯ колонка: ТС + расходы
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.monthName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatMoney(data.monthTotal))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 100, alignment: .leading)

            Divider()

            // ПРАВАЯ колонка: список напоминаний
            VStack(alignment: .leading, spacing: 6) {
                if data.reminders.isEmpty {
                    Text("Нет напоминаний")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ForEach(data.reminders.prefix(3)) { reminder in
                        ReminderRow(reminder: reminder)
                    }
                    Spacer()
                }
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
// Строка напоминания
// ═══════════════════════════════════════════════

struct ReminderRow: View {
    let reminder: WidgetReminder

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor(reminder.status))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(reminder.remainingText)
                    .font(.system(size: 10))
                    .foregroundStyle(statusColor(reminder.status))
                    .lineLimit(1)
            }
        }
    }
}

// ═══════════════════════════════════════════════
// Хелперы
// ═══════════════════════════════════════════════

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

func statusColor(_ status: String) -> Color {
    switch status {
    case "overdue": return .red
    case "soon": return .orange
    case "ok": return .green
    case "disabled": return .gray
    default: return .gray
    }
}

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
    let kind: String = "CarTrackerWidget_v2"

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
// Widget Bundle
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
            reminders: [
                WidgetReminder(
                    title: "Замена масла",
                    status: "overdue",
                    remainingText: "просрочено на 850 км"
                )
            ],
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
            reminders: [
                WidgetReminder(
                    title: "Замена масла",
                    status: "overdue",
                    remainingText: "просрочено на 850 км"
                ),
                WidgetReminder(
                    title: "Ротация шин",
                    status: "soon",
                    remainingText: "осталось 2000 км"
                ),
                WidgetReminder(
                    title: "Тормозная жидкость",
                    status: "ok",
                    remainingText: "осталось 6 мес."
                )
            ],
            monthTotal: 15300,
            monthName: "Октябрь",
            updatedAt: .now
        )
    )
}
