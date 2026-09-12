import Foundation

protocol BankingService {
    func fetchUser() async throws -> User
    func fetchAccounts() async throws -> [Account]
    func fetchRecentTransactions() async throws -> [Transaction]
    func fetchSpendingCategories() async throws -> [SpendingCategory]
    func fetchSubscriptions() async throws -> [Subscription]
    func fetchPrimarySavingsGoal() async throws -> SavingsGoal
    func fetchSavingsImpact() async throws -> SavingsImpact
}

struct MockBankingService: BankingService {
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

struct NessieBankingService: BankingService {
    func fetchUser() async throws -> User {
        try await unavailable()
    }

    func fetchAccounts() async throws -> [Account] {
        try await unavailable()
    }

    func fetchRecentTransactions() async throws -> [Transaction] {
        try await unavailable()
    }

    func fetchSpendingCategories() async throws -> [SpendingCategory] {
        try await unavailable()
    }

    func fetchSubscriptions() async throws -> [Subscription] {
        try await unavailable()
    }

    func fetchPrimarySavingsGoal() async throws -> SavingsGoal {
        try await unavailable()
    }

    func fetchSavingsImpact() async throws -> SavingsImpact {
        try await unavailable()
    }

    private func unavailable<T>() async throws -> T {
        throw ServiceError.missingConfiguration("Nessie API credentials are not configured.")
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

struct SolanaService {
    private let devnetRPCURL = URL(string: "https://api.devnet.solana.com")!
    let demoEscrowWalletAddress = "7g3ZHeY1qNyTwX22dTYrHL1HwHX13WvE3oAgUg492uWZ"

    func prepareStake(goal: SavingsGoal, committedSol: Decimal) -> SolanaCommitment {
        SolanaCommitment(
            id: UUID(),
            savingsGoalID: goal.id,
            committedSol: committedSol,
            mode: .devnet,
            state: .stakeSelected,
            walletAddress: nil,
            escrowWalletAddress: demoEscrowWalletAddress,
            transactionSignature: nil,
            settlementSignature: nil,
            createdAt: Date(),
            confirmedAt: nil
        )
    }

    func verifyDevnetTransaction(signature: String) async throws -> Bool {
        var request = URLRequest(url: devnetRPCURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getSignatureStatuses",
            "params": [
                [signature],
                ["searchTransactionHistory": true]
            ]
        ])

        let (data, _) = try await URLSession.shared.data(for: request)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result = json["result"] as? [String: Any],
            let values = result["value"] as? [Any],
            let status = values.first as? [String: Any]
        else {
            return false
        }

        if let error = status["err"], !(error is NSNull) {
            return false
        }

        let confirmationStatus = status["confirmationStatus"] as? String
        return confirmationStatus == "confirmed" || confirmationStatus == "finalized"
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
