import Foundation

// MARK: - Configuration

/// Where the SaveMaxing FastAPI backend (Tiger Data / Plaid analytics) lives.
enum FinancialAPIConfig {
    /// The Mac's LAN IP, reachable from both the Simulator and a physical
    /// iPhone on the same Wi-Fi network. If the Mac joins a different network,
    /// update this IP (`ipconfig getifaddr en0` prints it). Switch back to
    /// http://127.0.0.1:8000 if you only need the Simulator, or point at a
    /// deployed backend URL later.
    static let baseURL = URL(string: "http://172.20.1.201:8000")!
}

// MARK: - Models

/// One month of inflow vs spending from `/analytics/monthly-cash-flow`.
struct MonthlyCashFlow: Codable, Identifiable, Hashable {
    let month: String
    let inflow: Double
    let spending: Double
    let net: Double

    var id: String { month }

    var monthDate: Date {
        Self.monthFormatter.date(from: month) ?? .distantPast
    }

    /// Short label such as "Jun".
    var monthLabel: String {
        monthDate.formatted(.dateTime.month(.abbreviated))
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}

/// Aggregated merchant behavior from `/analytics/top-merchants`.
struct MerchantSpending: Codable, Identifiable, Hashable {
    let merchant: String
    let visits: Int
    let spending: Double

    var id: String { merchant }
}

/// One raw Plaid transaction from `/transactions`. Amounts follow the Plaid
/// sign convention: positive = money out (spending), negative = money in.
struct PlaidTransaction: Codable, Identifiable, Hashable {
    let id: String
    let date: String
    let amount: Double
    let merchant: String?
    let name: String?
    let category: String?
    let account: String?
    let pending: Bool?

    var displayName: String {
        merchant ?? name ?? "Transaction"
    }

    /// Real deposits only (payroll, transfers in, loan disbursements). A
    /// negative amount on a spending category is a refund, not income.
    var isIncome: Bool {
        amount < 0 && Self.incomeCategories.contains(category ?? "")
    }

    private static let incomeCategories: Set<String> = ["INCOME", "TRANSFER_IN", "LOAN_DISBURSEMENTS"]

    /// Always-positive magnitude for display.
    var magnitude: Double { abs(amount) }

    /// Human-friendly category, e.g. "Food And Drink".
    var categoryLabel: String {
        guard let category, !category.isEmpty else { return "Other" }
        return category
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    var transactionDate: Date {
        Self.formatter.date(from: date) ?? .distantPast
    }

    /// Which account this transaction belongs in, chosen by its nature so the
    /// result reads like a real bank: income and fixed bills flow through
    /// checking, day-to-day spending sits on the credit card. (The raw Plaid
    /// account ids mix both, so they aren't used for this.)
    var accountKind: Account.AccountType {
        if isIncome { return .checking }
        switch category {
        case "RENT_AND_UTILITIES", "LOAN_PAYMENTS", "GOVERNMENT_AND_NON_PROFIT",
             "MEDICAL", "TRANSFER_OUT", "TRANSFER_IN":
            return .checking
        default:
            return .credit
        }
    }

    /// Maps this transaction into the app's shared `Transaction` model so it can
    /// render alongside the bank account's own purchases.
    func asTransaction(accountName: String) -> Transaction {
        Transaction(
            id: Self.stableUUID(from: id),
            merchantName: displayName,
            amount: Decimal(amount),   // signed: negative = income/deposit
            date: transactionDate,
            category: isIncome ? .income : Self.spendingKind(for: category),
            accountName: accountName
        )
    }

    private static func spendingKind(for category: String?) -> SpendingCategory.Kind {
        switch category {
        case "FOOD_AND_DRINK": return .dining
        case "GENERAL_MERCHANDISE": return .shopping
        case "ENTERTAINMENT": return .entertainment
        case "TRANSPORTATION": return .transportation
        case "RENT_AND_UTILITIES", "GENERAL_SERVICES", "LOAN_PAYMENTS": return .subscriptions
        default: return .shopping
        }
    }

    /// A deterministic UUID derived from the Plaid id (FNV-1a) so SwiftUI keeps
    /// stable identity across reloads instead of generating a new UUID each time.
    private static func stableUUID(from string: String) -> UUID {
        func fnv1a(_ input: String) -> UInt64 {
            var hash: UInt64 = 0xcbf29ce484222325
            for byte in input.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
            return hash
        }
        let high = fnv1a(string).bigEndian
        let low = fnv1a("salt:" + string).bigEndian
        var bytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: high) { bytes.replaceSubrange(0..<8, with: $0) }
        withUnsafeBytes(of: low) { bytes.replaceSubrange(8..<16, with: $0) }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}

// MARK: - Service

/// Client for the SaveMaxing FastAPI backend. New analytics endpoints
/// (categories, recurring subscriptions, large purchases, dining spending,
/// advisor context) should be added here as one-line fetch methods.
struct FinancialAPIService {
    var baseURL = FinancialAPIConfig.baseURL

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        // Fail fast when the backend is down so Insights can show its error state.
        configuration.timeoutIntervalForRequest = 6
        return URLSession(configuration: configuration)
    }()

