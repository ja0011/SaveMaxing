import SwiftUI

struct InsightsView: View {
    @ObservedObject var appModel: AppViewModel
    @State private var selectedTab: InsightCategoryTab = .income
    @State private var chatMessages: [AdvisorMessage] = [
        AdvisorMessage(id: UUID(), role: .advisor, text: "What can I help with today?")
    ]
    @State private var chatInput = ""
    @State private var isAskingInsights = false
    @FocusState private var isChatFocused: Bool

    private let financialAPIService = FinancialAPIService()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    categoryTabs
                    selectedCategoryCard
                    insightsChatCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(appBackground)
            .task {
                await appModel.loadAnalytics()
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isChatFocused = false }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InsightCategoryTab.allCases) { tab in
                    Button {
                        withAnimation(.snappy) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.title)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(
                                Color(.secondarySystemBackground),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedTab == tab ? SaveMaxingTheme.brand : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var selectedCategoryCard: some View {
        let rows = topRows(for: selectedTab)

        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: selectedTab.title, systemImage: selectedTab.systemImage)

            ForEach(rows) { row in
                InsightCategoryRow(row: row, tint: selectedTab.tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var insightsChatCard: some View {
        VStack(spacing: 0) {
            chatHeader

            Divider()

            chatTranscript

            Divider()

            chatComposer
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var chatHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "message.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(SaveMaxingTheme.brand)
                .frame(width: 34, height: 34)
                .background(Color(.systemBackground), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Money Assistant")
                    .font(.headline.weight(.bold))
                Text("Ask about your current timeline.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
    }

    private var chatTranscript: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(chatMessages) { message in
                        chatBubble(message)
                            .id(message.id)
                    }

                    if isAskingInsights {
                        typingBubble
                            .id("typing")
                    }
                }
                .padding(14)
            }
            .frame(minHeight: 260, maxHeight: 340)
            .background(Color(.systemBackground).opacity(0.45))
            .onChange(of: chatMessages.count) {
                if let lastMessage = chatMessages.last {
                    withAnimation(.snappy) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isAskingInsights) {
                guard isAskingInsights else { return }
                withAnimation(.snappy) {
                    proxy.scrollTo("typing", anchor: .bottom)
                }
            }
        }
    }

    private var chatComposer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message Money Assistant", text: $chatInput, axis: .vertical)
                .lineLimit(1...4)
                .focused($isChatFocused)
                .submitLabel(.send)
                .onSubmit {
                    Task { await askInsights() }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                Task { await askInsights() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.hierarchical)
            }
            .tint(SaveMaxingTheme.brand)
            .disabled(isAskingInsights || chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
    }

    private func chatBubble(_ message: AdvisorMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 36) }

            if message.role == .advisor {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SaveMaxingTheme.brand)
                    .frame(width: 24, height: 24)
                    .background(Color(.systemBackground), in: Circle())
            }

            Text(message.text)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    message.role == .user ? SaveMaxingTheme.brand : Color(.systemBackground),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .foregroundStyle(message.role == .user ? .white : .primary)
                .fixedSize(horizontal: false, vertical: true)

            if message.role == .advisor { Spacer(minLength: 36) }
        }
    }

    private var typingBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(SaveMaxingTheme.brand)
                .frame(width: 24, height: 24)
                .background(Color(.systemBackground), in: Circle())

            HStack(spacing: 8) {
                ProgressView()
                Text("Thinking...")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Spacer(minLength: 36)
        }
    }

    private func askInsights() async {
        let question = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        chatInput = ""
        isChatFocused = false
        isAskingInsights = true
        chatMessages.append(AdvisorMessage(id: UUID(), role: .user, text: question))

        do {
            let answer = try await financialAPIService.askInsights(
                question: question,
                transactions: insightChatTransactions,
                goals: appModel.goals.map {
                    SimGoal(
                        name: $0.name,
                        kind: $0.kind.rawValue,
                        target: NSDecimalNumber(decimal: $0.targetAmount).doubleValue,
                        current: NSDecimalNumber(decimal: $0.currentAmount).doubleValue,
                        days_left: $0.daysRemaining
                    )
                }
            )
            chatMessages.append(AdvisorMessage(id: UUID(), role: .advisor, text: answer.answer))
        } catch {
            chatMessages.append(AdvisorMessage(id: UUID(), role: .advisor, text: localInsightAnswer(for: question)))
        }

        isAskingInsights = false
    }

    private func topRows(for tab: InsightCategoryTab) -> [InsightCategoryRowData] {
        combinedTransactions
            .filter { tab.matches($0) }
            .sorted { $0.date > $1.date }
            .prefix(3)
            .map { transaction in
                InsightCategoryRowData(
                    id: transaction.id,
                    title: transaction.merchantName,
                    subtitle: transaction.date.formatted(.dateTime.month(.abbreviated).day()),
                    amount: abs(transaction.amount)
                )
            }
    }

    private var combinedTransactions: [Transaction] {
        if appModel.isJudgeDemoActive {
            return appModel.transactions
        }

        let plaid = appModel.plaidTransactions.map { $0.asTransaction(accountName: "Linked Account") }
        let combined = appModel.transactions + plaid
        var seen = Set<UUID>()
        return combined.filter { transaction in
            seen.insert(transaction.id).inserted
        }
    }

    private var insightChatTransactions: [InsightChatTransaction] {
        combinedTransactions
            .sorted { $0.date > $1.date }
            .prefix(80)
            .map {
                InsightChatTransaction(
                    merchant: $0.merchantName,
                    category: $0.category.rawValue,
                    amount: NSDecimalNumber(decimal: $0.amount).doubleValue,
                    date: $0.date.formatted(.iso8601.year().month().day()),
                    account: $0.accountName
                )
            }
    }

    private func localInsightAnswer(for question: String) -> String {
        let lower = question.lowercased()
        let transactions = combinedTransactions
        let dining = transactions.filter { $0.category == .dining && $0.amount > 0 }.reduce(Decimal(0)) { $0 + $1.amount }
        let weekTransactions = transactionsInPastWeek(from: transactions)
        let weeklyDining = weekTransactions.filter { $0.category == .dining && $0.amount > 0 }.reduce(Decimal(0)) { $0 + $1.amount }
        let top = Dictionary(grouping: transactions.filter { $0.amount > 0 }, by: \.category)
            .map { kind, txns in (kind, txns.reduce(Decimal(0)) { $0 + $1.amount }) }
            .max { $0.1 < $1.1 }

        if (lower.contains("past week") || lower.contains("last week") || lower.contains("this week")) &&
            (lower.contains("food") || lower.contains("dining") || lower.contains("eat")) {
            return "You spent \(weeklyDining.formattedCurrency) on dining in the past week of the current data."
        }

        if lower.contains("food") || lower.contains("dining") || lower.contains("eat") {
            return "You have spent \(dining.formattedCurrency) on dining in the current data. To cut that down, try cooking two more meals this week and create a goal like: don't spend over $100 eating out this week."
        }

        if let top {
            return "Your biggest spending area in the current data is \(top.0.rawValue) at \(top.1.formattedCurrency). A good next step is creating a focused goal in the Goals tab."
        }

        return "I do not see enough spending data yet. Load more activity in Admin, then ask again."
    }

    private func transactionsInPastWeek(from transactions: [Transaction]) -> [Transaction] {
        guard let latestDate = transactions.map(\.date).max(),
              let startDate = Calendar.current.date(byAdding: .day, value: -7, to: latestDate)
        else { return [] }

        return transactions.filter { $0.date >= startDate && $0.date <= latestDate }
    }

    private var appBackground: some View {
        SaveMaxingTheme.background
            .ignoresSafeArea()
    }
}

