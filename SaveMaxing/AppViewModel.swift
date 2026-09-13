import Combine
import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var user = MockFinancialData.user
    @Published var availableUsers: [User] = []
    @Published var accounts = MockFinancialData.accounts
    @Published var transactions = MockFinancialData.recentTransactions
    @Published var categories = MockFinancialData.categories
    @Published var subscriptions = MockFinancialData.subscriptions
    // Start with no goals; the user creates them via the Goal Advisor.
    // Goals persist to the device so they survive relaunches.
    @Published var goals: [SavingsGoal] = [] { didSet { persistGoals() } }
    @Published var activeGoalID = UUID() { didSet { persistGoals() } }
    @Published var savedWallets: [SavedWallet] = [] { didSet { persistWallets() } }
    @Published var savingsImpact = MockFinancialData.savingsImpact
    @Published var advisorMessages: [AdvisorMessage] = [
        AdvisorMessage(id: UUID(), role: .advisor, text: "What do you need help with today?")
    ]

    // Tiger Data / Plaid historical analytics from the local FastAPI backend.
    enum AnalyticsLoadState: Hashable {
        case idle
        case loading
        case loaded
        case unavailable
    }

    @Published var analyticsState: AnalyticsLoadState = .idle
    @Published var monthlyCashFlow: [MonthlyCashFlow] = []
    @Published var topMerchants: [MerchantSpending] = []
    @Published var plaidTransactions: [PlaidTransaction] = []
    @Published var judgeDemoMonth = 0
    @Published var isJudgeDemoActive = false
    @Published var demoDay = 0

    // Admin "time machine" chat: natural-language steps that move the demo forward.
    @Published var demoChatMessages: [AdvisorMessage] = [
        AdvisorMessage(id: UUID(), role: .advisor, text: "Time Machine — move through the timeline and everything updates together. Try \"do the next 3 days\", \"forward 2 weeks\", \"go back 3 weeks\", or \"back to start\".")
    ]
    @Published var isDemoThinking = false
    @Published var demoResolveMessage: String?
    private var demoSimTransactions: [Transaction] = []

    var judgeDemoMaxMonth: Int {
        MockFinancialData.demoMonthTransactions.count
    }

    var judgeDemoTitle: String {
        judgeDemoMonth == 0 ? "No activity loaded" : "Month \(judgeDemoMonth) of \(judgeDemoMaxMonth)"
    }

    var judgeDemoDetail: String {
        switch judgeDemoMonth {
        case 1...3:
            return "Early activity is mostly normal: groceries, campus food, and a few one-off purchases."
        case 4...6:
            return "Recurring subscriptions and dining out are starting to form a pattern."
        case 7...9:
            return "Dining keeps climbing while entertainment and shopping add pressure."
        case 10...12:
            return "The full October-to-September history reveals overspending and clear savings opportunities."
        default:
            return "Start clean, then advance month by month for the judge."
        }
    }

    private let bankingService: any BankingService
    private let geminiService: GeminiService
    private let solanaService: SolanaService
    private let financialAPIService = FinancialAPIService()

    var activeGoal: SavingsGoal {
        goals.first { $0.id == activeGoalID } ?? goals.first ?? MockFinancialData.tvGoal
    }

    var totalBalance: Decimal {
        accounts.reduce(0) { $0 + $1.balance }
    }

    var expectedIncome: Decimal {
        1600
    }

    var projectedBalance: Decimal {
        totalBalance + expectedIncome - 680
    }

    var demoEscrowWalletAddress: String {
        solanaService.demoEscrowWalletAddress
    }

    var charities: [Charity] {
        Charity.charities
    }

    init() {
        // Live Capital One Nessie data; mock values above remain as the
        // fallback if the network or API key is unavailable.
        self.bankingService = NessieBankingService()
        self.geminiService = GeminiService()
        self.solanaService = SolanaService()
        loadPersistedGoals()
        loadPersistedWallets()
        if savedWallets.isEmpty {
            savedWallets = [
                SavedWallet(id: UUID(), label: "My Wallet", address: "31PxzUJwJQZqfh56a2oa5ioMA4Zc58yYibm7Bigz8mvA")
            ]
        }
    }

    // MARK: - Wallet management

    private static let walletsStorageKey = "savemaxing.wallets.v1"
    private var isLoadingWallets = false

    func addWallet(label: String, address: String) {
        let cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAddress.isEmpty else { return }
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLabel = cleanLabel.isEmpty ? "Wallet \(savedWallets.count + 1)" : cleanLabel
        savedWallets.append(SavedWallet(id: UUID(), label: finalLabel, address: cleanAddress))
    }

    /// Adds a plausible-looking demo wallet with a random address (no typing).
    @discardableResult
    func addDemoWallet() -> SavedWallet {
        let chars = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        let address = String((0..<44).map { _ in chars.randomElement()! })
        let wallet = SavedWallet(id: UUID(), label: "Wallet \(savedWallets.count + 1)", address: address)
        savedWallets.append(wallet)
        return wallet
    }

    func removeWallet(_ id: UUID) {
        savedWallets.removeAll { $0.id == id }
    }

    private func persistWallets() {
        guard !isLoadingWallets else { return }
        if let data = try? JSONEncoder().encode(savedWallets) {
            UserDefaults.standard.set(data, forKey: Self.walletsStorageKey)
        }
    }

    private func loadPersistedWallets() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.walletsStorageKey),
            let wallets = try? JSONDecoder().decode([SavedWallet].self, from: data)
        else { return }
        isLoadingWallets = true
        savedWallets = wallets
        isLoadingWallets = false
    }

    // MARK: - Goal persistence

    private static let goalsStorageKey = "savemaxing.goals.v1"
    private var isLoadingGoals = false

    private struct GoalsSnapshot: Codable {
        var goals: [SavingsGoal]
        var activeGoalID: UUID
    }

    private func persistGoals() {
        guard !isLoadingGoals else { return }
        let snapshot = GoalsSnapshot(goals: goals, activeGoalID: activeGoalID)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.goalsStorageKey)
        }
    }

    private func loadPersistedGoals() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.goalsStorageKey),
            let snapshot = try? JSONDecoder().decode(GoalsSnapshot.self, from: data)
        else { return }
        isLoadingGoals = true
        goals = snapshot.goals
        activeGoalID = snapshot.activeGoalID
        isLoadingGoals = false
    }

    var behavioralInsights: [BehavioralInsight] {
        FinancialInsightEngine.insights(cashFlow: monthlyCashFlow, merchants: topMerchants)
    }

    func loadAnalytics() async {
        guard !isJudgeDemoActive else { return }
        guard analyticsState != .loading else { return }
        analyticsState = .loading
        do {
            async let cashFlow = financialAPIService.fetchMonthlyCashFlow()
            async let merchants = financialAPIService.fetchTopMerchants()
            async let transactions = financialAPIService.fetchTransactions()
            monthlyCashFlow = try await cashFlow.sorted { $0.monthDate < $1.monthDate }
            topMerchants = try await merchants
            plaidTransactions = try await transactions
            analyticsState = .loaded
        } catch {
            analyticsState = .unavailable
        }
    }

    func switchUser(to userID: UUID) async {
        guard userID != user.id else { return }
        bankingService.selectUser(id: userID)
        await load()
    }

    func load() async {
        do {
            availableUsers = try await bankingService.fetchAvailableUsers()
            user = try await bankingService.fetchUser()
            accounts = try await bankingService.fetchAccounts()
            transactions = try await bankingService.fetchRecentTransactions()
            categories = try await bankingService.fetchSpendingCategories()
            subscriptions = try await bankingService.fetchSubscriptions()
            savingsImpact = try await bankingService.fetchSavingsImpact()
        } catch {
            // Mock defaults keep the demo available when live services are unavailable.
        }
    }

    // MARK: - Judge demo controls

    func resetJudgeDemo() {
        isJudgeDemoActive = true
        judgeDemoMonth = 0
        accounts = [
            Account(id: UUID(), name: "360 Checking", type: .checking, balance: 2480.45, institutionName: "Capital One"),
            Account(id: UUID(), name: "Performance Savings", type: .savings, balance: 2340.00, institutionName: "Capital One")
        ]
        transactions = []
        categories = []
        subscriptions = []
        // NOTE: do NOT touch `goals` here — they are the user's real, persisted
        // data. The judge demo only resets transactions/analytics, never goals.
        savingsImpact = SavingsImpact(purchasesResisted: 0, moneyProtected: 0)
        monthlyCashFlow = []
        topMerchants = []
        plaidTransactions = []
        analyticsState = .loaded
        advisorMessages = [
            AdvisorMessage(id: UUID(), role: .advisor, text: "Start with a clean slate. Load activity when you're ready to show how SaveMaxing detects patterns.")
        ]
    }

    func setJudgeDemoMonth(_ month: Int) {
        isJudgeDemoActive = true
        judgeDemoMonth = min(max(month, 0), judgeDemoMaxMonth)

        guard judgeDemoMonth > 0 else {
            resetJudgeDemo()
            return
        }

        let index = judgeDemoMonth - 1

        let visibleTransactions = MockFinancialData.demoMonthTransactions.prefix(judgeDemoMonth).flatMap { $0 }
            .sorted { $0.date > $1.date }
        accounts = demoAccounts(from: visibleTransactions)
        transactions = visibleTransactions
        categories = demoCategories(from: visibleTransactions, months: judgeDemoMonth)
        subscriptions = demoSubscriptions(for: judgeDemoMonth)
        savingsImpact = MockFinancialData.demoMonthSavingsImpact[index]
        monthlyCashFlow = demoCashFlow(for: Array(MockFinancialData.demoMonthTransactions.prefix(judgeDemoMonth)))
        topMerchants = demoTopMerchants(from: visibleTransactions)
        analyticsState = .loaded
        advisorMessages = [
            AdvisorMessage(id: UUID(), role: .advisor, text: judgeDemoDetail)
        ]
        Task { await resolveDemoStakesIfNeeded() }
    }

    func advanceJudgeDemoMonth() {
        setJudgeDemoMonth(judgeDemoMonth + 1)
    }

    func rewindJudgeDemoMonth() {
        setJudgeDemoMonth(judgeDemoMonth - 1)
    }

    private func demoCategories(from transactions: [Transaction], months: Int) -> [SpendingCategory] {
        let monthlyBudgets: [SpendingCategory.Kind: Decimal] = [
            .dining: 175,
            .shopping: 140,
            .transportation: 160,
            .entertainment: 70,
            .groceries: 340,
            .subscriptions: 80
        ]
        let totals = Dictionary(grouping: transactions.filter { $0.amount > 0 && $0.category != .savings }, by: \.category)
            .mapValues { $0.reduce(Decimal(0)) { $0 + $1.amount } }

        return totals
            .map { kind, amount in
                SpendingCategory(
                    kind: kind,
                    amount: amount,
                    budget: (monthlyBudgets[kind] ?? 100) * Decimal(max(months, 1))
                )
            }
            .sorted { $0.amount > $1.amount }
    }

    private func demoSubscriptions(for month: Int) -> [Subscription] {
        switch month {
        case 0...2:
            return []
        case 3...5:
            return Array(MockFinancialData.subscriptions.prefix(2))
        case 6...8:
            return Array(MockFinancialData.subscriptions.prefix(3))
        default:
            return MockFinancialData.subscriptions
        }
    }

    private func demoTopMerchants(from transactions: [Transaction]) -> [MerchantSpending] {
        Dictionary(grouping: transactions.filter { $0.amount > 0 && $0.category != .savings }, by: \.merchantName)
            .map { merchant, transactions in
                MerchantSpending(
                    merchant: merchant,
                    visits: transactions.count,
                    spending: NSDecimalNumber(decimal: transactions.reduce(Decimal(0)) { $0 + abs($1.amount) }).doubleValue
                )
            }
            .sorted { $0.spending > $1.spending }
    }

    private func demoAccounts(from transactions: [Transaction]) -> [Account] {
        let startingAccounts = [
            Account(id: UUID(), name: "360 Checking", type: .checking, balance: 700, institutionName: "Capital One"),
            Account(id: UUID(), name: "Performance Savings", type: .savings, balance: 825, institutionName: "Capital One"),
            Account(id: UUID(), name: "Quicksilver", type: .credit, balance: 0, institutionName: "Capital One")
        ]

        return startingAccounts.map { account in
            let accountTransactions = transactions.filter { $0.accountName == account.name }
            let balance = accountTransactions.reduce(account.balance) { runningBalance, transaction in
                switch account.type {
                case .credit:
                    return runningBalance - transaction.amount
                case .checking, .savings:
                    return runningBalance - transaction.amount
                }
            }
            return Account(
                id: account.id,
                name: account.name,
                type: account.type,
                balance: balance,
                institutionName: account.institutionName
            )
        }
    }

    private func demoCashFlow(for monthTransactions: [[Transaction]]) -> [MonthlyCashFlow] {
        monthTransactions.compactMap { transactions in
            guard let monthDate = transactions.map(\.date).min() else { return nil }
            let inflow = transactions
                .filter { $0.amount < 0 && $0.category == .income }
                .reduce(Decimal(0)) { $0 + abs($1.amount) }
            let spending = transactions
                .filter { $0.amount > 0 && $0.category != .savings }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let net = inflow - spending
            return MonthlyCashFlow(
                month: Self.demoMonthFormatter.string(from: monthDate),
                inflow: NSDecimalNumber(decimal: inflow).doubleValue,
                spending: NSDecimalNumber(decimal: spending).doubleValue,
                net: NSDecimalNumber(decimal: net).doubleValue
            )
        }
    }

    private static let demoMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-'01'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    // MARK: - Admin Time Machine (date scrubber over a fixed timeline)

    let demoMaxDay = 180
    private var demoGoalBaseline: [UUID: (days: Int, current: Decimal)] = [:]

    var demoDayLabel: String {
        if demoDay == 0 { return "Day 0 — the very first day" }
        if demoDay % 30 == 0 { return "Day \(demoDay) (\(demoDay / 30) month\(demoDay / 30 == 1 ? "" : "s"))" }
        if demoDay % 7 == 0 { return "Day \(demoDay) (\(demoDay / 7) week\(demoDay / 7 == 1 ? "" : "s"))" }
        return "Day \(demoDay)"
    }

    /// Parses a plain instruction like "next 3 days", "forward 2 weeks",
    /// "back 3 weeks", or "back to start" and moves the timeline cursor.
    func moveDemoFromText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        demoChatMessages.append(AdvisorMessage(id: UUID(), role: .user, text: trimmed))

        let lower = trimmed.lowercased()
        if lower.contains("start") || lower.contains("beginning") || lower.contains("reset") {
            setDemoDay(0, enteringDemo: true)
            demoChatMessages.append(AdvisorMessage(id: UUID(), role: .advisor, text: "Back to \(demoDayLabel). \(transactions.count) transactions."))
            return
        }

        let backward = lower.contains("back") || lower.contains("rewind") || lower.contains("ago") || lower.contains("previous") || lower.contains("earlier")
        let number = Self.firstInt(in: lower) ?? 1
        let unit = lower.contains("month") ? 30 : (lower.contains("week") ? 7 : 1)
        let magnitude = number * unit
        moveDemo(byDays: backward ? -magnitude : magnitude)

        demoChatMessages.append(AdvisorMessage(id: UUID(), role: .advisor, text: "Now at \(demoDayLabel). \(transactions.count) transactions, balances and goals updated."))
    }

    func moveDemo(byDays delta: Int) {
        setDemoDay(demoDay + delta, enteringDemo: true)
    }

    func resetDemoChat() {
        setDemoDay(0, enteringDemo: true)
        demoChatMessages = [
            AdvisorMessage(id: UUID(), role: .advisor, text: "Back to Day 0. Say how far to move — e.g. \"do the next 3 days\", \"forward 2 weeks\", \"go back 3 weeks\".")
        ]
    }

    private func setDemoDay(_ day: Int, enteringDemo: Bool) {
        if enteringDemo && !isJudgeDemoActive {
            isJudgeDemoActive = true
            demoGoalBaseline = Dictionary(uniqueKeysWithValues: goals.map {
                ($0.id, (days: $0.daysRemaining, current: $0.currentAmount))
            })
        }

        demoDay = min(max(day, 0), demoMaxDay)
        let visible = Self.demoTimeline(uptoDay: demoDay)

        transactions = visible.sorted { $0.date > $1.date }
        accounts = demoAccounts(from: visible)
        categories = demoCategories(from: visible, months: max(demoDay / 30, 1))
        topMerchants = demoTopMerchants(from: visible)
        monthlyCashFlow = demoCashFlowByMonth(visible)
        analyticsState = .loaded

        // Goals flow with the cursor — reversibly, as a function of the day.
        let today = Calendar.current.startOfDay(for: Date())
        for index in goals.indices {
            let baseDays = demoGoalBaseline[goals[index].id]?.days ?? goals[index].daysRemaining
            let baseCurrent = demoGoalBaseline[goals[index].id]?.current ?? goals[index].currentAmount

            let remaining = max(baseDays - demoDay, 0)
            goals[index].deadline = Calendar.current.date(byAdding: .day, value: remaining, to: today) ?? goals[index].deadline
            goals[index].currentAmount = demoGoalCurrent(goal: goals[index], baseCurrent: baseCurrent, baseDays: baseDays, visible: visible)
        }

        if demoDay >= demoMaxDay {
            Task { await resolveDemoStakesIfNeeded() }
        }
    }

    private func demoGoalCurrent(goal: SavingsGoal, baseCurrent: Decimal, baseDays: Int, visible: [Transaction]) -> Decimal {
        let target = goal.targetAmount
        switch goal.kind {
        case .spendingLimit:
            let dining = visible.filter { $0.category == .dining && $0.amount > 0 }.reduce(Decimal(0)) { $0 + $1.amount }
            return max(0, baseCurrent + dining)
        case .savings, .habit:
            guard baseDays > 0 else { return target }
            let fraction = min(Double(demoDay) / Double(baseDays), 1)
            return max(0, min(baseCurrent + (target - baseCurrent) * Decimal(fraction), target))
        }
    }

    private func demoCashFlowByMonth(_ txns: [Transaction]) -> [MonthlyCashFlow] {
        let groups = Dictionary(grouping: txns) { txn -> Date in
            Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: txn.date)) ?? txn.date
        }
        return groups.keys.sorted().map { month in
            let monthTxns = groups[month] ?? []
            let inflow = monthTxns.filter { $0.amount < 0 && $0.category == .income }.reduce(Decimal(0)) { $0 + abs($1.amount) }
            let spending = monthTxns.filter { $0.amount > 0 }.reduce(Decimal(0)) { $0 + $1.amount }
            return MonthlyCashFlow(
                month: Self.demoMonthFormatter.string(from: month),
                inflow: NSDecimalNumber(decimal: inflow).doubleValue,
                spending: NSDecimalNumber(decimal: spending).doubleValue,
                net: NSDecimalNumber(decimal: inflow - spending).doubleValue
            )
        }
    }

    private static func firstInt(in text: String) -> Int? {
        let digits = text.split(whereSeparator: { !$0.isNumber })
        return digits.first.flatMap { Int($0) }
    }

    // A fixed, deterministic day-by-day timeline. Rebuilding it for any cursor
    // gives the exact same data, so moving forward and backward is consistent.
    private static let demoStartDate: Date = {
        var components = DateComponents()
        components.year = 2026; components.month = 1; components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }()

    private struct DemoMerchant {
        let name: String
        let kind: SpendingCategory.Kind
        let base: Double
        let account: String
    }

    private static let demoMerchants: [DemoMerchant] = [
        DemoMerchant(name: "Chipotle", kind: .dining, base: 12, account: "Quicksilver"),
        DemoMerchant(name: "McDonald's", kind: .dining, base: 9, account: "Quicksilver"),
        DemoMerchant(name: "Starbucks", kind: .dining, base: 6, account: "Quicksilver"),
        DemoMerchant(name: "Whole Foods", kind: .groceries, base: 48, account: "360 Checking"),
        DemoMerchant(name: "Trader Joe's", kind: .groceries, base: 36, account: "360 Checking"),
        DemoMerchant(name: "Amazon", kind: .shopping, base: 32, account: "Quicksilver"),
        DemoMerchant(name: "Target", kind: .shopping, base: 44, account: "Quicksilver"),
        DemoMerchant(name: "Uber", kind: .transportation, base: 15, account: "Quicksilver"),
        DemoMerchant(name: "Shell", kind: .transportation, base: 40, account: "360 Checking"),
        DemoMerchant(name: "AMC", kind: .entertainment, base: 22, account: "Quicksilver")
    ]

    private static func demoTimeline(uptoDay: Int) -> [Transaction] {
        guard uptoDay >= 0 else { return [] }
        var result: [Transaction] = []

        for day in 0...uptoDay {
            var seed = UInt64(bitPattern: Int64(day &* 2_654_435_761 &+ 101))
            func rnd() -> Double {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double(seed >> 11) / Double(UInt64(1) << 53)
            }
            let date = Calendar.current.date(byAdding: .day, value: day, to: demoStartDate) ?? demoStartDate

            // Biweekly paycheck.
            if day > 0 && day % 14 == 0 {
                result.append(Transaction(id: demoID(day, 90), merchantName: "Payroll", amount: -1400, date: date, category: .income, accountName: "360 Checking"))
            }
            // Monthly rent.
            if day % 30 == 3 {
                result.append(Transaction(id: demoID(day, 91), merchantName: "Greystar Apartments", amount: 1650, date: date, category: .subscriptions, accountName: "360 Checking"))
            }
            // 1-3 everyday purchases.
            let count = Int(rnd() * 3) + 1
            for i in 0..<count {
                let merchant = demoMerchants[Int(rnd() * Double(demoMerchants.count)) % demoMerchants.count]
                let amount = (merchant.base * (0.6 + rnd() * 0.9) * 100).rounded() / 100
                result.append(Transaction(id: demoID(day, i), merchantName: merchant.name, amount: Decimal(amount), date: date, category: merchant.kind, accountName: merchant.account))
            }
        }
        return result
    }

    /// Stable UUID per (day, index) so list identity doesn't churn on rebuilds.
    private static func demoID(_ day: Int, _ index: Int) -> UUID {
        let n = UInt64(bitPattern: Int64(day &* 1000 &+ index))
        let hi = n &* 0x9E3779B97F4A7C15
        var bytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: hi.bigEndian) { bytes.replaceSubrange(0..<8, with: $0) }
        withUnsafeBytes(of: n.bigEndian) { bytes.replaceSubrange(8..<16, with: $0) }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    func addJudgeGoal() {
        goals = [MockFinancialData.eatingOutGoal, MockFinancialData.tvGoal]
        activeGoalID = MockFinancialData.eatingOutGoal.id
        advisorMessages.append(
            AdvisorMessage(id: UUID(), role: .advisor, text: "Now that you have a goal, every purchase can be checked against your spending limit before you buy.")
        )
    }

    /// Turns a natural-language prompt into a goal via Gemini and adds it.
    func createGoal(fromPrompt prompt: String) async throws {
        let generated = try await financialAPIService.generateGoal(prompt: prompt)
        let goal = SavingsGoal(
            id: UUID(),
            name: generated.name,
            targetAmount: Decimal(generated.targetAmount),
            currentAmount: Decimal(generated.currentAmount),
            deadline: Calendar.current.date(byAdding: .day, value: max(generated.days, 1), to: Date()) ?? Date(),
            createdAt: Date(),
            kind: GoalKind(rawValue: generated.kind) ?? .savings,
            currentLabel: generated.currentLabel,
            stake: nil
        )
        goals.insert(goal, at: 0)
        activeGoalID = goal.id
    }

    func deleteGoal(_ goalID: UUID) {
        goals.removeAll { $0.id == goalID }
        if activeGoalID == goalID {
            activeGoalID = goals.first?.id ?? UUID()
        }
    }

    func analyzePurchase(itemName: String, price: Decimal) async throws -> PurchaseDecision {
        let goal = activeGoal
        let advice = try await financialAPIService.analyzePurchase(
            item: itemName,
            price: NSDecimalNumber(decimal: price).doubleValue,
            goalName: goal.name,
            goalTarget: NSDecimalNumber(decimal: goal.targetAmount).doubleValue,
            goalRemaining: NSDecimalNumber(decimal: goal.amountRemaining).doubleValue,
            goalDays: goal.daysRemaining,
            goalKind: goal.kind.rawValue
        )

        let recommendation: PurchaseDecision.Recommendation
        switch advice.recommendation.lowercased() {
        case "approve": recommendation = .approve
        case "decline": recommendation = .decline
        default: recommendation = .caution
        }

        return PurchaseDecision(
            id: UUID(),
            itemName: itemName,
            price: price,
            recommendation: recommendation,
            summary: advice.summary,
            reasons: advice.reasons,
            alternatives: advice.alternatives
        )
    }

    func askAdvisor(_ question: String) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        advisorMessages.append(AdvisorMessage(id: UUID(), role: .user, text: trimmed))

        do {
            let answer = try await geminiService.answerAdvisorQuestion(
                trimmed,
                goal: activeGoal,
                categories: categories,
                subscriptions: subscriptions
            )
            advisorMessages.append(AdvisorMessage(id: UUID(), role: .advisor, text: answer))
        } catch {
            advisorMessages.append(AdvisorMessage(id: UUID(), role: .advisor, text: "I could not reach the live advisor, so I used your local financial context. Your active goal needs \(activeGoal.requiredDailySavings.formattedCurrency)/day to stay on pace."))
        }
    }

    func protectPurchase(price: Decimal) {
        savingsImpact = SavingsImpact(
            purchasesResisted: savingsImpact.purchasesResisted + 1,
            moneyProtected: savingsImpact.moneyProtected + price
        )

        updateGoal(activeGoalID) { goal in
            goal.currentAmount = min(goal.currentAmount + price, goal.targetAmount)
        }
    }

    func updateGoal(_ goalID: UUID, mutate: (inout SavingsGoal) -> Void) {
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return }
        var updatedGoal = goals[index]
        mutate(&updatedGoal)
        goals[index] = updatedGoal
    }

    func updateActiveGoal(name: String, targetAmount: Decimal, currentAmount: Decimal, deadline: Date, kind: GoalKind) {
        updateGoal(activeGoalID) { goal in
            goal.name = name
            goal.targetAmount = max(targetAmount, 1)
            goal.currentAmount = min(max(currentAmount, 0), goal.targetAmount)
            goal.deadline = deadline
            goal.kind = kind
            goal.currentLabel = kind == .spendingLimit ? "spent" : kind == .habit ? "days complete" : "saved"
        }
    }

    func prepareStake(for goalID: UUID, committedSol: Decimal, successWallet: String, charityId: String) {
        guard let goal = goals.first(where: { $0.id == goalID }) else { return }
        let stake = solanaService.prepareStake(
            goal: goal,
            committedSol: committedSol,
            successWallet: successWallet.trimmingCharacters(in: .whitespacesAndNewlines),
            charityId: charityId
        )
        updateGoal(goalID) { goal in
            goal.stake = stake
        }

        if demoDay >= demoMaxDay || judgeDemoMonth == judgeDemoMaxMonth {
            Task { await resolveDemoStakesNow() }
        }
    }

    func markStakeAwaitingApproval(for goalID: UUID, walletAddress: String?) {
        let cleanedWalletAddress = walletAddress?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        updateGoal(goalID) { goal in
            goal.stake?.walletAddress = cleanedWalletAddress
            goal.stake?.state = cleanedWalletAddress == nil ? .walletNotConnected : .awaitingApproval
        }
    }

    func verifyStakeTransaction(for goalID: UUID, signature: String, walletAddress: String?) async -> StakeVerification {
        let cleanedSignature = signature.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSignature.isEmpty else { return .notConfirmed }
        guard let stake = goals.first(where: { $0.id == goalID })?.stake else { return .notConfirmed }

        updateGoal(goalID) { goal in
            goal.stake?.state = .transactionPending
            goal.stake?.transactionSignature = cleanedSignature
            goal.stake?.walletAddress = walletAddress?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }

        do {
            let result = try await solanaService.verifyStakeTransfer(
                signature: cleanedSignature,
                escrow: stake.escrowWalletAddress,
                expectedSol: stake.committedSol
            )
            updateGoal(goalID) { goal in
                switch result {
                case .confirmed:
                    goal.stake?.state = .stakeConfirmed
                    goal.stake?.confirmedAt = Date()
                case .wrongTransfer, .notConfirmed:
                    goal.stake?.state = .transactionPending
                    goal.stake?.confirmedAt = nil
                }
            }
            return result
        } catch {
            updateGoal(goalID) { goal in
                goal.stake?.state = .transactionPending
            }
            return .notConfirmed
        }
    }

    /// Confirms a stake by scanning the escrow on-chain for the payment,
    /// so the user never has to paste a signature.
    func confirmStakeByScanning(for goalID: UUID) async -> Bool {
        guard let stake = goals.first(where: { $0.id == goalID })?.stake else { return false }
        if let signature = await solanaService.findStakeTransfer(
            escrow: stake.escrowWalletAddress,
            expectedSol: stake.committedSol,
            after: stake.createdAt
        ) {
            updateGoal(goalID) { goal in
                goal.stake?.state = .stakeConfirmed
                goal.stake?.transactionSignature = signature
                goal.stake?.confirmedAt = Date()
            }
            return true
        }
        return false
    }

    @discardableResult
    func resolveStake(for goalID: UUID, outcome: StakeResolutionOutcome) async -> Bool {
        guard let stake = goals.first(where: { $0.id == goalID })?.stake else { return false }
        updateGoal(goalID) { goal in
            goal.stake?.state = .settlementPending
        }

        let charity = Charity.charities.first { $0.id == stake.charityId } ?? Charity.charities[0]
        let destination = outcome == .success ? stake.successWallet : charity.walletAddress

        do {
            let result = try await financialAPIService.resolveStake(
                stake: stake,
                outcome: outcome,
                destination: destination
            )
            updateGoal(goalID) { goal in
                goal.stake?.state = .resolved
                goal.stake?.payoutSignature = result.signature
                goal.stake?.settlementSignature = result.signature
                goal.stake?.resolutionOutcome = outcome
                goal.stake?.resolvedAt = Date()
            }
            return true
        } catch {
            updateGoal(goalID) { goal in
                goal.stake?.state = .stakeConfirmed
            }
            return false
        }
    }

    private func resolveDemoStakesIfNeeded() async {
        guard isJudgeDemoActive else { return }
        guard judgeDemoMonth == judgeDemoMaxMonth || demoDay >= demoMaxDay else { return }
        await resolveDemoStakesNow()
    }

    func resolveDemoStakesNow() async {
        demoResolveMessage = "Resolving SOL stake..."
        var resolvedCount = 0
        var failedCount = 0
        for goal in goals {
            guard let stake = goal.stake else { continue }
            guard stake.state != .resolved else { continue }
            let outcome: StakeResolutionOutcome
            switch goal.kind {
            case .spendingLimit:
                outcome = goal.currentAmount < goal.targetAmount ? .success : .failure
            case .savings, .habit:
                outcome = goal.progress >= 1 ? .success : .failure
            }
            if await resolveStake(for: goal.id, outcome: outcome) {
                resolvedCount += 1
            } else {
                failedCount += 1
            }
        }
        if resolvedCount > 0 {
            demoResolveMessage = "Resolved \(resolvedCount) SOL stake\(resolvedCount == 1 ? "" : "s"). Check backend logs."
        } else if failedCount > 0 {
            demoResolveMessage = "Backend tried but failed. Check backend logs."
        } else {
            demoResolveMessage = "No unresolved SOL stakes found."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