    /// A longer-lived session for AI calls, which take a few seconds to think.
    private let aiSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 45
        return URLSession(configuration: configuration)
    }()

    func fetchMonthlyCashFlow() async throws -> [MonthlyCashFlow] {
        try await get("analytics/monthly-cash-flow")
    }

    func fetchTopMerchants() async throws -> [MerchantSpending] {
        try await get("analytics/top-merchants")
    }

    func fetchTransactions(limit: Int = 500) async throws -> [PlaidTransaction] {
        try await get("transactions?limit=\(limit)")
    }

    // MARK: - AI advisor (Gemini, via the backend)

    func generateGoal(prompt: String) async throws -> GeneratedGoal {
        try await post("advisor/goal", body: GoalPromptBody(prompt: prompt))
    }

    func analyzePurchase(
        item: String, price: Double,
        goalName: String, goalTarget: Double, goalRemaining: Double,
        goalDays: Int, goalKind: String
    ) async throws -> PurchaseAdvice {
        try await post("advisor/purchase", body: PurchaseBody(
            item: item, price: price,
            goal_name: goalName, goal_target: goalTarget, goal_remaining: goalRemaining,
            goal_days: goalDays, goal_kind: goalKind
        ))
    }

    func simulate(instruction: String, goals: [SimGoal], accounts: [SimAccount]) async throws -> DemoStep {
        try await post("admin/simulate", body: SimulateBody(instruction: instruction, goals: goals, accounts: accounts))
    }

    func askInsights(question: String, transactions: [InsightChatTransaction], goals: [SimGoal]) async throws -> InsightChatAnswer {
        try await post("advisor/insights", body: InsightChatBody(
            question: question,
            transactions: transactions,
            goals: goals
        ))
    }

