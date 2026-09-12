import SwiftUI

struct DashboardView: View {
    @ObservedObject var appModel: AppViewModel
    @Binding var isAdvisorPresented: Bool

    private var goal: SavingsGoal { appModel.activeGoal }
    private var categories: [SpendingCategory] { appModel.categories }
    private var transactions: [Transaction] { appModel.transactions }
    private var savingsImpact: SavingsImpact { appModel.savingsImpact }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    financialCommandCard
                    activeGoalCard
                    impactStrip
                    spendingSection
                    transactionsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(appBackground)
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdvisorPresented = true
                    } label: {
                        Label("Advisor", systemImage: "sparkles")
                    }
                }
            }
        }
    }

    private var financialCommandCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Financial Command Center")
                .font(.headline.weight(.bold))

            HStack(spacing: 10) {
                MetricPill(title: "Total Balance", value: appModel.totalBalance.formattedCurrency, systemImage: "banknote.fill")
                MetricPill(title: "Expected Income", value: "+\(appModel.expectedIncome.formattedCurrency)", systemImage: "arrow.down.circle.fill")
            }

            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.green)
                    .frame(width: 34, height: 34)
                    .background(.green.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Projected Balance")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(appModel.projectedBalance.formattedCurrency)
                        .font(.title.weight(.black))
                }
                Spacer()
            }
            .padding(14)
            .background(Color(.systemBackground).opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var activeGoalCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(goal.kind.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(goal.name)
                        .font(.title2.weight(.bold))
                    Text("At your current pace, you're projected to reach \(goal.projectedAmountAtDeadline.formattedCurrency) by your deadline.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: goal.progress)
                        .stroke(goal.health.tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(goal.progressPercentage)%")
                        .font(.headline.weight(.bold))
                }
                .frame(width: 92, height: 92)
            }

            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(goal.currentAmount.formattedCurrency)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("/ \(goal.targetAmount.formattedCurrency) \(goal.currentLabel)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ProgressView(value: goal.progress)
                    .tint(goal.health.tint)
                    .scaleEffect(x: 1, y: 1.8, anchor: .center)
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                MetricPill(title: "Days left", value: "\(goal.daysRemaining)", systemImage: "calendar")
                MetricPill(title: "Status", value: goal.health.rawValue, systemImage: goal.health.symbolName)
            }

            if let stake = goal.stake {
                StakeStatusBanner(stake: stake)
            } else {
                Label("No SOL stake attached", systemImage: "lock.open.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color(.secondarySystemBackground), goal.health.tint.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private var impactStrip: some View {
        HStack(spacing: 12) {
            ImpactTile(title: "Purchases resisted", value: "\(savingsImpact.purchasesResisted)", systemImage: "hand.raised.fill", color: .blue)
            ImpactTile(title: "Money protected", value: savingsImpact.moneyProtected.formattedCurrency, systemImage: "shield.checkered", color: .green)
        }
    }

    private var spendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Spending Categories", systemImage: "chart.pie.fill")

            VStack(spacing: 10) {
                ForEach(categories) { category in
                    CategoryRow(category: category)
                }
            }
        }
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Transactions", systemImage: "clock.arrow.circlepath")

            VStack(spacing: 0) {
                ForEach(transactions) { transaction in
                    TransactionRow(transaction: transaction)
                    if transaction.id != transactions.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var appBackground: some View {
        LinearGradient(colors: [Color(.systemBackground), Color.green.opacity(0.08), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

struct StakeStatusBanner: View {
    let stake: SolanaCommitment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: stake.state == .stakeConfirmed ? "checkmark.seal.fill" : "lock.fill")
                    .foregroundStyle(stake.state == .stakeConfirmed ? .green : .orange)
                Text("\(stake.committedSol.formattedSOL) at stake")
                    .font(.subheadline.weight(.bold))
                Spacer()
            }

            Text(stake.state == .stakeConfirmed ? "Confirmed on Solana Devnet" : stake.state.rawValue)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            if stake.state == .stakeConfirmed {
                Text("Wallet: \(stake.shortWalletAddress) • Transaction: \(stake.shortTransactionSignature)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MetricPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.green)
                .frame(width: 24, height: 24)
                .background(.green.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(Color(.systemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ImpactTile: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
            Text(value)
                .font(.title3.weight(.bold))
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 118)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SectionHeader: View {
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

private struct CategoryRow: View {
    let category: SpendingCategory

    private var progress: Double {
        guard category.budget > 0 else { return 0 }
        return min(NSDecimalNumber(decimal: category.amount / category.budget).doubleValue, 1)
    }

    private var isOverBudget: Bool {
        category.amount > category.budget
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: category.kind.symbolName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(category.kind.tint)
                    .frame(width: 34, height: 34)
                    .background(category.kind.tint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.kind.rawValue)
                        .font(.subheadline.weight(.semibold))
                    Text(isOverBudget ? "Above usual pace" : "On track")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isOverBudget ? .orange : .secondary)
                }

                Spacer()

                Text(category.amount.formattedCurrency)
                    .font(.subheadline.weight(.bold))
            }

            ProgressView(value: progress)
                .tint(isOverBudget ? .orange : .green)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.category.symbolName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(transaction.category.tint)
                .frame(width: 36, height: 36)
                .background(transaction.category.tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchantName)
                    .font(.subheadline.weight(.semibold))
                Text(transaction.category.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(transaction.amount.formattedCurrency)
                    .font(.subheadline.weight(.bold))
                Text(transaction.date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

extension SpendingCategory.Kind {
    var symbolName: String {
        switch self {
        case .dining: "fork.knife"
        case .shopping: "bag.fill"
        case .transportation: "car.fill"
        case .entertainment: "gamecontroller.fill"
        case .groceries: "cart.fill"
        case .subscriptions: "repeat.circle.fill"
        case .income: "arrow.down.circle.fill"
        case .savings: "banknote.fill"
        }
    }

    var tint: Color {
        switch self {
        case .dining: .orange
        case .shopping: .pink
        case .transportation: .blue
        case .entertainment: .purple
        case .groceries: .green
        case .subscriptions: .indigo
        case .income: .mint
        case .savings: .teal
        }
    }
}

extension GoalHealth {
    var tint: Color {
        switch self {
        case .onTrack: .green
        case .gettingClose: .orange
        case .atRisk: .red
        case .completed: .blue
        }
    }

    var symbolName: String {
        switch self {
        case .onTrack: "checkmark.circle.fill"
        case .gettingClose: "exclamationmark.circle.fill"
        case .atRisk: "xmark.octagon.fill"
        case .completed: "party.popper.fill"
        }
    }
}

#Preview {
    DashboardView(appModel: AppViewModel(), isAdvisorPresented: .constant(false))
}
