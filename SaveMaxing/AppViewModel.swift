import Combine
import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var user = MockFinancialData.user
    @Published var accounts = MockFinancialData.accounts
    @Published var transactions = MockFinancialData.recentTransactions
    @Published var categories = MockFinancialData.categories
    @Published var subscriptions = MockFinancialData.subscriptions
    @Published var goals = MockFinancialData.goals
    @Published var activeGoalID = MockFinancialData.tvGoal.id
    @Published var savingsImpact = MockFinancialData.savingsImpact
    @Published var advisorMessages: [AdvisorMessage] = [
        AdvisorMessage(id: UUID(), role: .advisor, text: "What do you need help with today?")
    ]

    private let bankingService: any BankingService
    private let geminiService: GeminiService
    private let solanaService: SolanaService

    var activeGoal: SavingsGoal {
        goals.first { $0.id == activeGoalID } ?? goals[0]
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

    init() {
        self.bankingService = MockBankingService()
        self.geminiService = GeminiService()
        self.solanaService = SolanaService()
    }

    func load() async {
        do {
            user = try await bankingService.fetchUser()
            accounts = try await bankingService.fetchAccounts()
            transactions = try await bankingService.fetchRecentTransactions()
            categories = try await bankingService.fetchSpendingCategories()
            subscriptions = try await bankingService.fetchSubscriptions()
            goals = MockFinancialData.goals
            activeGoalID = goals.first?.id ?? activeGoalID
            savingsImpact = try await bankingService.fetchSavingsImpact()
        } catch {
            // Mock defaults keep the demo available when live services are unavailable.
        }
    }

    func analyzePurchase(itemName: String, price: Decimal) async throws -> PurchaseDecision {
        try await geminiService.analyzePurchase(
            itemName: itemName,
            price: price,
            goal: activeGoal,
            categories: categories,
            subscriptions: subscriptions
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

    func prepareStake(for goalID: UUID, committedSol: Decimal) {
        guard let goal = goals.first(where: { $0.id == goalID }) else { return }
        let stake = solanaService.prepareStake(goal: goal, committedSol: committedSol)
        updateGoal(goalID) { goal in
            goal.stake = stake
        }
    }

    func markStakeAwaitingApproval(for goalID: UUID, walletAddress: String?) {
        let cleanedWalletAddress = walletAddress?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        updateGoal(goalID) { goal in
            goal.stake?.walletAddress = cleanedWalletAddress
            goal.stake?.state = cleanedWalletAddress == nil ? .walletNotConnected : .awaitingApproval
        }
    }

    func verifyStakeTransaction(for goalID: UUID, signature: String, walletAddress: String?) async -> Bool {
        let cleanedSignature = signature.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSignature.isEmpty else { return false }

        updateGoal(goalID) { goal in
            goal.stake?.state = .transactionPending
            goal.stake?.transactionSignature = cleanedSignature
            goal.stake?.walletAddress = walletAddress?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }

        do {
            let isConfirmed = try await solanaService.verifyDevnetTransaction(signature: cleanedSignature)
            updateGoal(goalID) { goal in
                goal.stake?.state = isConfirmed ? .stakeConfirmed : .transactionPending
                goal.stake?.confirmedAt = isConfirmed ? Date() : nil
            }
            return isConfirmed
        } catch {
            updateGoal(goalID) { goal in
                goal.stake?.state = .transactionPending
            }
            return false
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