    func resolveStake(stake: SolanaCommitment, outcome: StakeResolutionOutcome, destination: String) async throws -> StakeResolutionResult {
        try await post("solana/resolve-stake", body: ResolveStakeBody(
            stake_id: stake.id.uuidString,
            outcome: outcome.rawValue,
            destination: destination,
            escrow_wallet: stake.escrowWalletAddress,
            amount_lamports: stake.amountLamports
        ))
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        // `path` may include a query string (e.g. "transactions?limit=500"),
        // so resolve it relative to the base URL rather than treating the
        // whole thing as a single path component.
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ServiceError.missingConfiguration("Invalid analytics path: \(path).")
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServiceError.missingConfiguration("The analytics backend returned an unexpected response for \(path).")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ServiceError.missingConfiguration("Invalid advisor path: \(path).")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await aiSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServiceError.missingConfiguration("The advisor backend returned an unexpected response for \(path).")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - AI advisor models

private struct GoalPromptBody: Encodable {
    let prompt: String
}

private struct PurchaseBody: Encodable {
    let item: String
    let price: Double
    let goal_name: String
    let goal_target: Double
    let goal_remaining: Double
    let goal_days: Int
    let goal_kind: String
}

/// A goal the AI generated from a natural-language prompt.
struct GeneratedGoal: Codable {
    let name: String
    let kind: String            // "Savings", "Spending Limit", or "Habit"
    let targetAmount: Double
    let currentAmount: Double
    let days: Int
    let currentLabel: String
    let summary: String

    enum CodingKeys: String, CodingKey {
        case name, kind, days, summary
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case currentLabel = "current_label"
    }
}

/// The AI's verdict on a purchase.
struct PurchaseAdvice: Codable {
    let recommendation: String  // "approve", "caution", or "decline"
    let summary: String
    let reasons: [String]
    let alternatives: [String]
}

// MARK: - Admin demo simulation

struct SimGoal: Encodable {
    let name: String
    let kind: String
    let target: Double
    let current: Double
    let days_left: Int
}

struct SimAccount: Encodable {
    let name: String
    let type: String
    let balance: Double
}

private struct SimulateBody: Encodable {
    let instruction: String
    let goals: [SimGoal]
    let accounts: [SimAccount]
}

struct InsightChatTransaction: Encodable {
    let merchant: String
    let category: String
    let amount: Double
    let date: String
    let account: String
}

private struct InsightChatBody: Encodable {
    let question: String
    let transactions: [InsightChatTransaction]
    let goals: [SimGoal]
}

struct InsightChatAnswer: Decodable {
    let answer: String
}

/// One step of the demo timeline generated by the AI.
struct DemoStep: Decodable {
    let summary: String
    let advanceDays: Int
    let transactions: [DemoTxn]
    let goalUpdates: [DemoGoalUpdate]

    enum CodingKeys: String, CodingKey {
        case summary
        case advanceDays = "advance_days"
        case transactions
        case goalUpdates = "goal_updates"
    }
}

struct DemoTxn: Decodable {
    let merchant: String
    let category: String
    let amount: Double
    let type: String        // "spend" or "income"
    let account: String     // "checking", "savings", or "credit"
}

struct DemoGoalUpdate: Decodable {
    let goal: String
    let addToCurrent: Double

    enum CodingKeys: String, CodingKey {
        case goal
        case addToCurrent = "add_to_current"
    }
}

private struct ResolveStakeBody: Encodable {
    let stake_id: String
    let outcome: String
    let destination: String
    let escrow_wallet: String
    let amount_lamports: Int64
}

struct StakeResolutionResult: Decodable {
    let signature: String
    let destination: String
    let outcome: String
}

// MARK: - Behavioral insights

/// A single observation derived from the analytics data.
struct BehavioralInsight: Identifiable, Hashable {
    enum Tone: Hashable {
        case positive
        case warning
        case alert
    }

    var id: String { title }
    var title: String
    var detail: String
    var systemImage: String
    var tone: Tone
}

/// Turns raw analytics into human-readable observations. Everything is
/// computed from the returned data; no merchants or amounts are hard-coded.
enum FinancialInsightEngine {
    static func insights(cashFlow: [MonthlyCashFlow], merchants: [MerchantSpending]) -> [BehavioralInsight] {
        var results: [BehavioralInsight] = []
        let orderedMonths = cashFlow.sorted { $0.monthDate < $1.monthDate }

        // Current cash-flow direction.
        if let current = orderedMonths.last {
            if current.net < 0 {
                results.append(BehavioralInsight(
                    title: "Spending more than you earn",
                    detail: "In \(current.monthLabel), spending exceeded income by \(abs(current.net).asCurrency).",
                    systemImage: "arrow.down.right.circle.fill",
                    tone: .alert
                ))
            } else {
                results.append(BehavioralInsight(
                    title: "Cash-flow positive",
                    detail: "You kept \(current.net.asCurrency) of what you earned in \(current.monthLabel).",
                    systemImage: "arrow.up.right.circle.fill",
                    tone: .positive
                ))
            }
        }

        // Month-over-month spending swing.
        if orderedMonths.count >= 2 {
            let current = orderedMonths[orderedMonths.count - 1]
            let previous = orderedMonths[orderedMonths.count - 2]
            if previous.spending > 0 {
                let change = (current.spending - previous.spending) / previous.spending
                if abs(change) >= 0.15 {
                    let rising = change > 0
                    results.append(BehavioralInsight(
                        title: rising ? "Spending is accelerating" : "Spending is cooling off",
                        detail: "\(current.monthLabel) spending is \(rising ? "up" : "down") \(Int(abs(change) * 100))% vs \(previous.monthLabel).",
                        systemImage: rising ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                        tone: rising ? .warning : .positive
                    ))
                }
            }
        }

        // Repeated spending behavior: the most-visited merchant.
        if let frequent = merchants.max(by: { $0.visits < $1.visits }), frequent.visits >= 3 {
            results.append(BehavioralInsight(
                title: "Repeat habit: \(frequent.merchant)",
                detail: "\(frequent.visits) purchases totaling \(frequent.spending.asCurrency) — your most frequent merchant.",
                systemImage: "repeat.circle.fill",
                tone: .warning
            ))
        }

        // Unusually high spending vs your typical merchant total.
        if merchants.count >= 4, let outlier = merchants.max(by: { $0.spending < $1.spending }) {
            let typical = median(of: merchants.map(\.spending))
            if typical > 0, outlier.spending > typical * 2 {
                results.append(BehavioralInsight(
                    title: "Unusually high: \(outlier.merchant)",
                    detail: "\(outlier.spending.asCurrency) here — about \(Int((outlier.spending / typical).rounded()))× what you spend at a typical merchant.",
                    systemImage: "exclamationmark.triangle.fill",
                    tone: .alert
                ))
            }
        }

        return results
    }

    private static func median(of values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}

extension Double {
    /// Formats analytics amounts with the app's existing currency style.
    var asCurrency: String {
        (Decimal(string: "\(self)") ?? Decimal(self)).formattedCurrency
    }
}
