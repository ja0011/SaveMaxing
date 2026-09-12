import Foundation

enum MockFinancialData {
    static let user = User(
        id: UUID(uuidString: "8F1C2BA7-74E5-4872-8E15-B795B69A1001")!,
        name: "Maya Johnson",
        email: "maya@savemaxing.demo"
    )

    static let tvGoal = SavingsGoal(
        id: UUID(uuidString: "6A69DC23-E4A7-441B-9129-45BDB61D9343")!,
        name: "TV Fund",
        targetAmount: 1000,
        currentAmount: 640,
        deadline: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 30)) ?? Date().addingTimeInterval(18 * 86_400),
        createdAt: Calendar.current.date(byAdding: .day, value: -26, to: Date()) ?? Date(),
        kind: .savings,
        currentLabel: "saved",
        stake: nil
    )

    static let eatingOutGoal = SavingsGoal(
        id: UUID(uuidString: "29B57DC1-A60F-4D8C-B12B-FC0751202324")!,
        name: "Eating Out Limit",
        targetAmount: 250,
        currentAmount: 185,
        deadline: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 21)) ?? Date().addingTimeInterval(9 * 86_400),
        createdAt: Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date(),
        kind: .spendingLimit,
        currentLabel: "spent",
        stake: nil
    )

    static let habitGoal = SavingsGoal(
        id: UUID(uuidString: "622E74B6-6EEA-4557-81F0-6F4FAFE91D58")!,
        name: "No Takeout",
        targetAmount: 30,
        currentAmount: 11,
        deadline: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 1)) ?? Date().addingTimeInterval(19 * 86_400),
        createdAt: Calendar.current.date(byAdding: .day, value: -11, to: Date()) ?? Date(),
        kind: .habit,
        currentLabel: "days complete",
        stake: nil
    )

    static let goals = [tvGoal, eatingOutGoal, habitGoal]

    static let accounts: [Account] = [
        Account(id: UUID(), name: "360 Checking", type: .checking, balance: 2480.45, institutionName: "Capital One"),
        Account(id: UUID(), name: "Performance Savings", type: .savings, balance: 2340.00, institutionName: "Capital One"),
        Account(id: UUID(), name: "Quicksilver", type: .credit, balance: -184.33, institutionName: "Capital One")
    ]

    static let categories: [SpendingCategory] = [
        SpendingCategory(kind: .dining, amount: 210, budget: 175),
        SpendingCategory(kind: .shopping, amount: 185, budget: 140),
        SpendingCategory(kind: .transportation, amount: 140, budget: 160),
        SpendingCategory(kind: .entertainment, amount: 95, budget: 70),
        SpendingCategory(kind: .groceries, amount: 320, budget: 340)
    ]

    static let subscriptions: [Subscription] = [
        Subscription(id: UUID(), merchantName: "Netflix", monthlyAmount: 22.99, category: .entertainment, nextBillingDate: date(month: 9, day: 16)),
        Subscription(id: UUID(), merchantName: "Spotify", monthlyAmount: 11.99, category: .entertainment, nextBillingDate: date(month: 9, day: 18)),
        Subscription(id: UUID(), merchantName: "iCloud", monthlyAmount: 2.99, category: .subscriptions, nextBillingDate: date(month: 9, day: 20)),
        Subscription(id: UUID(), merchantName: "Gym", monthlyAmount: 35.00, category: .subscriptions, nextBillingDate: date(month: 9, day: 24))
    ]

    static let recentTransactions: [Transaction] = [
        Transaction(id: UUID(), merchantName: "McDonald's", amount: 12.48, date: date(month: 9, day: 12), category: .dining, accountName: "360 Checking"),
        Transaction(id: UUID(), merchantName: "Whole Foods", amount: 42.18, date: date(month: 9, day: 12), category: .groceries, accountName: "360 Checking"),
        Transaction(id: UUID(), merchantName: "Steam", amount: 19.99, date: date(month: 9, day: 11), category: .entertainment, accountName: "Quicksilver"),
        Transaction(id: UUID(), merchantName: "Prime Steakhouse", amount: 92.40, date: date(month: 9, day: 10), category: .dining, accountName: "Quicksilver"),
        Transaction(id: UUID(), merchantName: "Target", amount: 38.11, date: date(month: 9, day: 9), category: .shopping, accountName: "360 Checking")
    ]

    static let savingsImpact = SavingsImpact(purchasesResisted: 4, moneyProtected: 87.42)

    private static func date(month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day)) ?? Date()
    }
}
