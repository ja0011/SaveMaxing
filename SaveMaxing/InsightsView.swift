import SwiftUI

struct InsightsView: View {
    @ObservedObject var appModel: AppViewModel

    private var subscriptionTotal: Decimal {
        appModel.subscriptions.reduce(0) { $0 + $1.monthlyAmount }
    }

    private var annualSubscriptionTotal: Decimal {
        subscriptionTotal * 12
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    trendsCard
                    subscriptionsCard
                    actionCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(appBackground)
            .navigationTitle("Insights")
        }
    }

    private var trendsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Spending Trends", systemImage: "chart.line.uptrend.xyaxis")

            InsightTrendRow(title: "Dining spending", current: "$48 this week", previous: "$31 last week", change: "↑ 55%", tint: .orange)
            InsightTrendRow(title: "Entertainment spending", current: "Elevated this month", previous: "$95 spent", change: "↑ 21%", tint: .purple)
            InsightTrendRow(title: "Savings rate", current: "Behind goal pace", previous: "Needs $13.16/day", change: "↓ 8%", tint: .red)
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var subscriptionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Recurring Subscriptions", systemImage: "repeat.circle.fill")

            ForEach(appModel.subscriptions) { subscription in
                HStack(spacing: 12) {
                    Image(systemName: "creditcard.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.blue)
                        .frame(width: 34, height: 34)
                        .background(.blue.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(subscription.merchantName)
                            .font(.subheadline.weight(.semibold))
                        Text("Next bill \(subscription.nextBillingDate, format: .dateTime.month(.abbreviated).day())")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(subscription.monthlyAmount.formattedCurrency)/mo")
                        .font(.subheadline.weight(.bold))
                }
            }

            Divider()

            HStack {
                Text("Total subscriptions")
                    .font(.headline.weight(.bold))
                Spacer()
                Text("\(subscriptionTotal.formattedCurrency)/month")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.green)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Actionable Insight", systemImage: "lightbulb.max.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.yellow)

            Text("Cancel Netflix + Gym and you could free up $57.99/month.")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("That's approximately \(Decimal.currency(695.88).formattedCurrency)/year, enough to cover the remaining gap on your active goal.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SpendingMiniChart(categories: Array(appModel.categories.prefix(5)))
        }
        .padding(18)
        .background(
            LinearGradient(colors: [.yellow.opacity(0.12), Color(.secondarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private var appBackground: some View {
        LinearGradient(colors: [Color(.systemBackground), Color.green.opacity(0.07)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

private struct SpendingMiniChart: View {
    let categories: [SpendingCategory]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(categories) { category in
                let amount = NSDecimalNumber(decimal: category.amount).doubleValue
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(category.kind.tint)
                    .frame(height: max(28, CGFloat(amount / 5)))
                    .overlay(alignment: .bottom) {
                        Text(String(category.kind.rawValue.prefix(1)))
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.white)
                            .padding(.bottom, 4)
                    }
            }
        }
        .frame(height: 82, alignment: .bottom)
    }
}

private struct InsightTrendRow: View {
    let title: String
    let current: String
    let previous: String
    let change: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(current)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(change)
                    .font(.headline.weight(.black))
                    .foregroundStyle(tint)
                Text(previous)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.green)
            Text(title)
                .font(.headline.weight(.bold))
            Spacer()
        }
    }
}

#Preview {
    InsightsView(appModel: AppViewModel())
}
