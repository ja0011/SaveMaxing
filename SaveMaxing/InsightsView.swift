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
                    analyticsSection
                    subscriptionsCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(appBackground)
            .navigationTitle("Insights")
            .task {
                await appModel.loadAnalytics()
            }
        }
    }

    // MARK: - Tiger Data / Plaid analytics

    @ViewBuilder
    private var analyticsSection: some View {
        switch appModel.analyticsState {
        case .idle, .loading:
            analyticsLoadingCard
        case .unavailable:
            analyticsUnavailableCard
        case .loaded where appModel.monthlyCashFlow.isEmpty && appModel.topMerchants.isEmpty:
            analyticsEmptyCard
        case .loaded:
            cashFlowCard
            behaviorCard
            topMerchantsCard
        }
    }

    private var analyticsLoadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading transaction history…")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var analyticsUnavailableCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Live analytics unavailable", systemImage: "wifi.exclamationmark")
                .font(.headline.weight(.bold))
                .foregroundStyle(SaveMaxingTheme.warning)

            Text("Couldn't reach the SaveMaxing backend. Make sure the FastAPI server is running, then retry.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await appModel.loadAnalytics() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.bold))
            }
            .buttonStyle(.bordered)
            .tint(SaveMaxingTheme.brand)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var analyticsEmptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No transaction history yet", systemImage: "tray")
                .font(.headline.weight(.bold))
            Text("Once transactions land in Tiger Data, monthly cash flow and merchant insights appear here.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var cashFlowCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Monthly Cash Flow", systemImage: "chart.line.uptrend.xyaxis")

            ForEach(appModel.monthlyCashFlow) { month in
                CashFlowRow(month: month)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var behaviorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Spending Behavior", systemImage: "brain.head.profile")

            ForEach(appModel.behavioralInsights) { insight in
                BehavioralInsightRow(insight: insight)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var topMerchantsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Top Merchants", systemImage: "bag.fill")

            ForEach(appModel.topMerchants.sorted { $0.spending > $1.spending }.prefix(5)) { merchant in
                HStack(spacing: 12) {
                    Image(systemName: "creditcard.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SaveMaxingTheme.info)
                        .frame(width: 34, height: 34)
                        .background(SaveMaxingTheme.info.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(merchant.merchant)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(merchant.visits == 1 ? "1 visit" : "\(merchant.visits) visits")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(merchant.spending.asCurrency)
                        .font(.subheadline.weight(.bold))
                }
            }
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
                        .foregroundStyle(SaveMaxingTheme.mutedIcon)
                        .frame(width: 34, height: 34)
                        .background(SaveMaxingTheme.mutedIcon.opacity(0.12), in: Circle())

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
                    .foregroundStyle(SaveMaxingTheme.success)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var appBackground: some View {
        SaveMaxingTheme.background
            .ignoresSafeArea()
    }
}

private struct CashFlowRow: View {
    let month: MonthlyCashFlow

    private var netTint: Color {
        month.net < 0 ? SaveMaxingTheme.danger : SaveMaxingTheme.success
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(month.monthLabel)
                .font(.subheadline.weight(.bold))
                .frame(width: 42, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text("In \(month.inflow.asCurrency)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SaveMaxingTheme.success)
                Text("Out \(month.spending.asCurrency)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(month.net < 0 ? "−" : "+")\(abs(month.net).asCurrency)")
                    .font(.headline.weight(.black))
                    .foregroundStyle(netTint)
                Text("net")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct BehavioralInsightRow: View {
    let insight: BehavioralInsight

    private var tint: Color {
        switch insight.tone {
        case .positive: SaveMaxingTheme.success
        case .warning: SaveMaxingTheme.warning
        case .alert: SaveMaxingTheme.danger
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.subheadline.weight(.bold))
                Text(insight.detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                .foregroundStyle(SaveMaxingTheme.brand)
            Text(title)
                .font(.headline.weight(.bold))
            Spacer()
        }
    }
}

#Preview {
    InsightsView(appModel: AppViewModel())
}
