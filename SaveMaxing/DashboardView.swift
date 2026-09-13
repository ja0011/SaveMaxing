import SwiftUI

struct DashboardView: View {
    @ObservedObject var appModel: AppViewModel
    @Binding var isAdvisorPresented: Bool
    @Binding var selectedTab: Int

    private var goal: SavingsGoal { appModel.activeGoal }
    private var categories: [SpendingCategory] { appModel.categories }
    private var transactions: [Transaction] { appModel.transactions }
    private var savingsImpact: SavingsImpact { appModel.savingsImpact }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    accountsSection
                    if appModel.goals.isEmpty {
                        startGoalCard
                    } else {
                        activeGoalCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(appBackground)
            .navigationTitle("Home")
            .task {
                await appModel.loadAnalytics()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    userSwitcherMenu
                }
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

    /// Lets the demo switch between Nessie customers on the fly.
    private var userSwitcherMenu: some View {
        Menu {
            ForEach(appModel.availableUsers) { user in
                Button {
                    Task { await appModel.switchUser(to: user.id) }
                } label: {
                    if user.id == appModel.user.id {
                        Label(user.name, systemImage: "checkmark")
                    } else {
                        Text(user.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.fill")
                Text(appModel.user.name.components(separatedBy: " ").first ?? appModel.user.name)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
        }
    }

    /// Chase-style stack: one uniform card per account, plus a matching
    /// projected-balance card so the whole section lines up evenly.
    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Accounts", systemImage: "building.columns.fill")

            ForEach(appModel.accounts) { account in
                NavigationLink {
                    AccountTransactionsView(
                        account: account,
                        transactions: combinedTransactions(for: account)
                    )
                } label: {
                    AccountCard(account: account)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The bank account's own Nessie purchases plus the linked Plaid history for
    /// that account type, newest first, so tapping an account shows everything.
    private func combinedTransactions(for account: Account) -> [Transaction] {
        let own = appModel.transactions.filter { $0.accountName == account.name }
        let history = appModel.plaidTransactions
            .filter { $0.accountKind == account.type }
            .map { $0.asTransaction(accountName: account.name) }
        return (own + history).sorted { $0.date > $1.date }
    }


    /// Shown on Home when the user has deleted all their goals. Tapping it
    /// jumps to the Goals tab.
    private var startGoalCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(SaveMaxingTheme.brand)
                .frame(width: 68, height: 68)
                .background(SaveMaxingTheme.accentSoft, in: Circle())

            Text("Start a goal")
                .font(.title3.weight(.bold))

            Text("You don't have any goals yet. Tap here to create one.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            SaveMaxingTheme.cardGradient(),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            selectedTab = 1   // Goals tab
        }
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

            if goal.isFailed {
                goalOutcomeBanner(
                    title: "Goal Failed",
                    systemImage: "xmark.octagon.fill",
                    tint: .red,
                    detail: goal.stake.map { "\($0.committedSol.formattedSOL) lost" }
                )
            } else if goal.isAchieved {
                goalOutcomeBanner(
                    title: "Goal Achieved",
                    systemImage: "checkmark.seal.fill",
                    tint: .green,
                    detail: goal.stake.map { "\($0.committedSol.formattedSOL) returned" }
                )
            } else if let stake = goal.stake {
                StakeStatusBanner(stake: stake)
            } else {
                Label("SOL stake not created yet", systemImage: "lock.open.fill")
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

    private func goalOutcomeBanner(title: String, systemImage: String, tint: Color, detail: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.subheadline.weight(.bold))
            Spacer()
            if let detail {
                Text(detail)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var impactStrip: some View {
        HStack(spacing: 12) {
            ImpactTile(title: "Purchases resisted", value: "\(savingsImpact.purchasesResisted)", systemImage: "hand.raised.fill", color: SaveMaxingTheme.info)
            ImpactTile(title: "Money protected", value: savingsImpact.moneyProtected.formattedCurrency, systemImage: "shield.checkered", color: SaveMaxingTheme.success)
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

    /// Only the five most recent transactions; full history lives on each account card.
    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(5))
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Transactions", systemImage: "clock.arrow.circlepath")

            VStack(spacing: 0) {
                ForEach(recentTransactions) { transaction in
                    TransactionRow(transaction: transaction)
                    if transaction.id != recentTransactions.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var appBackground: some View {
        SaveMaxingTheme.background
            .ignoresSafeArea()
    }
}

struct StakeStatusBanner: View {
    let stake: SolanaCommitment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: stake.state == .stakeConfirmed ? "checkmark.seal.fill" : "lock.fill")
                    .foregroundStyle(stake.state == .stakeConfirmed ? SaveMaxingTheme.success : SaveMaxingTheme.warning)
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

            if let outcome = stake.resolutionOutcome, let payoutSignature = stake.payoutSignature {
                Text("Resolved: \(outcome.rawValue.capitalized) • Payout: \(payoutSignature.shortAddress)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            if let payoutURL = stake.payoutExplorerURL {
                Link(destination: payoutURL) {
                    Label("View Payout", systemImage: "arrow.up.right.square.fill")
                        .font(.caption.weight(.bold))
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Full transaction history for a single account, pushed from its card.
struct AccountTransactionsView: View {
    let account: Account
    let transactions: [Transaction]

    private var sortedTransactions: [Transaction] {
        transactions.sorted { $0.date > $1.date }
    }

    private var displayBalance: Decimal {
        account.type == .credit ? abs(account.balance) : account.balance
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                balanceHeader

                if sortedTransactions.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(sortedTransactions) { transaction in
                            TransactionRow(transaction: transaction)
                            if transaction.id != sortedTransactions.last?.id {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var balanceHeader: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(displayBalance.formattedCurrency)
                .font(.title.weight(.semibold))
            Text(account.type == .credit ? "Current balance" : "Available balance")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No transactions on this account yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// A Chase-style account card: name top-left, large right-aligned balance,
/// and an action row under a divider. Fixed height keeps the stack uniform.
private struct AccountCard: View {
    static let cardHeight: CGFloat = 148

    let account: Account

    private var subtitle: String {
        account.type == .credit ? "Current balance" : "Available balance"
    }

    private var actionTitle: String {
        account.type == .credit ? "Pay card" : "Pay bills"
    }

    private var displayBalance: Decimal {
        // Banks show credit card balances as the (positive) amount owed.
        account.type == .credit ? abs(account.balance) : account.balance
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(account.name.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)

            VStack(alignment: .trailing, spacing: 2) {
                Text(displayBalance.formattedCurrency)
                    .font(.title.weight(.semibold))
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer(minLength: 12)

            Divider()

            HStack(spacing: 14) {
                Spacer()
                Text(actionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SaveMaxingTheme.brand)
                Divider()
                    .frame(height: 16)
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SaveMaxingTheme.brand)
            }
            .padding(.top, 10)
        }
        .padding(16)
        .frame(height: Self.cardHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                .foregroundStyle(SaveMaxingTheme.brand)
                .frame(width: 24, height: 24)
                .background(SaveMaxingTheme.accentSoft, in: Circle())

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
                .foregroundStyle(SaveMaxingTheme.brand)
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
                        .foregroundStyle(isOverBudget ? SaveMaxingTheme.warning : .secondary)
                }

                Spacer()

                Text(category.amount.formattedCurrency)
                    .font(.subheadline.weight(.bold))
            }

            ProgressView(value: progress)
                .tint(isOverBudget ? SaveMaxingTheme.warning : SaveMaxingTheme.accent)
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
                // A negative amount is a deposit/income; show it green with a +.
                Text(isDeposit
                     ? "+\((-transaction.amount).formattedCurrency)"
                     : transaction.amount.formattedCurrency)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isDeposit ? SaveMaxingTheme.success : .primary)
                Text(transaction.date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var isDeposit: Bool {
        transaction.amount < 0
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
        case .dining: Color(red: 0.76, green: 0.43, blue: 0.16)
        case .shopping: Color(red: 0.48, green: 0.30, blue: 0.62)
        case .transportation: SaveMaxingTheme.info
        case .entertainment: Color(red: 0.46, green: 0.34, blue: 0.72)
        case .groceries: SaveMaxingTheme.success
        case .subscriptions: Color(red: 0.30, green: 0.38, blue: 0.62)
        case .income: SaveMaxingTheme.accent
        case .savings: SaveMaxingTheme.brand
        }
    }
}

extension GoalHealth {
    var tint: Color {
        switch self {
        case .onTrack: SaveMaxingTheme.success
        case .gettingClose: SaveMaxingTheme.warning
        case .atRisk: SaveMaxingTheme.danger
        case .completed: SaveMaxingTheme.info
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
    DashboardView(appModel: AppViewModel(), isAdvisorPresented: .constant(false), selectedTab: .constant(0))
}
