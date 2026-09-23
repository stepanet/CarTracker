import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var store: CarWorkStore

    @State private var monthsBack = 6

    private var monthlyData: [MonthlyCostDetailed] {
        store.monthlyCostsDetailed(monthsBack: monthsBack)
    }
    private var categoryData: [CategoryCost] { store.categoryCosts() }

    /// Средний расход в месяц (для линии на графике)
    private var averageMonthlyTotal: Double {
        let nonEmpty = monthlyData.filter { $0.total > 0 }
        guard !nonEmpty.isEmpty else { return 0 }
        return nonEmpty.reduce(0) { $0 + $1.total } / Double(nonEmpty.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    summarySection
                    monthlyChartSection
                    categoryChartSection
                    TopItemsChart()
                }
                .padding()
            }
            .navigationTitle("Статистика")
            .background(Color(.systemGroupedBackground))
        }
    }

    private var summarySection: some View {
        VStack(spacing: 10) {
            // Большая карточка «Всего» с разбивкой
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Всего потрачено")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(store.totalCost))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: 12) {
                    // Работы
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "wrench.adjustable.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text("Работы")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(formatCurrency(store.totalWorksCost))
                            .font(.subheadline.weight(.semibold))
                        Text(percentText(store.totalWorksCost))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().frame(height: 32)

                    // Детали
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "shippingbox.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("Детали")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(formatCurrency(store.totalPartsCost))
                            .font(.subheadline.weight(.semibold))
                        Text(percentText(store.totalPartsCost))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)

            // Три маленькие карточки
            HStack(spacing: 12) {
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
                statCard(
                    title: "Записей",
                    value: "\(store.works.count)",
                    icon: "list.bullet",
                    color: .purple
                )
            }
        }
    }

    private func percentText(_ value: Double) -> String {
        let total = store.totalCost
        guard total > 0 else { return "0%" }
        return String(format: "%.0f%%", value / total * 100)
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
                            y: .value("Сумма", item.worksTotal)
                        )
                        .foregroundStyle(by: .value("Тип", "Работы"))
                        .cornerRadius(4)

                        BarMark(
                            x: .value("Месяц", item.label),
                            y: .value("Сумма", item.partsTotal)
                        )
                        .foregroundStyle(by: .value("Тип", "Детали"))
                        .cornerRadius(4)
                    }

                    // Линия среднего
                    RuleMark(y: .value("Среднее", averageMonthlyTotal))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("средн: \(shortCurrency(averageMonthlyTotal))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .background(
                                    Color(.secondarySystemGroupedBackground)
                                        .opacity(0.9)
                                )
                                .cornerRadius(4)
                        }
                }
                .chartForegroundStyleScale([
                    "Работы": Color.blue,
                    "Детали": Color.orange
                ])
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
                .frame(height: 240)

                // Легенда
                HStack(spacing: 16) {
                    Label {
                        Text("Работы")
                            .font(.caption)
                    } icon: {
                        Circle().fill(.blue).frame(width: 8, height: 8)
                    }
                    Label {
                        Text("Детали")
                            .font(.caption)
                    } icon: {
                        Circle().fill(.orange).frame(width: 8, height: 8)
                    }
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
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
                ZStack {
                    Chart(categoryData) { item in
                        SectorMark(
                            angle: .value("Сумма", item.total),
                            innerRadius: .ratio(0.62),
                            angularInset: 1.5
                        )
                        .cornerRadius(4)
                        .foregroundStyle(by: .value("Категория", item.category.rawValue))
                    }
                    .chartForegroundStyleScale(colorScale)
                    .chartLegend(.hidden)

                    // Центральный текст
                    VStack(spacing: 2) {
                        Text("Всего")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(shortCurrency(totalCategorySum))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("₽")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
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

    private var totalCategorySum: Double {
        categoryData.reduce(0) { $0 + $1.total }
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
