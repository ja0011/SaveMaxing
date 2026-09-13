import Foundation

protocol BankingService {
    func fetchAvailableUsers() async throws -> [User]
    func selectUser(id: UUID)
    func fetchUser() async throws -> User
    func fetchAccounts() async throws -> [Account]
    func fetchRecentTransactions() async throws -> [Transaction]
    func fetchSpendingCategories() async throws -> [SpendingCategory]
    func fetchSubscriptions() async throws -> [Subscription]
    func fetchPrimarySavingsGoal() async throws -> SavingsGoal
    func fetchSavingsImpact() async throws -> SavingsImpact
}

struct MockBankingService: BankingService {
    func fetchAvailableUsers() async throws -> [User] {
        [MockFinancialData.user]
    }

    func selectUser(id: UUID) {
        // Mock data has a single user.
    }

    func fetchUser() async throws -> User {
        MockFinancialData.user
    }

    func fetchAccounts() async throws -> [Account] {
        MockFinancialData.accounts
    }

    func fetchRecentTransactions() async throws -> [Transaction] {
        MockFinancialData.recentTransactions
    }

    func fetchSpendingCategories() async throws -> [SpendingCategory] {
        MockFinancialData.categories
    }

    func fetchSubscriptions() async throws -> [Subscription] {
        MockFinancialData.subscriptions
    }

    func fetchPrimarySavingsGoal() async throws -> SavingsGoal {
        MockFinancialData.tvGoal
    }

    func fetchSavingsImpact() async throws -> SavingsImpact {
        MockFinancialData.savingsImpact
    }
}

/// Live banking data from the Capital One Nessie API (https://api.nessieisreal.com).
final class NessieBankingService: BankingService {
    private let apiKey = Secrets.nessieAPIKey
    private let baseURL = Secrets.nessieBaseURL

    /// Nessie customer ID currently powering the app; nil falls back to the first customer.
    private var activeCustomerID: String?
    private var cachedCustomers: [NessieCustomer] = []

    // Nessie has no budget concept, so budgets are app-defined per category.
    private static let defaultBudgets: [SpendingCategory.Kind: Decimal] = [
        .dining: 175,
        .shopping: 140,
        .transportation: 160,
        .entertainment: 70,
        .groceries: 340,
        .subscriptions: 80
    ]

    func fetchAvailableUsers() async throws -> [User] {
        try await customers().map(Self.user(from:))
    }

    func selectUser(id: UUID) {
        activeCustomerID = cachedCustomers.first { UUID(uuidString: $0.id) == id }?.id
    }

    func fetchUser() async throws -> User {
        guard let customer = try await activeCustomer() else {
            throw ServiceError.missingConfiguration("No customers exist in Nessie for this API key.")
        }
        return Self.user(from: customer)
    }

    func fetchAccounts() async throws -> [Account] {
        try await nessieAccounts().map { account in
            Account(
                id: UUID(uuidString: account.id) ?? UUID(),
                name: account.nickname,
                type: account.kind,
                // Nessie reports a credit card balance as the amount owed.
                balance: account.kind == .credit ? -account.decimalBalance : account.decimalBalance,
                institutionName: "Capital One"
            )
        }
    }

    func fetchRecentTransactions() async throws -> [Transaction] {
        var merchantCache: [String: NessieMerchant] = [:]
        var transactions: [Transaction] = []

        for account in try await nessieAccounts() {
            let purchases: [NessiePurchase] = try await get("accounts/\(account.id)/purchases")
            for purchase in purchases {
                let merchant = try await merchant(id: purchase.merchantID, cache: &merchantCache)
                transactions.append(
                    Transaction(
                        id: UUID(uuidString: purchase.id) ?? UUID(),
                        merchantName: merchant?.name ?? purchase.description ?? "Unknown Merchant",
                        amount: purchase.decimalAmount,
                        date: Self.parseDate(purchase.purchaseDate),
                        category: Self.categoryKind(for: merchant?.category),
                        accountName: account.nickname
                    )
                )
            }
        }

        return transactions.sorted { $0.date > $1.date }
    }

    func fetchSpendingCategories() async throws -> [SpendingCategory] {
        let transactions = try await fetchRecentTransactions()
        let totals = Dictionary(grouping: transactions, by: \.category)
            .mapValues { $0.reduce(Decimal(0)) { $0 + $1.amount } }

        return totals
            .map { kind, amount in
                SpendingCategory(kind: kind, amount: amount, budget: Self.defaultBudgets[kind] ?? amount)
            }
            .sorted { $0.amount > $1.amount }
    }

