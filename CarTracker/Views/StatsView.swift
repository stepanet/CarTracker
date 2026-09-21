import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var store: CarWorkStore

    @State private var monthsBack = 6
    @State private var selectedBar: MonthlyCost?

    private var monthlyData: [MonthlyCost] { store.monthlyCosts(monthsBack: monthsBack) }
    private var categoryData: [CategoryCost] { store.categoryCosts() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    summarySection
                    monthlyChartSection
                    categoryChartSection
                }
                .padding()
            }
            .navigationTitle("Статистика")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Сводка
    private var summarySection: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Всего",
                value: formatCurrency(store.totalCost),
                icon: "banknote.fill",
                color: .blue
            )
            statCard(
                title: "За год",
                value: formatCurrency(store.totalCostThisYear),
                icon: "calendar",
                color: .green
            )
            statCard(
                title: "Средний/мес",
                value: formatCurrency(averagePerMonth),
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
        }
    }

    private var averagePerMonth: Double {
        let nonEmpty = monthlyData.filter { $0.total > 0 }
        guard !nonEmpty.isEmpty else { return 0 }
        return nonEmpty.reduce(0) { $0 + $1.total } / Double(nonEmpty.count)
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - График по месяцам
    private var monthlyChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Расходы по месяцам")
                    .font(.headline)
                Spacer()
                Picker("Период", selection: $monthsBack) {
                    Text("3 мес").tag(3)
                    Text("6 мес").tag(6)
                    Text("12 мес").tag(12)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            if monthlyData.allSatisfy({ $0.total == 0 }) {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(monthlyData) { item in
                        BarMark(
                            x: .value("Месяц", item.label),
                            y: .value("Сумма", item.total)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(6)
                        .annotation(position: .top) {
                            if item.total > 0 {
                                Text(shortCurrency(item.total))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(shortCurrency(v))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - График по категориям
    private var categoryChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Расходы по категориям")
                .font(.headline)

            if categoryData.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart(categoryData) { item in
                    SectorMark(
                        angle: .value("Сумма", item.total),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("Категория", item.category.rawValue))
                }
                .chartForegroundStyleScale(colorScale)
                .chartLegend(.hidden)
                .frame(height: 220)

                VStack(spacing: 8) {
                    ForEach(categoryData) { item in
                        HStack {
                            Circle()
                                .fill(colorFor(item.category))
                                .frame(width: 10, height: 10)
                            Text(item.category.rawValue)
                                .font(.subheadline)
                            Spacer()
                            Text(formatCurrency(item.total))
                                .font(.subheadline.weight(.medium))
                            Text(percentString(item.total))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Цвета для категорий
    private var colorScale: KeyValuePairs<String, Color> {
        [
            CarWork.WorkCategory.maintenance.rawValue: .blue,
            CarWork.WorkCategory.repair.rawValue: .red,
            CarWork.WorkCategory.tires.rawValue: .gray,
            CarWork.WorkCategory.fuel.rawValue: .orange,
            CarWork.WorkCategory.insurance.rawValue: .green,
            CarWork.WorkCategory.other.rawValue: .purple
        ]
    }

    private func colorFor(_ category: CarWork.WorkCategory) -> Color {
        switch category {
        case .maintenance: return .blue
        case .repair: return .red
        case .tires: return .gray
        case .fuel: return .orange
        case .insurance: return .green
        case .other: return .purple
        }
    }

    private func percentString(_ value: Double) -> String {
        let total = categoryData.reduce(0) { $0 + $1.total }
        guard total > 0 else { return "" }
        return String(format: "%.0f%%", value / total * 100)
    }

    // MARK: - Заглушка
    private var emptyChartPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Нет данных для отображения")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }

    // MARK: - Форматирование
    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₽"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value)) ₽"
    }

    private func shortCurrency(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0fк", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}