private enum InsightCategoryTab: String, CaseIterable, Identifiable {
    case income
    case dining
    case entertainment
    case shopping
    case subscriptions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: "Income"
        case .dining: "Dining Out"
        case .entertainment: "Entertainment"
        case .shopping: "Shopping"
        case .subscriptions: "Subscriptions"
        }
    }

    var systemImage: String {
        switch self {
        case .income: "arrow.down.circle.fill"
        case .dining: "fork.knife"
        case .entertainment: "play.circle.fill"
        case .shopping: "bag.fill"
        case .subscriptions: "repeat.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .income: SaveMaxingTheme.success
        case .dining: SaveMaxingTheme.warning
        case .entertainment: SaveMaxingTheme.info
        case .shopping: SaveMaxingTheme.brand
        case .subscriptions: SaveMaxingTheme.mutedIcon
        }
    }

    func matches(_ transaction: Transaction) -> Bool {
        switch self {
        case .income:
            transaction.amount < 0 || transaction.category == .income
        case .dining:
            transaction.amount > 0 && transaction.category == .dining
        case .entertainment:
            transaction.amount > 0 && transaction.category == .entertainment
        case .shopping:
            transaction.amount > 0 && transaction.category == .shopping
        case .subscriptions:
            transaction.amount > 0 && transaction.category == .subscriptions
        }
    }
}

private struct InsightCategoryRowData: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let amount: Decimal
}

private struct InsightCategoryRow: View {
    let row: InsightCategoryRowData
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Color(.systemBackground).opacity(0.78), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(row.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(row.amount.formattedCurrency)
                .font(.subheadline.weight(.bold))
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