    func fetchSubscriptions() async throws -> [Subscription] {
        var subscriptions: [Subscription] = []

        for account in try await nessieAccounts() {
            let bills: [NessieBill] = try await get("accounts/\(account.id)/bills")
            for bill in bills {
                subscriptions.append(
                    Subscription(
                        id: UUID(uuidString: bill.id) ?? UUID(),
                        merchantName: bill.payee,
                        monthlyAmount: bill.decimalAmount,
                        category: .subscriptions,
                        nextBillingDate: Self.nextBillingDate(dayOfMonth: bill.recurringDate)
                    )
                )
            }
        }

        return subscriptions.sorted { $0.nextBillingDate < $1.nextBillingDate }
    }

    // Nessie has no concept of savings goals or resisted purchases;
    // these stay app-managed.
    func fetchPrimarySavingsGoal() async throws -> SavingsGoal {
        MockFinancialData.tvGoal
    }

    func fetchSavingsImpact() async throws -> SavingsImpact {
        MockFinancialData.savingsImpact
    }

    // MARK: - Requests

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServiceError.missingConfiguration("Nessie request for \(path) failed. Check your API key in Secrets.swift.")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func customers() async throws -> [NessieCustomer] {
        let customers: [NessieCustomer] = try await get("customers")
        cachedCustomers = customers
        return customers
    }

    private func activeCustomer() async throws -> NessieCustomer? {
        let customers = cachedCustomers.isEmpty ? try await customers() : cachedCustomers
        if let activeCustomerID, let selected = customers.first(where: { $0.id == activeCustomerID }) {
            return selected
        }
        return customers.first
    }

    private func nessieAccounts() async throws -> [NessieAccount] {
        guard let customer = try await activeCustomer() else { return [] }
        return try await get("customers/\(customer.id)/accounts")
    }

    private func merchant(id: String, cache: inout [String: NessieMerchant]) async throws -> NessieMerchant? {
        if let cached = cache[id] { return cached }
        let merchant: NessieMerchant? = try? await get("merchants/\(id)")
        if let merchant { cache[id] = merchant }
        return merchant
    }

    // MARK: - Mapping helpers

    private static func user(from customer: NessieCustomer) -> User {
        User(
            id: UUID(uuidString: customer.id) ?? UUID(),
            name: "\(customer.firstName) \(customer.lastName)",
            email: "\(customer.firstName.lowercased())@savemaxing.demo"
        )
    }

    private static func categoryKind(for category: String?) -> SpendingCategory.Kind {
        let lowered = (category ?? "").lowercased()
        if lowered.contains("dining") || lowered.contains("food") || lowered.contains("restaurant") { return .dining }
        if lowered.contains("grocer") { return .groceries }
        if lowered.contains("entertain") { return .entertainment }
        if lowered.contains("transport") || lowered.contains("travel") || lowered.contains("gas") { return .transportation }
        if lowered.contains("subscription") { return .subscriptions }
        return .shopping
    }

    private static func parseDate(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: string) ?? Date()
    }

    private static func nextBillingDate(dayOfMonth: Int?) -> Date {
        guard let dayOfMonth else { return Date() }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var components = calendar.dateComponents([.year, .month], from: today)
        components.day = dayOfMonth
        let candidate = calendar.date(from: components) ?? today
        if candidate >= today { return candidate }
        return calendar.date(byAdding: .month, value: 1, to: candidate) ?? candidate
    }
}

// MARK: - Nessie response models

private struct NessieCustomer: Decodable {
    let id: String
    let firstName: String
    let lastName: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

private struct NessieAccount: Decodable {
    let id: String
    let type: String
    let nickname: String
    let balance: Double

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case type, nickname, balance
    }

    var kind: Account.AccountType {
        switch type.lowercased() {
        case "savings": .savings
        case "credit card": .credit
        default: .checking
        }
    }

    var decimalBalance: Decimal {
        Decimal(string: "\(balance)") ?? Decimal(balance)
    }
}

private struct NessiePurchase: Decodable {
    let id: String
    let merchantID: String
    let purchaseDate: String
    let amount: Double
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case merchantID = "merchant_id"
        case purchaseDate = "purchase_date"
        case amount, description
    }

    /// Nessie truncates purchase amounts to whole dollars, which looks
    /// artificial in a banking UI. For whole-dollar amounts we add demo cents
    /// derived from the purchase ID, so each transaction shows the same cents
    /// on every launch. Remove this once amounts come from a real source.
    var decimalAmount: Decimal {
        let base = Decimal(string: "\(amount)") ?? Decimal(amount)
        guard amount.truncatingRemainder(dividingBy: 1) == 0 else { return base }
        let cents = id.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 100 }
        return base + Decimal(cents) / 100
    }
}

private struct NessieMerchant: Decodable {
    let id: String
    let name: String
    let category: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, category
    }
}

