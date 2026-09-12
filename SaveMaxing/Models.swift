import Foundation

struct User: Identifiable, Hashable {
    let id: UUID
    var name: String
    var email: String
}

struct Account: Identifiable, Hashable {
    enum AccountType: String, Hashable {
        case checking
        case savings
        case credit
    }

    let id: UUID
    var name: String
    var type: AccountType
    var balance: Decimal
    var institutionName: String
}

struct Transaction: Identifiable, Hashable {
    let id: UUID
    var merchantName: String
    var amount: Decimal
    var date: Date
    var category: SpendingCategory.Kind
    var accountName: String
}

struct SpendingCategory: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Hashable {
        case dining = "Dining"
        case shopping = "Shopping"
        case transportation = "Transportation"
        case entertainment = "Entertainment"
        case groceries = "Groceries"
        case subscriptions = "Subscriptions"
        case income = "Income"
        case savings = "Savings"
    }

    var id: Kind { kind }
    var kind: Kind
    var amount: Decimal
    var budget: Decimal
}

struct Subscription: Identifiable, Hashable {
    let id: UUID
    var merchantName: String
    var monthlyAmount: Decimal
    var category: SpendingCategory.Kind
    var nextBillingDate: Date
}

enum GoalKind: String, CaseIterable, Hashable {
    case savings = "Savings"
    case spendingLimit = "Spending Limit"
    case habit = "Habit"
}

enum GoalHealth: String, Hashable {
    case onTrack = "On Track"
    case gettingClose = "Getting Close"
    case atRisk = "At Risk"
    case completed = "Completed"
}

enum SolanaStakeState: String, CaseIterable, Hashable {
    case noStake = "No Stake"
    case stakeSelected = "Stake Selected"
    case walletNotConnected = "Wallet Not Connected"
    case awaitingApproval = "Awaiting Approval"
    case transactionPending = "Transaction Pending"
    case stakeConfirmed = "Stake Confirmed"
    case goalSucceeded = "Goal Succeeded"
    case goalFailed = "Goal Failed"
    case settlementPending = "Settlement Pending"
    case settled = "Settled"
}

struct SavingsGoal: Identifiable, Hashable {
    let id: UUID
    var name: String
    var targetAmount: Decimal
    var currentAmount: Decimal
    var deadline: Date
    var createdAt: Date
    var kind: GoalKind = .savings
    var currentLabel: String = "saved"
    var stake: SolanaCommitment? = nil

    var amountRemaining: Decimal {
        max(targetAmount - currentAmount, 0)
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(NSDecimalNumber(decimal: currentAmount / targetAmount).doubleValue, 1)
    }

    var progressPercentage: Int {
        Int((progress * 100).rounded())
    }

    var daysRemaining: Int {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: deadline)
        return max(Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    var requiredDailySavings: Decimal {
        guard daysRemaining > 0 else { return amountRemaining }
        return amountRemaining / Decimal(daysRemaining)
    }

    var health: GoalHealth {
        if progress >= 1 { return .completed }
        if kind == .spendingLimit {
            if progress >= 0.9 { return .atRisk }
            if progress >= 0.72 { return .gettingClose }
            return .onTrack
        }
        if progress >= 0.62 { return .onTrack }
        if progress >= 0.45 { return .gettingClose }
        return .atRisk
    }

    var projectedAmountAtDeadline: Decimal {
        switch kind {
        case .savings:
            return currentAmount + Decimal(daysRemaining) * 21.25
        case .spendingLimit:
            return currentAmount + Decimal(daysRemaining) * 7.25
        case .habit:
            return currentAmount
        }
    }
}

struct PurchaseDecision: Identifiable, Hashable {
    enum Recommendation: String, Hashable {
        case approve = "Looks Reasonable"
        case caution = "Think Twice"
        case decline = "Skip & Save"
    }

    let id: UUID
    var itemName: String
    var price: Decimal
    var recommendation: Recommendation
    var summary: String
    var reasons: [String]
    var alternatives: [String]
}

struct SolanaCommitment: Identifiable, Hashable {
    enum Mode: String, Hashable {
        case devnet
    }

    let id: UUID
    var savingsGoalID: UUID
    var committedSol: Decimal
    var mode: Mode
    var state: SolanaStakeState
    var walletAddress: String?
    var escrowWalletAddress: String
    var transactionSignature: String?
    var settlementSignature: String?
    var createdAt: Date
    var confirmedAt: Date?

    var explorerURL: URL? {
        guard let transactionSignature else { return nil }
        return URL(string: "https://explorer.solana.com/tx/\(transactionSignature)?cluster=devnet")
    }

    var shortWalletAddress: String {
        walletAddress?.shortAddress ?? "Not connected"
    }

    var shortTransactionSignature: String {
        transactionSignature?.shortAddress ?? "Pending"
    }
}

struct SavingsImpact: Hashable {
    var purchasesResisted: Int
    var moneyProtected: Decimal
}

struct AdvisorMessage: Identifiable, Hashable {
    enum Role: Hashable {
        case user
        case advisor
    }

    let id: UUID
    var role: Role
    var text: String
}

extension Decimal {
    static func currency(_ value: Double) -> Decimal {
        Decimal(value)
    }
}

extension String {
    var shortAddress: String {
        guard count > 10 else { return self }
        return "\(prefix(4))...\(suffix(4))"
    }
}
