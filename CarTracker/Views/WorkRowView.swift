import SwiftUI

struct WorkRowView: View {
    let work: CarWork

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: work.category.icon)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(work.title)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(work.date, style: .date)
                    if work.mileage > 0 {
                        Text("• \(work.mileage.formatted()) км")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Значок подработ — если есть
                if work.hasSubItems {
                    HStack(spacing: 8) {
                        if work.worksCount > 0 {
                            Label("\(work.worksCount)", systemImage: "wrench.adjustable.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                        if work.partsCount > 0 {
                            Label("\(work.partsCount)", systemImage: "shippingbox.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Spacer()

            Text(formatCost(work.cost))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    private func formatCost(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₽"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value)) ₽"
    }
}
