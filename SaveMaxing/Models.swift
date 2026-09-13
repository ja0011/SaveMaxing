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

enum GoalKind: String, CaseIterable, Hashable, Codable {
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

enum SolanaStakeState: String, CaseIterable, Hashable, Codable {
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
    case resolved = "Resolved"
}

enum StakeResolutionOutcome: String, Hashable, Codable {
    case success
    case failure
}

struct SavedWallet: Identifiable, Hashable, Codable {
    let id: UUID
    var label: String
    var address: String

    var shortLabel: String {
        "\(label) — \(address.shortAddress)"
    }
}

struct Charity: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var walletAddress: String

    static let charities: [Charity] = [
        Charity(id: "red-cross", name: "Red Cross", walletAddress: "HzRzKakDLg4xS1uAiTC33Ry6DbArZTXbVBVEXgG6x36s"),
        Charity(id: "st-jude", name: "St. Jude", walletAddress: "8X2gRoetP2ZjnWZ78p4tGPM8Dqq6fMNbLaKrYUSx9tQ9")
    ]
}

struct SavingsGoal: Identifiable, Hashable, Codable {
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

    /// The goal has been blown: a spending limit went over, or a savings/habit
    /// goal ran out of days without hitting its target.
    var isFailed: Bool {
        guard targetAmount > 0 else { return false }
        switch kind {
        case .spendingLimit:
            return currentAmount >= targetAmount
        case .savings, .habit:
            return daysRemaining == 0 && progress < 1
        }
    }

    /// The goal was met: a savings/habit goal reached its target, or a spending
    /// limit reached its deadline while staying under.
    var isAchieved: Bool {
        guard targetAmount > 0 else { return false }
        switch kind {
        case .spendingLimit:
            return daysRemaining == 0 && currentAmount < targetAmount
        case .savings, .habit:
            return progress >= 1
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

struct SolanaCommitment: Identifiable, Hashable, Codable {
    enum Mode: String, Hashable, Codable {
        case devnet
    }

    let id: UUID
    var savingsGoalID: UUID
    var committedSol: Decimal
    var mode: Mode
    var state: SolanaStakeState
    var walletAddress: String?
    var successWallet: String
    var charityId: String
    var escrowWalletAddress: String
    var transactionSignature: String?
    var settlementSignature: String?
    var payoutSignature: String?
    var resolutionOutcome: StakeResolutionOutcome?
    var createdAt: Date
    var confirmedAt: Date?
    var resolvedAt: Date?

    var amountLamports: Int64 {
        Int64((NSDecimalNumber(decimal: committedSol).doubleValue * 1_000_000_000).rounded())
    }

    var explorerURL: URL? {
        guard let transactionSignature else { return nil }
        return URL(string: "https://explorer.solana.com/tx/\(transactionSignature)?cluster=devnet")
    }

    var payoutExplorerURL: URL? {
        guard let payoutSignature else { return nil }
        return URL(string: "https://explorer.solana.com/tx/\(payoutSignature)?cluster=devnet")
    }

    var shortWalletAddress: String {
        walletAddress?.shortAddress ?? "Not connected"
    }

    var shortTransactionSignature: String {
        transactionSignature?.shortAddress ?? "Pending"
    }

    init(
        id: UUID,
        savingsGoalID: UUID,
        committedSol: Decimal,
        mode: Mode,
        state: SolanaStakeState,
        walletAddress: String?,
        successWallet: String,
        charityId: String,
        escrowWalletAddress: String,
        transactionSignature: String?,
        settlementSignature: String?,
        payoutSignature: String?,
        resolutionOutcome: StakeResolutionOutcome?,
        createdAt: Date,
        confirmedAt: Date?,
        resolvedAt: Date?
    ) {
        self.id = id
        self.savingsGoalID = savingsGoalID
        self.committedSol = committedSol
        self.mode = mode
        self.state = state
        self.walletAddress = walletAddress
        self.successWallet = successWallet
        self.charityId = charityId
        self.escrowWalletAddress = escrowWalletAddress
        self.transactionSignature = transactionSignature
        self.settlementSignature = settlementSignature
        self.payoutSignature = payoutSignature
        self.resolutionOutcome = resolutionOutcome
        self.createdAt = createdAt
        self.confirmedAt = confirmedAt
        self.resolvedAt = resolvedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, savingsGoalID, committedSol, mode, state, walletAddress
        case successWallet, charityId, escrowWalletAddress, transactionSignature
        case settlementSignature, payoutSignature, resolutionOutcome, createdAt
        case confirmedAt, resolvedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        savingsGoalID = try container.decode(UUID.self, forKey: .savingsGoalID)
        committedSol = try container.decode(Decimal.self, forKey: .committedSol)
        mode = try container.decode(Mode.self, forKey: .mode)
        state = try container.decode(SolanaStakeState.self, forKey: .state)
        walletAddress = try container.decodeIfPresent(String.self, forKey: .walletAddress)
        successWallet = try container.decodeIfPresent(String.self, forKey: .successWallet) ?? ""
        charityId = try container.decodeIfPresent(String.self, forKey: .charityId) ?? "red-cross"
        escrowWalletAddress = try container.decode(String.self, forKey: .escrowWalletAddress)
        transactionSignature = try container.decodeIfPresent(String.self, forKey: .transactionSignature)
        settlementSignature = try container.decodeIfPresent(String.self, forKey: .settlementSignature)
        payoutSignature = try container.decodeIfPresent(String.self, forKey: .payoutSignature)
        resolutionOutcome = try container.decodeIfPresent(StakeResolutionOutcome.self, forKey: .resolutionOutcome)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        confirmedAt = try container.decodeIfPresent(Date.self, forKey: .confirmedAt)
        resolvedAt = try container.decodeIfPresent(Date.self, forKey: .resolvedAt)
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