private struct NessieBill: Decodable {
    let id: String
    let payee: String
    let paymentAmount: Double
    let recurringDate: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case payee
        case paymentAmount = "payment_amount"
        case recurringDate = "recurring_date"
    }

    var decimalAmount: Decimal {
        Decimal(string: "\(paymentAmount)") ?? Decimal(paymentAmount)
    }
}

struct TigerDataService {
    func monthlySubscriptionTotal(from subscriptions: [Subscription]) -> Decimal {
        subscriptions.reduce(0) { $0 + $1.monthlyAmount }
    }

    func topOverspendingCategory(from categories: [SpendingCategory]) -> SpendingCategory? {
        categories
            .filter { $0.amount > $0.budget }
            .max { first, second in
                (first.amount - first.budget) < (second.amount - second.budget)
            }
    }
}

struct GeminiService {
    func analyzePurchase(
        itemName: String,
        price: Decimal,
        goal: SavingsGoal,
        categories: [SpendingCategory],
        subscriptions: [Subscription]
    ) async throws -> PurchaseDecision {
        let percentageOfRemaining = NSDecimalNumber(decimal: price / max(goal.amountRemaining, 1)).doubleValue
        let topCategory = TigerDataService().topOverspendingCategory(from: categories)
        let subscription = subscriptions.max { $0.monthlyAmount < $1.monthlyAmount }

        var reasons = [
            "\(price.formattedCurrency) is about \((percentageOfRemaining * 100).rounded()).formatted(.number) percent of what remains for your \(goal.name.lowercased()) goal.",
            "Based on your current pace, this purchase would reduce the cushion available before your deadline."
        ]

        if let topCategory {
            reasons.append("\(topCategory.kind.rawValue) spending is elevated this month.")
        }

        var alternatives = ["Wait until your next paycheck", "Look for a refurbished option", "Show what happens if you buy it anyway"]
        if let subscription {
            alternatives.append("Review \(subscription.merchantName), which costs \(subscription.monthlyAmount.formattedCurrency) per month")
        }

        return PurchaseDecision(
            id: UUID(),
            itemName: itemName,
            price: price,
            recommendation: .caution,
            summary: "Buying \(itemName) today would put your \(goal.name) goal under more pressure.",
            reasons: reasons,
            alternatives: alternatives
        )
    }

    func answerAdvisorQuestion(
        _ question: String,
        goal: SavingsGoal,
        categories: [SpendingCategory],
        subscriptions: [Subscription]
    ) async throws -> String {
        let lowercased = question.lowercased()
        let subscriptionTotal = subscriptions.reduce(Decimal(0)) { $0 + $1.monthlyAmount }
        let topCategory = TigerDataService().topOverspendingCategory(from: categories)

        if lowercased.contains("behind") || lowercased.contains("hurting") {
            let categoryText = topCategory.map { "\($0.kind.rawValue.lowercased()) is running \(($0.amount - $0.budget).formattedCurrency) over its usual pace" } ?? "your discretionary spending is the main pressure point"
            return "You are behind mostly because \(categoryText). For \(goal.name), you still need \(goal.amountRemaining.formattedCurrency) in \(goal.daysRemaining) days. Cutting two restaurant visits this week would help more than trimming small one-off purchases."
        }

        if lowercased.contains("subscription") || lowercased.contains("cut") {
            return "You are paying \(subscriptionTotal.formattedCurrency)/month across \(subscriptions.count) subscriptions. The fastest demo cut is Netflix + Gym, which frees up $57.99/month, or about $695.88/year."
        }

        if lowercased.contains("eating out") || lowercased.contains("dining") {
            return "Dining is at \((categories.first { $0.kind == .dining }?.amount ?? 0).formattedCurrency) this month. Reducing two meals out per week could reasonably protect $45-$70/month toward \(goal.name)."
        }

        return "Given your current balance, goal deadline, subscriptions, and category spending, I would protect \(goal.name) first. You need \(goal.requiredDailySavings.formattedCurrency)/day to stay on pace, so any new purchase should either wait or be offset by a specific spending cut."
    }
}

/// Outcome of checking a staking transaction on Solana devnet.
enum StakeVerification {
    case confirmed        // paid the escrow the expected amount
    case wrongTransfer    // on-chain, but didn't pay the escrow the right amount
    case notConfirmed     // not found on devnet yet, or failed
}

struct SolanaService {
    private let devnetRPCURL = URL(string: "https://api.devnet.solana.com")!
    // Backend-controlled escrow (its secret key lives in the backend .env),
    // so the backend can pay the stake out to the user or a charity.
    let demoEscrowWalletAddress = "AjQVNGPAXenS1CrqJMRk9pyQcKJV17stNfds3yAtYsai"

    func prepareStake(goal: SavingsGoal, committedSol: Decimal, successWallet: String, charityId: String) -> SolanaCommitment {
        SolanaCommitment(
            id: UUID(),
            savingsGoalID: goal.id,
            committedSol: committedSol,
            mode: .devnet,
            state: .stakeSelected,
            walletAddress: nil,
            successWallet: successWallet,
            charityId: charityId,
            escrowWalletAddress: demoEscrowWalletAddress,
            transactionSignature: nil,
            settlementSignature: nil,
            payoutSignature: nil,
            resolutionOutcome: nil,
            createdAt: Date(),
            confirmedAt: nil,
            resolvedAt: nil
        )
    }

    /// Confirms a devnet transaction really sent the expected amount to the
    /// escrow wallet — not just that some signature exists on-chain.
    func verifyStakeTransfer(signature: String, escrow: String, expectedSol: Decimal) async throws -> StakeVerification {
        var request = URLRequest(url: devnetRPCURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getTransaction",
            "params": [
                signature,
                ["encoding": "jsonParsed", "commitment": "confirmed", "maxSupportedTransactionVersion": 0]
            ]
        ])

        let (data, _) = try await URLSession.shared.data(for: request)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result = json["result"] as? [String: Any],
            let meta = result["meta"] as? [String: Any]
        else {
            // A null result means the signature isn't on devnet (yet).
            return .notConfirmed
        }

        if let error = meta["err"], !(error is NSNull) {
            return .notConfirmed
        }

        guard
            let transaction = result["transaction"] as? [String: Any],
            let message = transaction["message"] as? [String: Any],
            let accountKeys = message["accountKeys"] as? [[String: Any]],
            let preBalances = meta["preBalances"] as? [NSNumber],
            let postBalances = meta["postBalances"] as? [NSNumber],
            let escrowIndex = accountKeys.firstIndex(where: { ($0["pubkey"] as? String) == escrow }),
            escrowIndex < preBalances.count, escrowIndex < postBalances.count
        else {
            // Confirmed on-chain, but the escrow wallet wasn't part of it.
            return .wrongTransfer
        }

        let receivedLamports = postBalances[escrowIndex].int64Value - preBalances[escrowIndex].int64Value
        let expectedLamports = Int64((NSDecimalNumber(decimal: expectedSol).doubleValue * 1_000_000_000).rounded())

        // Allow a 1% tolerance so rounding never fails a genuine transfer.
        if receivedLamports >= Int64(Double(expectedLamports) * 0.99) {
            return .confirmed
        }
        return .wrongTransfer
    }

    /// Scans the escrow wallet's recent devnet transactions and returns the
    /// signature of one that received the expected amount after `after`.
    /// Lets the app confirm a stake with no signature pasting.
    func findStakeTransfer(escrow: String, expectedSol: Decimal, after: Date) async -> String? {
        var request = URLRequest(url: devnetRPCURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getSignaturesForAddress",
            "params": [escrow, ["limit": 25]]
        ])

        guard
            let (data, _) = try? await URLSession.shared.data(for: request),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entries = json["result"] as? [[String: Any]]
        else {
            return nil
        }

        // Grace window for clock skew.
        let cutoff = after.timeIntervalSince1970 - 120

        for entry in entries {
            if let err = entry["err"], !(err is NSNull) { continue }
            if let blockTime = entry["blockTime"] as? Double, blockTime < cutoff { continue }
            guard let signature = entry["signature"] as? String else { continue }

            if let result = try? await verifyStakeTransfer(signature: signature, escrow: escrow, expectedSol: expectedSol),
               result == .confirmed {
                return signature
            }
        }
        return nil
    }

    func explorerURL(for signature: String) -> URL? {
        URL(string: "https://explorer.solana.com/tx/\(signature)?cluster=devnet")
    }
}

private struct SignatureStatusRequest: Encodable {
    let jsonrpc = "2.0"
    let id = 1
    let method = "getSignatureStatuses"
    let params: [SignatureStatusParams]

    init(signature: String) {
        self.params = [SignatureStatusParams(signatures: [signature], searchTransactionHistory: true)]
    }
}

private struct SignatureStatusParams: Encodable {
    let signatures: [String]
    let searchTransactionHistory: Bool
}

private struct SignatureStatusResponse: Decodable {
    struct Result: Decodable {
        let value: [SignatureStatus?]
    }

    struct SignatureStatus: Decodable {
        let err: String?
        let confirmationStatus: String?
    }

    let result: Result
}

enum ServiceError: LocalizedError {
    case missingConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let message):
            message
        }
    }
}

extension Decimal {
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }

    var formattedSOL: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        return "\(formatter.string(from: self as NSDecimalNumber) ?? "0") SOL"
    }
}
